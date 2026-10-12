# User Story: User Reports a Bug

> **Project:** KinderLog — Voice-driven daily reports for Vietnamese kindergartens
> **Stack:** Flutter (Android) · FastAPI · PostgreSQL · Redis · Celery
> **Branch:** `feature/user-report-bug`
> **Owner:** TBD
> **Status:** Draft
> **Last updated:** 2026-10-12

---

## 1. Mục tiêu (Goal)

Cho phép **người dùng cuối** (giáo viên, phụ huynh) gửi báo cáo lỗi (bug report) từ trong ứng dụng Flutter lên hệ thống, kèm theo mô tả, mức độ nghiêm trọng, ảnh chụp màn hình và thông tin môi trường. Bộ phận quản trị (admin) nhận được thông báo và có thể theo dõi, xử lý các báo cáo này trong một bảng điều khiển nội bộ.

## 2. User Story chính (Main user stories)

| ID | As a... | I want to... | So that... | Priority |
|----|---------|--------------|------------|----------|
| US-BUG-01 | Teacher/Parent | Gửi bug report từ màn hình cài đặt/trợ giúp trong app, kèm tiêu đề, mô tả, mức độ nghiêm trọng, ảnh chụp màn hình | Đội ngũ phát triển nhận được phản hồi và xử lý lỗi kịp thời | Must |
| US-BUG-02 | Teacher/Parent | Xem lại lịch sử các bug report của tôi và trạng thái xử lý | Tôi biết được báo cáo của mình đang ở trạng thái nào | Must |
| US-BUG-03 | Admin | Nhận danh sách tất cả bug report với bộ lọc (trạng thái, mức độ, loại người dùng) | Quản lý và ưu tiên xử lý lỗi | Must |
| US-BUG-04 | Admin | Cập nhật trạng thái bug report (`open` → `in_progress` → `resolved` / `closed` / `wont_fix`) và thêm ghi chú nội bộ | Theo dõi tiến độ xử lý và phản hồi cho người dùng | Must |
| US-BUG-05 | Teacher/Parent | Nhận thông báo (in-app + email) khi trạng thái bug report của tôi thay đổi | Tôi biết được lỗi đã được xử lý | Should |
| US-BUG-06 | System | Tự động thu thập thông tin môi trường (app version, OS version, device model, network type, user id, timestamp) kèm theo bug report | Hỗ trợ debug nhanh hơn | Should |
| US-BUG-07 | Admin | Thống kê số lượng bug report theo trạng thái / mức độ / thời gian | Có cái nhìn tổng quan để cải tiến chất lượng | Could |

---

## 3. Acceptance Criteria (Tiêu chí chấp nhận)

### 3.1. Tạo bug report
- [ ] Người dùng đã đăng nhập có thể truy cập form "Báo cáo lỗi" từ **Settings / Help & Support**.
- [ ] Form bắt buộc: **Tiêu đề** (≤ 200 ký tự), **Mô tả chi tiết** (≤ 4000 ký tự), **Mức độ nghiêm trọng** (Low / Medium / High / Critical).
- [ ] Form tùy chọn: **Loại lỗi** (UI / Performance / Crash / Data / Notification / Khác), **ảnh chụp màn hình** (tối đa 5 ảnh, ≤ 5 MB / ảnh).
- [ ] Tự động đính kèm metadata: `app_version`, `build_number`, `os_version`, `device_model`, `network_type`, `user_id`, `user_role`, `created_at`.
- [ ] Sau khi gửi thành công: hiển thị toast/snackbar "Gửi báo cáo thành công" và quay về màn hình trước.
- [ ] Nếu mất mạng: lưu report vào **outbox cục bộ** và tự động retry khi có mạng.
- [ ] Validation: nếu tiêu đề/mô tả rỗng → hiển thị lỗi inline; không gửi request lên server.

### 3.2. Lịch sử bug report (của tôi)
- [ ] Hiển thị danh sách các bug report do user hiện tại gửi, phân trang 20 item/trang.
- [ ] Mỗi dòng hiển thị: tiêu đề, mức độ, trạng thái, ngày tạo.
- [ ] Bấm vào một report → mở chi tiết với mô tả đầy đủ, ảnh đính kèm, lịch sử trạng thái, phản hồi của admin (nếu có).

### 3.3. Quản lý bug report (Admin)
- [ ] Màn hình admin: bảng danh sách với filter theo **trạng thái**, **mức độ**, **role**, **khoảng thời gian**.
- [ ] Bấm vào report → cửa sổ chi tiết cho phép: đổi trạng thái, thêm ghi chú nội bộ, xem ảnh, xem metadata.
- [ ] Mọi thay đổi trạng thái ghi log vào bảng `bug_report_history` (audit trail).

