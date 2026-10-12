# Bug Report — User Guide

> Hướng dẫn gửi báo cáo lỗi từ ứng dụng KinderLog dành cho **giáo viên** và **phụ huynh**.

---

## 1. Khi nào nên gửi báo cáo lỗi?

Bạn nên gửi báo cáo lỗi khi gặp phải **bất kỳ vấn đề nào** sau đây trong ứng dụng:

| Vấn đề | Ví dụ |
|---|---|
| **App bị crash / đứng** | App thoát ra khi đang dùng, màn hình trắng, không phản hồi |
| **Giao diện bị lỗi** | Chữ bị cắt, button không bấm được, hình ảnh hiển thị sai |
| **Dữ liệu sai / mất** | Báo cáo của bé bị thiếu, thông tin không đúng |
| **Không nhận được thông báo** | Đã bật notification nhưng không thấy báo cáo mới |
| **Upload / tải chậm** | Upload audio bị timeout, tải báo cáo lâu |
| **Không đăng nhập được** | Quên mật khẩu, tài khoản bị khóa |
| **Hiệu năng kém** | App chạy chậm, pin tụt nhanh |
| **Khác** | Bất kỳ vấn đề nào khác |

> 💡 **Mẹo:** Nếu bạn không chắc chắn đó là lỗi hay chỉ là cách hoạt động bình thường,
> hãy gửi báo cáo — team sẽ phản hồi!

---

## 2. Cách gửi báo cáo lỗi từ app

### Bước 1: Mở màn hình "Báo cáo lỗi"

1. Đăng nhập vào app KinderLog.
2. Mở menu **Cài đặt** (Settings) — thường ở góc phải trên cùng hoặc trong menu hamburger.
3. Chọn **Trợ giúp & Hỗ trợ** → **Báo cáo lỗi**.

> (Nếu chưa thấy mục này, hãy cập nhật app lên phiên bản mới nhất.)

### Bước 2: Điền thông tin bắt buộc

Bạn sẽ thấy form với 2 trường bắt buộc:

| Trường | Mô tả | Ví dụ |
|---|---|---|
| **Tiêu đề** | Tóm tắt ngắn gọn lỗi, tối đa 200 ký tự | "App crash khi mở báo cáo của bé An" |
| **Mô tả chi tiết** | Mô tả các bước tái hiện, tối đa 4000 ký tự | "1) Mở Dashboard 2) Bấm vào bé An 3) App thoát ra ngay" |

### Bước 3: (Tùy chọn) Chọn loại lỗi và mức độ nghiêm trọng

| Loại lỗi | Khi nào chọn |
|---|---|
| **Giao diện** | Lỗi hiển thị, bố cục, màu sắc |
| **Hiệu năng** | App chậm, lag |
| **Crash** | App bị thoát / đóng băng |
| **Dữ liệu** | Sai hoặc mất dữ liệu |
| **Thông báo** | Không nhận được push / email |
| **Mạng** | Lỗi kết nối |
| **Xác thực** | Lỗi đăng nhập |
| **Khác** | Các lỗi khác |

| Mức độ | Khi nào chọn |
|---|---|
| **Thấp** | Lỗi nhỏ, không ảnh hưởng nhiều |
| **Trung bình** | Ảnh hưởng một phần trải nghiệm (mặc định) |
| **Cao** | Ảnh hưởng lớn, cần sửa sớm |
| **Nghiêm trọng** | App không thể dùng được |

### Bước 4: (Tùy chọn) Đính kèm ảnh chụp màn hình

Bạn có thể đính kèm **tối đa 5 ảnh** chụp màn hình để team dễ hiểu lỗi hơn.

