# [UI][Garden Voice] bàn giao WIP refactor Batch 1–5

Bản chụp công việc để team tiếp tục sửa, **chưa nghiệm thu layout và không sẵn
sàng merge/release**. Người dùng yêu cầu push trước dù UI còn sai nhiều chỗ.

## Phạm vi

- Flutter Teacher/Parent, token Garden Voice, asset/font local và các test UI.
- Tích hợp API/push liên quan: điểm danh, duyệt đơn, thuốc, cảnh báo sức khỏe,
  phân quyền approve/send/delete draft báo cáo.
- Mapping: `design-system/kinderlog/FIGMA-MAP.md`, `COMPONENT-MAP.md`,
  `VISUAL-QA.md`. Dùng frame Figma được giao làm chuẩn; test xanh không có nghĩa
  layout đã đúng. Cần tiếp tục rà layout trên thiết bị.
- Không đưa cấu hình agent, dữ liệu local, `.env`, model weights hoặc build output
  vào bản bàn giao.

## Kiểm tra đã chạy trước bàn giao

- `flutter analyze`: không có issue.
- UI capture suite: 40/40; PNG sinh ở `frontend/build/ui-captures/`, không commit.
- Test Batch 5: 13/13.
- Full `flutter test`: 385 pass / 9 fail. Các lỗi còn lại:
  - `login_and_parent_test.dart`: mở report, xác nhận logout, mở timetable.
  - `push_open_report_test.dart`: report cũ của bé thứ hai, initialOpenReport,
    chạm push khi màn Parent đang mở.
  - `push_open_attendance_test.dart`: mở lớp/ngày/danh sách bé từ push điểm danh.
  - `teacher_medication_test.dart`: xác nhận thuốc và form cảnh báo sự cố.
- Backend lint/test chưa chạy được trên máy bàn giao (không có Docker/Ruff/Python
  dùng được); cần chạy CI hoặc môi trường backend trước khi merge.

## Rủi ro còn lại

- Nhiều layout chưa khớp Figma; chưa sign-off pixel/dark mode/Android thật.
- Chưa xác minh mở Settings và microphone thật trên Android.
- Batch send chỉ báo hoàn tất khi các ID đã được xác nhận; timeout sau commit
  vẫn có thể khiến publish fallback gửi lại vì chưa có idempotency/status lookup.
- Branch WIP dựa trên HEAD local hiện có; không tự merge/rebase `origin/develop`
  trong phiên bàn giao để tránh trộn thay đổi mới của team.

## Chạy lại

- Flutter: dừng rồi chạy ▶ để nạp asset/font mới.
- Backend Python: API hot-reload, worker cần `docker compose restart worker`.
- Không có migration, requirements hoặc Dockerfile mới trong bản bàn giao này.
