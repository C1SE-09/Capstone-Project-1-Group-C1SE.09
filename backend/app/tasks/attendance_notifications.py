"""
backend/app/tasks/attendance_notifications.py
=============================================
Celery background task: Gửi FCM Push Notification cho phụ huynh khi trẻ vắng mặt.
Đảm bảo SLA nhận tin < 60s, có log và tự động dọn token rác.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.child import Child
from app.models.user import Class_, Teacher, User
from app.models.device_token import DeviceToken
from app.services.notification_service import (
    child_parents_device_tokens,
    is_invalid_token,
    send_push_notification,
)
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)

@celery_app.task(name="send_absence_notifications", queue="notifications")
def send_absence_notifications(class_id_str: str, date_str: str, target_child_ids: list[str] | None = None) -> dict:
    """
    Task chạy nền trên Celery Worker:
    1. Tìm các bé đang vắng mặt hôm nay.
    2. Lấy device token của phụ huynh từng bé.
    3. Bắn Push Notification Firebase tức thì.
    """

    db: Session = SessionLocal()
    try:
        class_uuid = uuid.UUID(class_id_str)
        att_date = date.fromisoformat(date_str)

        # 1. Lấy thông tin lớp

        class_obj = db.scalar(select(Class_).where(Class_.class_id == class_uuid))
        class_name = class_obj.name if class_obj else "Lớp học"

        # 2. Xác định danh sách bé vắng mặt
        query = select(AttendanceRecord).where(
            AttendanceRecord.class_id == class_uuid,
            AttendanceRecord.date == att_date,
            AttendanceRecord.status == AttendanceStatus.ABSENT,
        )
        if target_child_ids :
            uuids = [uuid.UUID(cid) for cid in target_child_ids]
            query = query.where(AttendanceRecord.child_id.in_(uuids))

        absent_records = db.scalars(query).all()

        if not absent_records:
            logger.info("[AttendanceNotiFy] Không có học sinh vắng nào cần gửi thông báo.")
            return {"sent": 0, "failed": 0, "reason": "no_absent_children"}

        sent_count = 0
        failed_count = 0

        # 3. Lặp qua từng bé vắng để gửi thông báo riêng biệt cho phụ huynh bé đó
        for rec in absent_records:
            child = db.scalar(select(Child).where(Child.child_id == rec.child_id))
            if not child:
                continue

            # Lấy toàn bộ token điện thoại của phụ huynh bé
            tokens = child_parents_device_tokens(db, child.child_id)
            if not tokens:
                logger.warning("[AttendanceNotiFy] Trẻ %s (%s) vắng nhưng phụ huynh chưa đăng ký thông báo", child.full_name, child.child_id)
                continue

            display_name = child.full_name
            title = "KinderLog: Thông báo điểm danh"
            body = f"Bé {display_name} hiện chưa có mặt tại lớp {class_name} hôm nay ({att_date.strftime('%d/%m%Y')}). Ba mẹ vui lòng liên hệ cô nếu cần nhé!"

            for dt in tokens:
                try:
                    send_push_notification(
                        token = dt.token,
                        title = title,
                        body = body,
                        data = {
                            "type": "attendance_absent",
                            "child_id": str(child.child_id),
                            "date": date_str,
                        },
                        channel_id = "kinderlog_attendance",
                    )
                    sent_count += 1
                except Exception as ex:
                    failed_count += 1 
                    logger.warning("[AttendanceNotify] Gửi thông báo thất bại %s: %s", dt.token, ex)
                    if is_invalid_token(ex):
                        db.delete(dt)
                        db.commit()
        logger.info("[AttendanceNotify] Hoàn thành gửi thông báo: %d thành công, %d thất bại", sent_count, failed_count)
        return {"sent": sent_count, "failed": failed_count}
    except Exception as e:
        logger.exception("[AttendanceNotify] Lỗi hệ thống khi gửi thông báo vắng mặt: %s", e)
        return {"sent": 0, "failed": 0, "error": str(e)}
    finally:
        db.close()

@celery_app.task(name="remind_unmarked_attendance", queue="notifications")
def remind_unmarked_attendance(target_date_str: str | None = None) -> dict:
    """
    Quét toàn bộ các lớp trong hệ thống vào lúc 07:40 sáng:
    - Nếu lớp chưa có bất kỳ bản ghi điểm danh nào trong ngày hôm nay
    -> Bắn Push Notification nhắc giáo viên phụ trách hoàn thành trước 07:45.
    """
    db: Session = SessionLocal()
    try: 
        target_date = date.fromisoformat(target_date_str) if target_date_str else date.today()

        #1 Lấy danh sách các lớp học
        classes = db.scalars(select(Class_)).all()
        reminded_classes = []
        total_sent = 0

        for cls in classes:
            # 2. Kiểm tra xem lớp đã có bản ghi điểm danh hôm nay chưa
            has_record = db.scalar(
                select(AttendanceRecord.record_id)
                .where(
                    AttendanceRecord.class_id == cls.class_id,
                    AttendanceRecord.date == target_date
                )
                .limit(1)
            )

            # Nếu đã điểm danh rồi thì bỏ qua
            if has_record:
                continue

            # 3. Lớp chưa điểm danh -> Tìm giáo viên phụ trách lớp
            teachers = db.scalars(
                select(Teacher).where(Teacher.class_id == cls.class_id)
            ).all()

            if not teachers:
                logger.info("[AttendanceReminder] Lớp %s chưa có giáo viên phụ trách.", cls.name)
                continue

            reminded_classes.append(cls.name)

            # 4. Gửi Push Notification cho từng giáo viên của lớp
            title = "KinderLog: Nhắc nhở điểm danh"
            body = f"Sắp đến giờ chốt điểm danh 07:45! Cô vui lòng hoàn thành bảng điểm danh cho lớp {cls.name} nhé."

            for teacher in teachers:
                # Lấy device token của tài khoản giáo viên
                tokens = db.scalars(
                    select(DeviceToken)
                    .join(User, DeviceToken.user_id == User.user_id)
                    .where(User.teacher_id == teacher.teacher_id)
                ).all()

                for dt in tokens:
                    try:
                        send_push_notification(
                            token = dt.token,
                            title = title,
                            body = body,
                            data = {
                                "type": "attendance_reminder",
                                "class_id": str(cls.class_id),
                                "date": target_date.isoformat(),
                            },
                            channel_id = "kinderlog_attendance",
                        )
                        total_sent += 1
                    except Exception as ex:
                        logger.warning("[AttendanceReminder] Lỗi gửi thông báo tới giáo viên: %s", ex)
                        if is_invalid_token(ex):
                            db.delete(dt)
                            db.commit()

        logger.info(
            "[AttendanceReminder] Hoàn tất quét: %d lớp chưa điểm danh, đã gửi %d thông báo.",
            len(reminded_classes),
            total_sent,
        )
        return{
            "unmarked_classes": reminded_classes,
            "notifications_sent": total_sent,
        }
    except Exception as e:
        logger.info("[AttendanceReminder] lỗi khi chạy nhắc điểm danh: %s", e)
        return {"error": str(e)}
    finally:
        db.close()