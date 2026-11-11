# Tài liệu thiết kế — cách đọc nguồn

Hướng dẫn bàn giao UI hiện tại nằm trong
[design-system/kinderlog](../../design-system/kinderlog/FIGMA-MAP.md): mapping
node/code/test, baseline Flutter, component/asset và visual QA. Quy tắc cho Agent
ở [frontend/AGENTS.md](../../frontend/AGENTS.md).

Các file trong thư mục này được giữ để hiểu lịch sử yêu cầu. Một prompt mô tả
điều muốn tạo trong Make không chứng minh thiết kế đã được áp dụng hay phê duyệt.
Khi implement UI, dùng node được giao cùng context/screenshot live; không copy
palette/font/layout từ prompt cũ nếu khác node đó.

| Tài liệu | Vai trò |
|---|---|
| `parent-screen-figma-make-prompt.md` | Prompt v4 cũ, palette teal/cream; không dùng làm token hiện tại. |
| `parent-health-profile-figma-prompt.md` | Brief tương tác cho Make, tự ghi chưa được áp dụng/xác minh. |
| `parent-health-profile-figma-prompt.v1-archived.md` | Bản lưu trữ trước brief tương tác. |
| `attendance-figma-prompt.md`, `attendance-figma-fix-prompt.md` | Prompt tạo/sửa prototype; không tự biến thành yêu cầu đổi runtime. |
| `parent-requests-implementation.md` | Ghi nhận implementation/API của task cũ; đối chiếu code/API hiện tại khi dùng. |
| `ui-audit-2026-10-18.md` | Audit có mốc ngày; không phải kết quả kiểm tra hiện tại. |

`.gitignore` cho phép các file Markdown ngay trong `docs/design/`; không mở toàn
bộ `docs/` cho binary, dữ liệu hoặc ghi chép riêng. Không ghi tài khoản/token,
thông tin trẻ thật hoặc asset URL Figma tạm vào tài liệu được version.
