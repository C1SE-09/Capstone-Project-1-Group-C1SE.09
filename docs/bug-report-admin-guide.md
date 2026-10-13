# Bug Report — Admin Guide

> Hướng dẫn xử lý báo cáo lỗi từ dashboard admin dành cho **quản trị viên (admin)**.

---

## 1. Tổng quan quy trình xử lý

```
┌─────────┐    ┌───────────────┐    ┌────────────┐    ┌──────────┐    ┌─────────┐
│  User   │───▶│  Admin nhận   │───▶│ Triage &   │───▶│   Fix &  │───▶│ User xác │
│ report  │    │ notification  │    │ assign     │    │ deploy   │    │ nhận     │
└─────────┘    └───────────────┘    └────────────┘    └──────────┘    └─────────┘
     │                                                                      │
     │              ┌─────────────────────────────────────────────────────┘
     │              ▼
     │         ┌──────────┐
     │         │  Closed  │  (hoặc Reopen nếu user báo vẫn lỗi)
     │         └──────────┘
     │
     └─── Có thể kết thúc ở `wont_fix` (nếu duplicate / outside scope)
```

**SLA khuyến nghị:**

| Severity | Phản hồi đầu tiên | Fix xong |
|---|---|---|
| **Critical** | 4 giờ | 24 giờ |
| **High** | 8 giờ | 3 ngày |
| **Medium** | 24 giờ | 1 tuần |
| **Low** | 3 ngày | 2 tuần |

---

## 2. Nhận thông báo có bug report mới

Khi user gửi bug report, bạn sẽ nhận được:

### 2.1. Email

- **Tiêu đề:** `[KinderLog] [Bug Report] {severity_emoji} {title}`
- **Ví dụ:** `[KinderLog] [Bug Report] 🔴 [CRITICAL] App crash khi mở báo cáo của bé An`
- **Người nhận:**
  - Nếu `BUG_REPORT_NOTIFY_EMAIL` được set → gửi tới các email trong danh sách.
  - Nếu rỗng → tự động tìm tất cả `User.role=ADMIN` có email và gửi.

Nội dung email bao gồm:
- Tiêu đề, mô tả
- Mức độ nghiêm trọng, loại lỗi
- Thông tin môi trường (app version, OS, device)
- Link tới admin dashboard để xem chi tiết

### 2.2. Push notification (FCM)

- **Tiêu đề:** `[Bug Report] {severity} {title}`
- **Body:** Rút gọn mô tả + link tới report
- **Critical** sẽ có prefix `[CRITICAL]` để dễ phân biệt.

### 2.3. Trong dashboard admin

- Tất cả bug reports hiển thị ở menu **Bug Reports** → **All Reports**.
- Báo cáo mới có badge "NEW" (trong 24h đầu).

---

## 3. Xem danh sách bug reports

### 3.1. Truy cập

1. Đăng nhập với tài khoản admin.
2. Vào menu **Bug Reports** → **All Reports**.

### 3.2. Bộ lọc (filter)

Có thể filter theo:

| Bộ lọc | Mô tả |
|---|---|
| **Status** | open, in_progress, resolved, closed, wont_fix |
| **Severity** | low, medium, high, critical |
| **Category** | ui, performance, crash, data, notification, network, auth, other |
| **Role** | teacher, parent, admin |
| **Khoảng thời gian** | date_from → date_to (created_at) |
| **Search** | Tìm kiếm theo tiêu đề (case-insensitive) |
| **Assignee** | Filter theo teacher_id đã được assign |

**Tip:** Filter nhanh nhất cho daily triage:

```
status = open, in_progress
order_by = severity_desc
```

→ Hiển thị critical → high → medium → low, ưu tiên xử lý trước.

### 3.3. Sắp xếp (sort)

- **created_at_desc** (mặc định) — Mới nhất trước
- **created_at_asc** — Cũ nhất trước
- **severity_desc** — Critical trước

### 3.4. Phân trang

- 20 reports / trang (mặc định)
- Tối đa 100 / trang

---

## 4. Xem chi tiết một bug report

Bấm vào 1 dòng trong danh sách để mở **Detail Panel** gồm:

### 4.1. Thông tin chính (header)

```
┌──────────────────────────────────────────────┐
│ [HIGH] [CRASH] App crash khi mở báo cáo     │
│ Trạng thái: 🔧 In Progress   Assignee: Cô Mai│
│ Reporter: comai (teacher) • 2 giờ trước       │
└──────────────────────────────────────────────┘
```

