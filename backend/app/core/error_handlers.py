"""
backend/app/core/error_handlers.py
==================================
Chuẩn hóa xử lý ngoại lệ cho toàn bộ Backend FastAPI:
- Chuyển đổi lỗi Pydantic (RequestValidationError 422) thành thông điệp tiếng Việt thân thiện,
  dễ hiểu cho người dùng cuối trên mọi màn hình ứng dụng (trừ admin-web).
- Đảm bảo mã lỗi HTTP (400, 401, 403, 404, 409, 422, 500) trả về cấu trúc đồng nhất
  với 'detail' và 'message' rõ nghĩa.
"""

from typing import Any
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

FIELD_TRANSLATIONS: dict[str, str] = {
    "full_name": "Họ và tên",
    "nickname": "Tên biệt danh",
    "date_of_birth": "Ngày sinh",
    "gender": "Giới tính",
    "medical_allergies": "Dị ứng & Sức khỏe",
    "phone": "Số điện thoại",
    "email": "Địa chỉ email",
    "username": "Tên đăng nhập",
    "password": "Mật khẩu",
    "new_password": "Mật khẩu mới",
    "current_password": "Mật khẩu hiện tại",
    "class_id": "Lớp học",
    "teacher_id": "Giáo viên",
    "child_id": "Trẻ",
    "parent_id": "Phụ huynh",
    "summary_text": "Nội dung nhận xét",
    "title": "Tiêu đề",
    "description": "Mô tả",
    "content": "Nội dung",
    "status": "Trạng thái",
    "role": "Vai trò",
    "otp": "Mã xác thực",
    "code": "Mã",
}


def _translate_loc(loc: tuple[Any, ...] | list[Any]) -> str:
    for item in reversed(loc):
        if isinstance(item, str) and item not in ("body", "query", "path"):
            return FIELD_TRANSLATIONS.get(item, item)
    return "Dữ liệu"


def format_validation_error(err: dict[str, Any]) -> str:
    loc = err.get("loc", ())
    err_type = str(err.get("type", ""))
    msg = str(err.get("msg", ""))
    field = _translate_loc(loc)

    if err_type == "missing":
        return f"Vui lòng cung cấp {field.lower()}."
    if "string_too_short" in err_type:
        return f"{field} quá ngắn, vui lòng kiểm tra lại."
    if "string_too_long" in err_type:
        return f"{field} vượt quá độ dài tối đa cho phép."
    if "string_pattern_mismatch" in err_type:
        if field == "Số điện thoại":
            return "Số điện thoại không đúng định dạng (10–11 chữ số, bắt đầu bằng số 0)."
        return f"{field} không đúng định dạng quy định."
    if "date" in err_type or "datetime" in err_type:
        return f"{field} không đúng định dạng ngày tháng hợp lệ (YYYY-MM-DD)."
    if "int" in err_type or "float" in err_type:
        return f"{field} phải là chữ số hợp lệ."
    if "enum" in err_type:
        return f"{field} phải thuộc danh sách các giá trị hợp lệ."
    if "value_error" in err_type and msg:
        clean_msg = msg.removeprefix("Value error,").strip()
        return clean_msg if clean_msg else f"{field} không hợp lệ."
    return f"Thông tin '{field}' không hợp lệ hoặc chưa đúng định dạng."


def register_error_handlers(app: FastAPI) -> None:
    """Đăng ký các bộ xử lý lỗi tiêu chuẩn cho ứng dụng FastAPI."""

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        errors = exc.errors()
        messages = [format_validation_error(err) for err in errors]
        friendly_msg = (
            " ".join(messages)
            if messages
            else "Dữ liệu nhập vào chưa đúng định dạng. Vui lòng kiểm tra lại."
        )
        return JSONResponse(
            status_code=422,
            content={
                "detail": friendly_msg,
                "message": friendly_msg,
                "errors": [
                    {
                        "loc": err.get("loc"),
                        "msg": format_validation_error(err),
                        "type": err.get("type"),
                    }
                    for err in errors
                ],
            },
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        detail = exc.detail
        # Nếu detail là chuỗi mặc định tiếng Anh từ framework, chuyển sang tiếng Việt thân thiện
        if isinstance(detail, str):
            clean_detail = detail.strip()
            english_to_vietnamese = {
                "Not Found": "Không tìm thấy dữ liệu yêu cầu trên hệ thống.",
                "Method Not Allowed": "Phương thức yêu cầu không được hỗ trợ.",
                "Internal Server Error": "Hệ thống máy chủ đang gặp sự cố. Vui lòng thử lại sau.",
                "Unauthorized": "Phiên làm việc đã hết hạn hoặc chưa được xác thực. Vui lòng đăng nhập lại.",
                "Forbidden": "Bạn không có quyền thực hiện thao tác này.",
                "Bad Request": "Yêu cầu không hợp lệ. Vui lòng kiểm tra lại thông tin.",
            }
            if clean_detail in english_to_vietnamese:
                clean_detail = english_to_vietnamese[clean_detail]
            return JSONResponse(
                status_code=exc.status_code,
                content={"detail": clean_detail, "message": clean_detail},
                headers=exc.headers,
            )

        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": detail, "message": str(detail)},
            headers=exc.headers,
        )
