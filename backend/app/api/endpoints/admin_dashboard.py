from __future__ import annotations

import logging
from datetime import date

from app.core.database import get_db
from app.core.security import get_optional_current_user
from app.models.user import User, UserRole
from app.schemas.admin_dashboard import (
    AdminOverviewStats,
    ClassProgressStat,
    ReportTrendItem,
    SystemHealthStats,
    VoiceRecordStats,
)
from app.services import admin_dashboard_service
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/dashboard", tags=["Admin Dashboard"])


def check_admin_access(
    current_user: User | None = Depends(get_optional_current_user),
) -> User | None:
    """Kiểm tra quyền hạn quản trị viên khi có token."""
    if current_user:
        role_val = (
            current_user.role.value
            if hasattr(current_user.role, "value")
            else str(current_user.role)
        )
        if role_val != UserRole.ADMIN.value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Chỉ tài khoản quản trị viên mới có quyền xem thông tin này",
            )
    return current_user


@router.get(
    "/stats",
    response_model=AdminOverviewStats,
    summary="Thống kê tổng quan hệ thống",
)
def get_overview_stats(
    target_date: date | None = Query(None, description="Ngày cần xem thống kê (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    _: User | None = Depends(check_admin_access),
) -> AdminOverviewStats:
    """Lấy các chỉ số KPI: tổng số trường, lớp, học sinh, giáo viên và tiến độ báo cáo ngày."""
    return admin_dashboard_service.get_overview_stats(db, target_date=target_date)


@router.get(
    "/classes-progress",
    response_model=list[ClassProgressStat],
    summary="Tiến độ báo cáo theo từng lớp",
)
def get_classes_progress(
    target_date: date | None = Query(None, description="Ngày cần xem tiến độ (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    _: User | None = Depends(check_admin_access),
) -> list[ClassProgressStat]:
    """Danh sách tất cả các lớp kèm số học sinh đã hoàn thành / còn nợ báo cáo ngày."""
    return admin_dashboard_service.get_classes_progress(db, target_date=target_date)


@router.get(
    "/report-trends",
    response_model=list[ReportTrendItem],
    summary="Biểu đồ xu hướng báo cáo",
)
def get_report_trends(
    days: int = Query(7, ge=1, le=60, description="Số ngày gần nhất cần thống kê (1 - 60 ngày)"),
    db: Session = Depends(get_db),
    _: User | None = Depends(check_admin_access),
) -> list[ReportTrendItem]:
    """Thống kê số lượng báo cáo (nháp / đã gửi) theo từng ngày để vẽ biểu đồ đường hoặc cột."""
    return admin_dashboard_service.get_report_trends(db, days=days)


@router.get(
    "/voice-stats",
    response_model=VoiceRecordStats,
    summary="Thống kê xử lý âm thanh STT",
)
def get_voice_stats(
    db: Session = Depends(get_db),
    _: User | None = Depends(check_admin_access),
) -> VoiceRecordStats:
    """Thống kê tổng số file ghi âm giọng nói, trạng thái xử lý PhoWhisper và tổng thời lượng."""
    return admin_dashboard_service.get_voice_record_stats(db)


@router.get(
    "/system-health",
    response_model=SystemHealthStats,
    summary="Trạng thái dịch vụ máy chủ",
)
def get_system_health(
    db: Session = Depends(get_db),
    _: User | None = Depends(check_admin_access),
) -> SystemHealthStats:
    """Kiểm tra tình trạng kết nối trực tiếp đến PostgreSQL và Redis."""
    return admin_dashboard_service.get_system_health(db)