### 4.2. Mô tả

Hiển thị đầy đủ text mà user nhập.

### 4.3. Ảnh đính kèm

- Grid 3 cột, mỗi ảnh ~150x150px.
- Bấm vào ảnh để xem full size (zoom in/out).
- Bấm chuột phải để download.

### 4.4. Metadata môi trường

| Field | Ý nghĩa |
|---|---|
| **App version** | Phiên bản app (vd: `1.2.3`) |
| **Build number** | Số build (vd: `42`) |
| **OS version** | Hệ điều hành (vd: `Android 14`) |
| **Device model** | Model thiết bị (vd: `Samsung SM-A546B`) |
| **Network type** | Loại mạng khi xảy ra lỗi |

### 4.5. Lịch sử thay đổi (audit trail)

Mỗi status / assignment change đều ghi lại:

```
2026-10-12 10:00  comai (teacher)    open         (created)
2026-10-12 11:30  admin              open → in_progress
                  "Đang fix responsive layout"
2026-10-12 14:00  admin              in_progress → resolved
                  "Đã fix bằng SafeArea. Build 1.2.3 deploy"
```

### 4.6. Nút hành động

- **Change Status** — Mở dropdown chọn status mới
- **Assign to Teacher** — Dropdown chọn giáo viên
- **Add Comment** — Thêm ghi chú (sẽ lưu vào history)
- **Add Attachments** — Upload thêm ảnh
- **Delete** — Chỉ dành cho admin cấp cao (cẩn thận!)

---

## 5. Xử lý một bug report

### 5.1. Workflow tiêu chuẩn

```
1. Mở report từ danh sách
2. Đọc mô tả + xem ảnh
3. Tìm hiểu vấn đề (đọc code, reproduce, hỏi user thêm nếu cần)
4. Assign cho giáo viên phụ trách (nếu cần)
5. Đổi status: open → in_progress
6. Thêm comment giải thích đang làm gì
7. Fix code + test
8. Deploy lên TestFlight / staging
9. Đổi status: in_progress → resolved
10. Thêm comment ghi rõ PR #, version, link release notes
11. Đợi user xác nhận
12. Nếu OK → closed. Nếu vẫn lỗi → reopen (in_progress) hoặc để resolved và tạo report mới
```

### 5.2. Đổi status

1. Bấm nút **Change Status**.
2. Chọn status mới từ dropdown.
3. (Bắt buộc nếu không phải wont_fix) Nhập **comment** giải thích.
4. Bấm **Save**.

Side effects:
- 1 entry mới được ghi vào `bug_report_history` (audit trail).
- Nếu status = `resolved` → `resolved_at = NOW()`.
- Nếu status = `closed` → `closed_at = NOW()`.
- Celery task `notify_user_status_changed` được dispatch:
  - Push notification (FCM) cho user tạo report.
  - Email cho user (nếu có email).

### 5.3. Assign cho giáo viên

1. Bấm nút **Assign to Teacher**.
2. Chọn giáo viên từ dropdown.
3. Nhập comment (vd: "Bạn xử lý lỗi này nhé").
4. Bấm **Save**.

Side effects:
- 1 entry mới trong history với `old_teacher_id` và `new_teacher_id`.

### 5.4. Đánh dấu `wont_fix`

Chỉ dùng khi:

| Lý do | Ví dụ |
|---|---|
| **Duplicate** | Cùng lỗi với report #123 đã xử lý |
| **Outside scope** | Lỗi thuộc feature chưa ra mắt |
| **Feature request** | User nhầm lẫn gửi yêu cầu tính năng |
| **Cannot reproduce** | Đã thử 3 lần nhưng không tái hiện được |
| **User error** | Người dùng làm sai hướng dẫn |

Khi đánh wont_fix, **comment bắt buộc** phải ghi rõ lý do để user hiểu.

### 5.5. Bulk actions

Để xử lý nhanh nhiều reports cùng lúc:

1. Tick chọn nhiều reports trong danh sách.
2. Bấm **Bulk Actions** → chọn:
   - Assign to teacher X
   - Change status to closed (chỉ áp dụng cho reports đã resolved ≥ 7 ngày)
   - Delete (chỉ admin cấp cao)
3. Confirm.

---

## 6. Thống kê (Dashboard)

Menu **Bug Reports** → **Statistics** hiển thị:

### 6.1. Tổng quan

```
Tổng số reports:        156
Mới (open):             12
Đang xử lý:              8
Đã xử lý:               5  (chờ user xác nhận)
Đã đóng:               128
Không sửa:               3
```

