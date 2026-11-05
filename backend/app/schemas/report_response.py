"""
app/schemas/report_response.py
===============================
Pydantic schemas cho API "Phản hồi báo cáo" (parent/teacher replies).

Tách biệt ORM model (``app.models.report_response``) với API schemas
theo nguyên tắc Clean Architecture — không expose trực tiếp ORM object.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReportResponseOut(BaseModel):
    """1 tin nhắn phản hồi trả về cho client."""

    response_id: uuid.UUID = Field(..., description="UUID của phản hồi")
    daily_report_id: uuid.UUID = Field(..., description="UUID của báo cáo cha")
    child_id: uuid.UUID | None = Field(None, description="UUID của bé")
    author_user_id: uuid.UUID | None = Field(
        None, description="UUID người viết (NULL nếu tài khoản bị xoá)"
    )
    author_role: str = Field(
        ...,
        description="Vai trò người viết: parent | teacher | admin",
        examples=["parent"],
    )
    author_name: str = Field(..., description="Tên hiển thị người viết")
    author_avatar_url: str | None = Field(None, description="Ảnh đại diện người viết")
    content: str = Field(..., description="Nội dung phản hồi")
    has_image: bool = Field(
        False,
        description=(
            "True nếu phản hồi có ảnh đính kèm. "
            "Ảnh được đọc qua endpoint riêng có kiểm tra quyền, không trả URL."
        ),
    )
    is_read: bool = Field(False, description="Giáo viên đã đọc phản hồi này chưa")
    is_resolved: bool = Field(False, description="Giáo viên đã xử lý phản hồi này chưa")
    resolved_at: datetime | None = Field(
        None, description="Thời điểm đánh dấu đã xử lý (UTC)"
    )
    created_at: datetime | None = Field(None, description="Thời điểm gửi (UTC)")
    updated_at: datetime | None = Field(None, description="Lần sửa gần nhất (UTC)")

    model_config = ConfigDict(from_attributes=True)


class ReportResponseListResponse(BaseModel):
    """Danh sách phản hồi của 1 báo cáo (phẳng, cũ → mới)."""

    daily_report_id: uuid.UUID = Field(..., description="UUID của báo cáo")
    total: int = Field(0, description="Tổng số phản hồi")
    unread_count: int = Field(
        0,
        description="Số phản hồi của phụ huynh chưa được giáo viên đọc",
    )
    responses: list[ReportResponseOut] = Field(
        default_factory=list,
        description="Các tin nhắn phản hồi, sắp xếp theo thời gian tăng dần",
    )


class ReportResponseCreateRequest(BaseModel):
    """Payload tạo phản hồi mới (JSON — không kèm ảnh)."""

    content: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="Nội dung phản hồi",
        examples=["Bé An sốt nhẹ sáng nay, nhờ cô theo dõi thêm giúp ạ."],
    )


class ReportResponseCreateResponse(BaseModel):
    """Response sau khi tạo phản hồi thành công."""

    response: ReportResponseOut = Field(..., description="Phản hồi vừa tạo")
    total: int = Field(0, description="Tổng số phản hồi của báo cáo")
    unread_count: int = Field(
        0, description="Số phản hồi của phụ huynh chưa được giáo viên đọc"
    )


class ReportResponseResolveRequest(BaseModel):
    """Payload đánh dấu phản hồi đã xử lý (hoặc huỷ đánh dấu)."""

    resolved: bool = Field(
        True,
        description="True = đánh dấu đã xử lý, False = huỷ đánh dấu",
    )


class ReportResponseResolveResponse(BaseModel):
    """Response sau khi đánh dấu đã xử lý."""

    response: ReportResponseOut = Field(..., description="Phản hồi sau khi cập nhật")
    message: str = Field(..., description="Thông báo kết quả")
