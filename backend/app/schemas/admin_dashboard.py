from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class AdminOverviewStats(BaseModel):
    """Thống kê tổng quan toàn hệ thống cho trang Admin."""

    total_schools: int = Field(..., description="Tổng số trường học")
    total_classes: int = Field(..., description="Tổng số lớp học")
    total_children: int = Field(..., description="Tổng số trẻ em đã đăng ký")
    total_teachers: int = Field(..., description="Tổng số giáo viên")
    total_parents: int = Field(..., description="Tổng số phụ huynh")
    today_reports_count: int = Field(..., description="Tổng số báo cáo ngày được tạo hôm nay")
    today_sent_reports_count: int = Field(..., description="Số báo cáo hôm nay đã duyệt/gửi cho phụ huynh")
    today_draft_reports_count: int = Field(..., description="Số báo cáo hôm nay đang ở trạng thái nháp")
    today_completion_rate: float = Field(..., description="Tỷ lệ hoàn thành báo cáo hôm nay (%)")
    total_voice_records: int = Field(..., description="Tổng số bản ghi âm giọng nói đã tải lên")
    today_voice_records: int = Field(..., description="Số bản ghi âm trong ngày hôm nay")


class ClassProgressStat(BaseModel):
    """Tiến độ nộp báo cáo theo từng lớp học trong ngày."""

    class_id: uuid.UUID = Field(..., description="ID của lớp học")
    class_name: str = Field(..., description="Tên lớp học")
    grade_label: str | None = Field(None, description="Khối lớp")
    teacher_name: str | None = Field(None, description="Tên giáo viên chủ nhiệm")
    total_children: int = Field(..., description="Tổng số học sinh trong lớp")
    reported_children: int = Field(..., description="Số học sinh đã có báo cáo gửi/đã đọc")
    pending_children: int = Field(..., description="Số học sinh chưa có báo cáo hoặc còn nháp")
    completion_rate: float = Field(..., description="Tỷ lệ hoàn thành của lớp (%)")


class ReportTrendItem(BaseModel):
    """Dữ liệu xu hướng báo cáo theo từng ngày."""

    report_date: str = Field(..., description="Ngày báo cáo (định dạng YYYY-MM-DD)")
    total_reports: int = Field(..., description="Tổng số báo cáo trong ngày")
    sent_reports: int = Field(..., description="Số báo cáo đã gửi (sent / read)")
    draft_reports: int = Field(..., description="Số báo cáo nháp (draft)")


class VoiceRecordStats(BaseModel):
    """Thống kê chi tiết hoạt động ghi âm và xử lý STT."""

    total_records: int = Field(..., description="Tổng số file ghi âm")
    completed_records: int = Field(..., description="Số file xử lý thành công")
    pending_records: int = Field(..., description="Số file đang chờ hoặc đang xử lý")
    failed_records: int = Field(..., description="Số file xử lý thất bại")
    total_duration_seconds: float = Field(..., description="Tổng thời lượng ghi âm (giây)")


class SystemHealthStats(BaseModel):
    """Thông tin trạng thái hoạt động của các dịch vụ hạ tầng."""

    database_status: str = Field(..., description="Trạng thái kết nối PostgreSQL (healthy / error)")
    redis_status: str = Field(..., description="Trạng thái kết nối Redis (healthy / error)")
    api_status: str = Field("healthy", description="Trạng thái FastAPI server")
    server_time: datetime = Field(..., description="Thời gian hiện tại của hệ thống")