### 6.2. Theo mức độ (severity)

```
Critical: ████░░░░░░░░░░░░░░░░  8 (5%)
High:     █████████░░░░░░░░░░░  32 (21%)
Medium:   ██████████████░░░░░  78 (50%)
Low:      ████████░░░░░░░░░░░  38 (24%)
```

### 6.3. Theo loại (category)

```
UI:           45
Performance:  32
Crash:        28
Data:         21
Notification: 18
Network:       8
Auth:          4
Other:         0
```

### 6.4. Theo thời gian

- Line chart: số reports mới / ngày trong 30 ngày qua.
- Bar chart: trung bình thời gian xử lý theo severity.

---

## 7. Best Practices

### 7.1. Triage hàng ngày

Mỗi sáng nên:

1. Vào **All Reports** → filter `status = open` → sort `severity_desc`.
2. Xử lý **Critical** trước (4h SLA).
3. Sau đó đến **High** (8h SLA).
4. Cuối ngày, review các **Medium** cũ > 3 ngày.

### 7.2. Comment tốt

✅ Comment nên rõ ràng, có actionable info:

```
GOOD: "PR #141 merged, bump upload chunk size 5MB → 15MB.
       Build 1.2.4 (build 44) đã push lên TestFlight.
       Vui lòng test và báo lại nếu vẫn còn timeout."

BAD:  "Đã fix."
```

### 7.3. Không close report khi chưa xác nhận

- Status `resolved` = "đã fix, chờ user xác nhận".
- Status `closed` = "user xác nhận OK" hoặc "admin quyết định đóng".
- **Không** chuyển thẳng `open` → `closed` (trừ khi rất rõ ràng là duplicate / spam).

### 7.4. Liên lạc với user

- Nếu cần thêm thông tin, **KHÔNG gửi email riêng** — hãy thêm comment vào report.
- Comment sẽ xuất hiện trong lịch sử user xem được.
- User sẽ nhận email thông báo khi có comment mới (nếu status thay đổi).

### 7.5. Tránh duplicate

Trước khi assign, search để xem có report tương tự chưa:

```
Filter: search = "crash dashboard"
        status = open
```

Nếu tìm thấy report tương tự:

- Ghi rõ "Duplicate of #NH-123" trong comment.
- Đánh status `wont_fix` với lý do "Duplicate".
- Đóng report hiện tại.

---

## 8. Phân quyền

| Hành động | Admin | Teacher/Parent |
|---|---|---|
| Xem tất cả reports | ✅ | ❌ (chỉ xem của mình) |
| Tạo report | ✅ | ✅ |
| Đổi status | ✅ | ❌ |
| Assign teacher | ✅ | ❌ |
| Xóa report | ✅ (cẩn thận) | ❌ |
| Upload thêm ảnh vào report | ✅ | ✅ (chỉ report của mình) |

---

## 9. Xử lý sự cố (Troubleshooting)

### 9.1. Push notification không gửi được

1. Kiểm tra user có device token chưa (bảng `device_tokens`).
2. Nếu FCM trả lỗi `UnregisteredError` hoặc `SenderIdMismatchError` → token tự động bị xóa.
3. Nếu lỗi `InvalidArgumentError` với "registration token" → cũng tự xóa.
4. Các lỗi khác được log vào file `[bug-notify] Push thất bại cho token=...`.

### 9.2. Email không gửi được

1. Kiểm tra `SMTP_*` env vars.
2. Xem log `[bug-notify] Email thất bại: ...`.
3. Test bằng `POST /api/auth/test-email` (chỉ dev).

### 9.3. User báo "Tôi không nhận được thông báo"

1. Kiểm tra user có device token không.
2. Kiểm tra email user có trong bảng `users.email` không.
3. Nếu cả 2 đều không có → thông báo user vào app để bật notification + cập nhật profile.

### 9.4. Rate limit 429

User gửi quá 10 reports / giờ. Hãy nhắc user:
- Mô tả đầy đủ 1 report thay vì gửi nhiều report nhỏ.
- Đợi 1 giờ rồi gửi tiếp.

---

## 10. Tài liệu liên quan

- [API Documentation](./bug-report-api.md) — Chi tiết endpoints
- [User Guide](./bug-report-user-guide.md) — Hướng dẫn cho user cuối
- [Postman Collection](../postman/collections/🏫%20KinderLog%20API/🐛%20Bug%20Reports/) — Test API
- [User Story](../Document/Doc/user-report-story.md) — Spec gốc