- Mỗi ảnh tối đa **5 MB**.
- Định dạng: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`.
- Bấm vào biểu tượng **📷 Camera** để chụp ảnh mới, hoặc **🖼️ Gallery** để chọn từ thư viện.

> 💡 **Mẹo:** Chụp ảnh cả màn hình đang bị lỗi (không che thông tin quan trọng khác).

### Bước 5: Gửi báo cáo

1. Kiểm tra lại thông tin.
2. Bấm nút **Gửi báo cáo** ở cuối form.
3. Đợi vài giây — bạn sẽ thấy thông báo **"Gửi báo cáo thành công"** và quay về màn hình trước.

> 📬 Sau khi gửi, team admin sẽ nhận được thông báo qua email + push notification
> và bắt đầu xử lý trong vòng 24 giờ (với lỗi nghiêm trọng).

---

## 3. Theo dõi trạng thái báo cáo của bạn

### Mở danh sách báo cáo

1. **Cài đặt** → **Trợ giúp & Hỗ trợ** → **Lịch sử báo cáo lỗi** (hoặc **Bug reports của tôi**).

Bạn sẽ thấy danh sách các báo cáo đã gửi, sắp xếp theo thời gian mới nhất.

### Trạng thái báo cáo

| Trạng thái | Ý nghĩa | Bạn cần làm gì |
|---|---|---|
| 🆕 **Mới** (`open`) | Team đã nhận được, chưa xem | Chờ phản hồi |
| 🔧 **Đang xử lý** (`in_progress`) | Admin đang fix | Chờ bản cập nhật |
| ✅ **Đã xử lý** (`resolved`) | Đã fix, chờ bạn xác nhận | Cập nhật app lên bản mới, kiểm tra lỗi, báo lại nếu vẫn còn |
| 📁 **Đã đóng** (`closed`) | Đã xong hoặc không sửa | Không cần làm gì |
| 🚫 **Không sửa** (`wont_fix`) | Trùng lặp / ngoài phạm vi | Xem lý do trong chi tiết |

### Xem chi tiết một báo cáo

Bấm vào một dòng trong danh sách để xem:
- Mô tả đầy đủ
- Ảnh đính kèm (bấm để phóng to)
- Lịch sử trạng thái (audit trail)
- Phản hồi / ghi chú từ admin (nếu có)

---

## 4. Câu hỏi thường gặp (FAQ)

### Tôi gửi báo cáo nhưng không thấy admin phản hồi?

- Báo cáo **Nghiêm trọng** được phản hồi trong vòng **24 giờ**.
- Báo cáo **Cao** trong vòng **3 ngày**.
- Báo cáo **Trung bình** trong vòng **1 tuần**.
- Báo cáo **Thấp** trong vòng **2 tuần**.

Nếu quá thời gian trên mà chưa có phản hồi, hãy gửi báo cáo mới nhắc lại.

### Tôi gửi nhầm báo cáo. Xóa được không?

Hiện tại app **chưa hỗ trợ xóa báo cáo**. Tuy nhiên bạn có thể:
- Bấm vào báo cáo → **Yêu cầu đóng** (nếu có button này).
- Hoặc gửi báo cáo mới với tiêu đề "[HỦY] ..." kèm link báo cáo cũ.

### Tôi không đính kèm được ảnh?

- Kiểm tra ảnh có dung lượng ≤ **5 MB** không.
- Kiểm tra app có quyền truy cập **Camera** và **Bộ nhớ** chưa (vào Cài đặt điện thoại → Apps → KinderLog → Quyền).
- Nếu vẫn lỗi, hãy chụp màn hình bằng nút nguồn + volume, sau đó gửi qua Zalo/email cho team.

### Tôi bị mất mạng khi đang gửi báo cáo?

App tự động lưu báo cáo vào **Outbox cục bộ** và sẽ **tự động gửi lại** khi có mạng.
Bạn không cần làm gì thêm.

### Tôi gửi quá nhiều báo cáo, có bị khóa tài khoản không?

- Hệ thống giới hạn **10 báo cáo / user / giờ** để tránh spam.
- Nếu vượt quá, bạn sẽ nhận thông báo *"Bạn đã gửi quá nhiều báo cáo. Vui lòng thử lại sau."*
- Sau 1 giờ, bạn có thể gửi tiếp.
- Tài khoản **không bị khóa** — chỉ là tạm thời không thể gửi mới.

### Tôi có thể gửi báo cáo ẩn danh không?

Không. Mọi báo cáo đều phải gắn với tài khoản đã đăng nhập để admin có thể phản hồi cho bạn.

---

## 5. Mẹo viết báo cáo hiệu quả

Một báo cáo tốt giúp team fix nhanh hơn **5-10 lần**. Hãy bao gồm:

### ✅ Nên làm

1. **Tóm tắt ngắn gọn trong tiêu đề**
   - ✅ "App crash khi mở báo cáo của bé An"
   - ❌ "App bị lỗi"

2. **Mô tả các bước tái hiện (steps to reproduce)**
   ```
   1. Mở app
   2. Đăng nhập với tài khoản phụ huynh
   3. Mở Dashboard
   4. Bấm vào "Báo cáo của bé An"
   5. App thoát ra ngay
   ```

3. **Mô tả kết quả mong đợi vs thực tế**
   ```
   Mong đợi: Mở được báo cáo của bé An
   Thực tế:  App crash, màn hình trắng rồi thoát
   ```

4. **Đính kèm screenshot / video** (nếu có)

5. **Ghi rõ điện thoại và phiên bản app**
   - Samsung Galaxy A54, Android 14, KinderLog 1.2.3 (build 42)

### ❌ Không nên

- Để trống tiêu đề / mô tả
- Chỉ ghi "App bị lỗi" mà không mô tả chi tiết
- Gửi nhiều báo cáo trùng nhau
- Dùng ngôn từ không phù hợp

---

## 6. Liên hệ hỗ trợ

Nếu bạn cần hỗ trợ khẩn cấp (không phải bug), liên hệ:

- **Email:** support@kinderlog.app
- **Hotline:** 0901-234-567 (giờ hành chính)
- **Zalo OA:** KinderLog

> ⚠️ Các kênh trên **CHỈ** dành cho hỗ trợ. Mọi feedback về lỗi, vui lòng gửi qua
> chức năng **Báo cáo lỗi** trong app để team xử lý nhanh nhất.
