# [UI][Parent Health] Prompt V1 — lưu trữ, không dùng để sửa Make app hiện có

**Bản lưu trữ, không copy lại.** Giữ nội dung cũ để đối chiếu. Bản hiện hành dùng
chỉ dẫn tiếng Anh, tập trung UI/UX blueprint để duyệt trước khi triển khai Flutter;
thay thế cả V1 và hướng sửa routing/state của V2. Xem tại
[parent-health-profile-figma-prompt.md](parent-health-profile-figma-prompt.md).

Đầu ra ở bước này là **prompt**, chưa phải canvas Figma đã được tạo hay kiểm tra.
Copy nguyên khối bên dưới vào Figma Make. Có thể đính kèm ảnh màn Tài khoản phụ
huynh hiện tại đã ẩn dữ liệu cá nhân để giữ đúng bố cục. Không tải hồ sơ sức khỏe
thật của trẻ lên công cụ tạo mẫu.

```text
Thiết kế một prototype UI high-fidelity cho US “Phụ huynh cập nhật hồ sơ sức khỏe
của bé” trong ứng dụng KinderLog. Đây là mở rộng app Flutter Android đã có,
không phải thiết kế lại toàn bộ app và không phải ứng dụng bệnh án.

MỤC TIÊU VÀ PHẠM VI
- Phụ huynh chỉnh sửa dị ứng và lưu ý chăm sóc lâu dài của đúng bé được liên kết.
- Giáo viên và admin xem cùng thông tin sau khi tải lại dữ liệu.
- Không làm lời dặn theo ngày, chat, push, AI tư vấn, kê thuốc, biểu đồ tăng trưởng,
  quy trình duyệt hoặc trạng thái giáo viên đã xem.
- Toàn bộ chữ trên giao diện bằng tiếng Việt, rõ ràng, ngắn gọn.
- Dùng dữ liệu giả: bé Nguyễn Minh An, lớp Mầm 1. Avatar chữ “MA”, không cần ảnh trẻ.

GIỮ NHẬN DIỆN KINDERLOG
- Font Be Vietnam Pro, không tự đổi sang Inter. Nếu không có font, báo rõ.
- Phong cách Material 3: gần gũi, gọn, đáng tin, ưu tiên thao tác và khả năng đọc.
- Light: nền #F6F4EF, surface #FFFFFF, surface-sunken #EFECE5;
  chữ chính #2A2926, chữ phụ #605D57, đường chia #E7E3DA;
  brand #16665A, brand-strong #114F46, brand-tint #E6EFEC;
  cảnh báo #8A5E12 trên #F6EED9, lỗi #BB4A34 trên #F6E6E1.
- Dark: nền #1C1B1A, surface #252422, surface-sunken #2D2C29;
  chữ chính #E8E6E1, chữ phụ #C4C2BC, brand #52BBA8.
  Nút nền brand sáng trong dark mode dùng chữ tối tương phản, không dùng chữ trắng.
- Nếu file có design system tương ứng, reuse components, variables và text styles.
  Nếu chưa có, đặt tên các giá trị trên thành token nhất quán cho prototype.
- Spacing 4/8/12/16/20/24/32; radius card 12, control 8.
- Icon Material dạng outline, cùng một họ; không emoji, không hình minh họa trang trí.
- Không thêm gradient/glassmorphism/hero lớn hay dashboard mới.

MÀN 1 — PARENT / TÀI KHOẢN
- Giữ cấu trúc hiện tại: thông tin phụ huynh, thông tin liên hệ, Thông tin bé,
  cài đặt và thanh điều hướng hai mục Tổng quan / Tài khoản.
- Trong card Thông tin bé, thêm hàng luôn hiển thị “Hồ sơ sức khỏe”, icon sức khỏe,
  tóm tắt “Chưa khai báo” hoặc “Có thông tin cần lưu ý”, chevron bên phải.
- Chạm hàng này mở màn cập nhật riêng. Không thêm tab điều hướng mới.
- Hàng phải hiện cả khi bé chưa có dị ứng hay lưu ý nào.

MÀN 2 — PARENT / THÔNG TIN SỨC KHỎE
- App bar có Quay lại và tiêu đề “Thông tin sức khỏe”.
- Đầu nội dung: avatar MA, Nguyễn Minh An, Lớp Mầm 1 để tránh sửa nhầm bé.
- Dòng hướng dẫn: “Cập nhật thông tin lâu dài để giáo viên lưu ý khi chăm sóc bé.”
- Phần Dị ứng: ba lựa chọn radio xếp dọc, có nhãn đầy đủ:
  1. Chưa khai báo
  2. Không có dị ứng được biết
  3. Có dị ứng
- Không chọn sẵn “Không có dị ứng được biết” khi chưa có dữ liệu.
- Chọn Có dị ứng thì hiện ô multiline “Mô tả dị ứng”, bắt buộc nhập;
  placeholder “Ví dụ: Đậu phộng, hải sản…”, bộ đếm tối đa 1000 ký tự.
- Hai lựa chọn còn lại ẩn ô mô tả; chuyển lựa chọn chưa được tự lưu lên server.
- Phần “Lưu ý chăm sóc”: ô multiline không bắt buộc, tối đa 1000 ký tự;
  placeholder “Những lưu ý lâu dài khi chăm sóc bé”.
  Helper: “Không dùng để gửi lời dặn trong ngày hoặc yêu cầu dùng thuốc.”
- Metadata: “Cập nhật hồ sơ gần nhất: Phụ huynh · 18/10/2026, 07:30”.
  Với dữ liệu cũ thiếu nguồn/thời gian, hiện “Thông tin từ hồ sơ hiện có”.
  Với hồ sơ chưa khai báo, không dựng sẵn người cập nhật hoặc thời gian giả.
- Thanh hành động cuối màn có nút “Lưu thay đổi”, disabled nếu chưa thay đổi;
  loading có spinner và “Đang lưu…”, ngăn gửi lặp.
- Không đặt bottom navigation ở màn chỉnh sửa để giữ tập trung.

TRẠNG THÁI VÀ TƯƠNG TÁC
- Có mẫu Chưa khai báo, Không có dị ứng được biết và Có dị ứng với mô tả giả
  “Đậu phộng”; các trạng thái không được đánh đồng.
- Chọn Có dị ứng nhưng bỏ trống mô tả: lỗi ngay dưới field, focus vào field lỗi.
- Vượt giới hạn: chỉ rõ field cần sửa; không xóa hoặc cắt ngầm nội dung.
- Lưu thành công: trở về Tài khoản, tóm tắt cập nhật, SnackBar
  “Đã cập nhật thông tin sức khỏe”. Không dùng “Nhà trường đã nắm thông tin”.
- Lỗi tải: có Thử lại và Quay lại; không hiển thị form trắng như dữ liệu thật.
- Lỗi lưu/mất mạng: giữ nguyên dữ liệu đang nhập, hiện thông báo và cho thử lại;
  không báo thành công, không hiện raw exception.
- Dữ liệu đã bị người khác sửa: hiện “Hồ sơ vừa được cập nhật ở nơi khác.
  Vui lòng tải lại trước khi lưu.” Không có nút ghi đè bất chấp.
- Nếu đang có dị ứng mà đổi sang Không có/Chưa khai báo, xác nhận trước khi lưu:
  tiêu đề “Thay đổi thông tin dị ứng?”, mô tả rõ thông tin cũ sẽ được thay thế;
  nút “Tiếp tục chỉnh sửa” / “Xác nhận thay đổi”. Không gọi đây là xác nhận y tế.
- Back khi có thay đổi chưa lưu: dialog “Bỏ thay đổi?”;
  nút “Tiếp tục chỉnh sửa” / “Bỏ thay đổi”.

THẺ THAM CHIẾU CHO GIÁO VIÊN VÀ ADMIN
- Thêm hai biến thể read-only của card “Sức khỏe của bé”, không vẽ lại dashboard.
- Dùng cùng dữ liệu với form: trạng thái dị ứng, mô tả, lưu ý chăm sóc,
  nguồn và thời gian cập nhật hồ sơ gần nhất.
- Giáo viên cần đọc nhanh: dị ứng đặt trước, lưu ý chăm sóc sau; text dài được
  mở rộng/đọc đầy đủ. Không tự chấm mức độ bệnh hoặc đổi trạng thái báo cáo.
- Trong mẫu này không có nút duyệt, đánh dấu đã xem hay gửi thông báo.
- “Chưa khai báo” là trạng thái trung tính, không biến thành kết luận bé khỏe.

RESPONSIVE VÀ ACCESSIBILITY
- Mẫu chính 375×812; thêm bản form dark mode và preview 320 px, 1440 px.
- Web desktop giữ nội dung form rộng tối đa khoảng 560 px, không kéo giãn toàn trang.
- Nội dung cuộn được, safe area đầy đủ; nút Lưu không che field cuối.
- Khi mở bàn phím, form vẫn cuộn tới field đang nhập và thao tác Lưu.
- Touch target Android tối thiểu 48×48 dp; nhãn text đầy đủ cho icon button.
- Text thông thường tương phản ít nhất 4.5:1, ranh giới control đủ rõ;
  hỗ trợ cỡ chữ 200%, không ép fixed-height khiến chữ bị cắt.
- Báo lỗi bằng text và trạng thái, không chỉ bằng màu; motion tối giản.

ĐẦU RA
- Hai màn chính, các biến thể trạng thái của form, bản dark mode, hai card read-only.
- Prototype click được luồng Tài khoản → chỉnh sửa → xác nhận/lưu → cập nhật tóm tắt.
- Tái sử dụng các thành phần giữa các trạng thái; không tạo nhiều thiết kế rời rạc.
- Dùng state giả trong bộ nhớ để minh họa, không kết nối API thật và không lưu
  thông tin sức khỏe vào localStorage. Prototype không phải bằng chứng đồng bộ backend.
```