### 3.4. Thông báo
- [ ] Khi user gửi report → gửi email thông báo cho admin group (`BUG_REPORT_NOTIFY_EMAIL`).
- [ ] Khi admin đổi trạng thái → gửi push notification (Firebase) cho user đã gửi report (nếu user có device token) + email.
- [ ] Khi admin thêm ghi chú public → user nhận được thông báo.

### 3.5. Bảo mật & Quyền
- [ ] Endpoint tạo report yêu cầu JWT hợp lệ, role = `teacher` / `parent` / `admin`.
- [ ] Endpoint list / update report yêu cầu role = `admin`.
- [ ] User chỉ xem được các report do chính mình tạo (trừ admin).
- [ ] Rate limit: tối đa **10 report / user / giờ** để tránh spam.

---

## 4. Phân tích kỹ thuật & Tasks chi tiết

### 4.1. Backend (FastAPI + PostgreSQL)

| # | Task | File / Vị trí | Mô tả chi tiết | Estimate |
|---|------|---------------|----------------|----------|
| **B-01** | **Database: models + migration** | `backend/app/models/bug_report.py` · `backend/alembic/versions/...` | Định nghĩa 3 model SQLAlchemy 2.0 (`BugReport`, `BugReportAttachment`, `BugReportHistory`) + 3 enum (`BugCategory`, `BugSeverity`, `BugStatus`). Tạo Alembic migration tạo bảng + indexes. Chạy `alembic upgrade head` thành công. | 4h |
| **B-02** | **Schemas + service layer** | `backend/app/schemas/bug_report.py` · `backend/app/services/bug_report_service.py` | Pydantic schemas (`BugReportCreate/Update/Out/Detail/ListResponse`). Service xử lý business logic: `create_report`, `list_reports` (filter + pagination), `get_report`, `update_status` (ghi history), `get_user_reports`. Validate permission, rate-limit. Upload file (MIME image/*, ≤ 5MB) lên S3-compatible storage có sẵn. | 6h |
| **B-03** | **API endpoints + security** | `backend/app/api/endpoints/bug_reports.py` · `backend/app/main.py` | 7 endpoint: `POST/GET /api/bug-reports`, `GET /api/bug-reports/me`, `GET/PATCH /api/bug-reports/{id}`, `POST /api/bug-reports/{id}/attachments`. Dùng `require_role()` cho phân quyền (admin cho list/update; teacher/parent/admin cho create/me). SlowAPI rate-limit 10/min. Register router trong `main.py`. Thêm env (`BUG_REPORT_NOTIFY_EMAIL`, `MAX_ATTACHMENT_SIZE_MB`). | 5h |
| **B-04** | **Notification integration** | `backend/app/services/notification_service.py` · `backend/app/tasks/notifications.py` | Tận dụng service hiện có: gửi email cho admin khi có report mới; gửi push (FCM) + email cho user khi admin đổi status. Background task Celery để không block API. | 3h |
| **B-05** | **Testing + API docs** | `backend/tests/test_bug_reports.py` · `http://localhost:8000/docs` | Pytest cho create/list (admin/user)/update status/permission/rate limit/attachment upload/history audit. FastAPI tự sinh OpenAPI; verify đầy đủ tại `/docs`. | 4h |

### 4.2. Frontend (Flutter / Android)

| # | Task | File / Vị trí | Mô tả chi tiết | Estimate |
|---|------|---------------|----------------|----------|
| **F-01** | **Domain + data layer** | `frontend/lib/domain/entities/bug_report/` · `frontend/lib/data/repositories/http_bug_report_repository.dart` · `frontend/lib/core/utils/device_info_helper.dart` | Entity Freezed (`BugReport`, `BugCategory`, `BugSeverity`, `BugStatus`, `BugReportAttachment`, `BugReportHistory`). Repo interface + HTTP impl (multipart upload). Helper lấy metadata (`package_info_plus`, `device_info_plus`, `connectivity_plus`). | 5h |
| **F-02** | **State management + offline outbox** | `frontend/lib/features/bug_report/bloc/` · `frontend/lib/data/local/bug_report_outbox.dart` | Bloc/Cubit cho form, list, detail. Events: `SubmitReport`, `LoadMyReports`, `LoadReportDetail`, `UpdateStatus`. Outbox lưu report chưa gửi được vào local storage (Hive/sqflite), auto-retry khi có mạng. | 6h |
| **F-03** | **User-facing UI** (form / list / detail) | `frontend/lib/features/bug_report/screens/` · `frontend/lib/features/bug_report/widgets/attachment_picker.dart` | 3 màn hình: form (text + dropdown + image picker), my-reports list (pagination + filter + pull-to-refresh), detail (ảnh zoom + lịch sử status). Widget image picker (tối đa 5 ảnh, gallery/camera, preview). | 8h |
| **F-04** | **Admin UI** (list / detail / shell) | `frontend/lib/features/bug_report/admin/` · `frontend/lib/features/admin/` | Admin shell (nếu chưa có). Bảng danh sách với filter (status/severity/role/date range) + search. Chi tiết: đổi status, note public/private, xem ảnh + metadata. | 8h |
| **F-05** | **Navigation + entry point + deps + l10n** | `frontend/lib/core/routing/app_router.dart` · `frontend/lib/features/kindergarten_dashboard/screens/` · `frontend/pubspec.yaml` · `frontend/lib/l10n/` | Thêm 5 route (`/bug-report/new`, `/my`, `/:id`, `/admin/bug-reports`, `/:id`). Thêm mục "Báo cáo lỗi" + "Lịch sử" trong Settings. Thêm pub dependencies (`image_picker`, `photo_view`, `connectivity_plus`, `package_info_plus`, `device_info_plus`, `path_provider`, `hive`). Thêm string keys VI+EN. | 4h |
| **F-06** | **Testing** (widget + e2e) | `frontend/test/bug_report/...` | Widget tests: form validation, list rendering, bloc events. Integration test e2e: login → submit → check my list → admin update → user nhận notification. | 5h |

### 4.3. DevOps & tài liệu

| # | Task | File / Vị trí | Mô tả | Estimate |
|---|------|---------------|-------|----------|
| **D-01** | **Seed + Postman** | `backend/seed.sql` · `postman/bug_reports.postman_collection.json` | Seed 3-5 bug report mẫu (các status khác nhau) cho môi trường dev. Postman collection cho tất cả endpoints. | 1.5h |
| **D-02** | **Documentation** (API + user + admin) | `docs/bug-report-api.md` · `docs/bug-report-user-guide.md` · `docs/bug-report-admin-guide.md` · `README.md` | API docs (endpoint + request/response + error codes). User guide (cách gửi report từ app). Admin guide (cách xử lý report từ dashboard). Update README mục "Bug reporting". | 4h |
| **D-03** | **CI workflow** | `.github/workflows/...` | Thêm job chạy `pytest` cho test_bug_reports + Flutter test. | 0.5h |

---

## 5. API Endpoints (Tóm tắt)

| Method | Endpoint | Role | Mô tả |
|--------|----------|------|-------|
| `POST` | `/api/bug-reports` | teacher / parent / admin | Tạo bug report mới (multipart/form-data, có thể kèm attachments) |
| `GET` | `/api/bug-reports/me` | teacher / parent / admin | Danh sách report của user hiện tại (phân trang) |
| `GET` | `/api/bug-reports/me/{id}` | teacher / parent / admin | Chi tiết 1 report của tôi |
| `GET` | `/api/bug-reports` | admin | Danh sách tất cả report, có filter & phân trang |
| `GET` | `/api/bug-reports/{id}` | admin | Chi tiết 1 report |
| `PATCH` | `/api/bug-reports/{id}` | admin | Cập nhật status + admin note |
| `POST` | `/api/bug-reports/{id}/attachments` | author / admin | Upload thêm ảnh vào report đã tồn tại |

### Request/Response mẫu

**POST /api/bug-reports** (multipart):
```
title: App bị crash khi mở report
description: Khi em bấm vào report của bé An, app thoát ra ngay.
category: crash
severity: high
attachment_0: <file 1>
attachment_1: <file 2>
```

**Response 201:**
```json
{
  "bug_report_id": "uuid",
  "user_id": "uuid",
  "title": "App bị crash khi mở report",
  "description": "Khi em bấm vào report của bé An, app thoát ra ngay.",
  "category": "crash",
  "severity": "high",
  "status": "open",
  "app_version": "1.2.3",
  "build_number": "45",
  "os_version": "Android 14",
  "device_model": "Samsung SM-A546B",
  "network_type": "wifi",
  "attachments": [
    { "attachment_id": "uuid", "file_url": "https://...", "file_name": "screenshot.png" }
  ],
  "created_at": "2026-10-12T10:00:00Z",
  "updated_at": "2026-10-12T10:00:00Z"
}
```

---

## 6. Database Schema (Rút gọn)

```
┌──────────────────────────┐
│        bug_report        │
├──────────────────────────┤
│ bug_report_id  UUID PK   │
│ user_id        UUID FK   │──→ users.user_id
│ title          VARCHAR   │
│ description    TEXT      │
│ category       ENUM      │
│ severity       ENUM      │
│ status         ENUM      │
│ app_version    VARCHAR   │
│ build_number   VARCHAR   │
│ os_version     VARCHAR   │
│ device_model   VARCHAR   │
│ network_type   VARCHAR   │
│ created_at     TIMESTAMP │
│ updated_at     TIMESTAMP │
└──────────┬───────────────┘
           │
           │ 1:N
           ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│  bug_report_attachment   │    │   bug_report_history     │
├──────────────────────────┤    ├──────────────────────────┤
│ attachment_id  UUID PK   │    │ history_id      UUID PK  │
│ bug_report_id  UUID FK   │    │ bug_report_id   UUID FK  │
│ file_url       VARCHAR   │    │ changed_by      UUID FK  │
│ file_name      VARCHAR   │    │ old_status      ENUM     │
│ file_size      INT       │    │ new_status      ENUM     │
│ mime_type      VARCHAR   │    │ note            TEXT     │
│ uploaded_at    TIMESTAMP │    │ created_at      TIMESTAMP│
└──────────────────────────┘    └──────────────────────────┘
```

---

## 7. Definition of Done (DoD)

- [ ] Tất cả tasks trong section 4 đã hoàn thành và merged vào `develop`.
- [ ] Tất cả test pass: `pytest backend/tests/test_bug_reports.py` + `flutter test`.
- [ ] Code coverage backend ≥ 80% cho module bug_report.
- [ ] Đã test trên thiết bị Android thật (gửi report, upload ảnh, nhận push notification).
- [ ] Tài liệu `docs/bug-report-api.md`, `docs/bug-report-user-guide.md`, `docs/bug-report-admin-guide.md` đã cập nhật.
- [ ] Postman collection import được và chạy thành công.
- [ ] Migration chạy thành công trên cả DB local và môi trường staging.
- [ ] Đã demo cho PO/giáo viên/ phụ huynh thử nghiệm thực tế.
- [ ] Không có linter error (ruff, flutter analyze).
- [ ] PR đã được review bởi ít nhất 1 thành viên khác.

---

## 8. Out of Scope (Không làm trong story này)

- Tích hợp với hệ thống ticketing bên ngoài (Jira, GitHub Issues) — sẽ là story riêng.
- Chat trực tiếp giữa admin và user.
- Tự động attach log file từ app (chỉ screenshot).
- Báo cáo lỗi qua kênh khác (SMS, Zalo).
- Phân tích tự động root-cause từ log (AI-assisted debugging).

---

## 9. Rủi ro & Giảm thiểu

| Rủi ro | Tác động | Giảm thiểu |
|--------|----------|------------|
| User spam report | DB phình, admin quá tải | Rate limit 10/h, captcha nếu cần (post-MVP) |
| Upload ảnh nặng làm chậm API | UX kém | Resize ảnh ở client trước khi upload, giới hạn 5MB/ảnh |
| File đính kèm chứa thông tin nhạy cảm | Bảo mật | Cảnh báo user; admin có quyền xóa; URL ký có thời hạn |
| Admin không vào dashboard thường xuyên | Báo lỗi chậm xử lý | Email + push ngay khi có report mới; SLA 24h cho critical |
| Offline — user gửi report không có mạng | Mất report | Outbox cục bộ + auto retry khi online |
| Push notification chưa có device token | User không nhận được thông báo cập nhật | Fallback email |

---

## 10. Tổng estimate

| Nhóm | Tasks | Tổng giờ |
|------|-------|----------|
| Backend | B-01 → B-05 (5 task) | ~22h |
| Frontend | F-01 → F-06 (6 task) | ~36h |
| DevOps & Docs | D-01 → D-03 (3 task) | ~6h |
| **Tổng** | **14 task** | **~64h (~ 8 ngày làm việc cho 1 dev)** |

> Gợi ý chia 2 sprint:
> - **Sprint 1 (BE-first)**: B-01 → B-05 + F-01 → F-02 (data layer + outbox) → ~3 ngày
> - **Sprint 2 (UI + Admin + Docs)**: F-03 → F-06 + D-01 → D-03 → ~5 ngày

---

## 11. Reference (Tham khảo)

- FastAPI multipart upload: <https://fastapi.tiangolo.com/tutorial/request-files/>
- Flutter `image_picker`: <https://pub.dev/packages/image_picker>
- SQLAlchemy 2.0 Mapped style: pattern đang dùng trong `backend/app/models/report.py`
- Push notification service có sẵn: `frontend/lib/core/notifications/push_notification_service.dart`, `backend/app/services/notification_service.py`
- Outbox pattern: tham khảo `docs/push-notification-testing.md`
