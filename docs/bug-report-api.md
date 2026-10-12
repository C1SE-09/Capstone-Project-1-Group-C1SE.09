# Bug Report API Documentation

> **Project:** KinderLog — Voice-driven daily reports for Vietnamese kindergartens
> **Version:** 1.0.0 (US-BUG-01 → US-BUG-07)
> **Base URL:** `http://localhost:8000` (dev) · `https://api.kinderlog.app` (prod)
> **OpenAPI docs:** `http://localhost:8000/docs` (Swagger UI) · `http://localhost:8000/openapi.json`

This document describes the REST API for the **User Reports a Bug** user story.
The API allows users (teacher/parent/admin) to submit bug reports from the mobile app,
and administrators to manage them through a dashboard.

For end-user instructions, see:
- [User Guide](./bug-report-user-guide.md) — how to send a bug report from the app
- [Admin Guide](./bug-report-admin-guide.md) — how to triage & resolve bug reports

---

## 1. Authentication

All endpoints (except health checks) require a **Bearer JWT token** in the
`Authorization` header. The token is obtained by logging in via:

```
POST /api/auth/login
Content-Type: application/json

{
  "username": "comai",
  "password": "123456"
}
```

**Response 200:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "role": "teacher",
  "user_id": "11111111-0000-0000-0000-000000000001",
  "teacher_id": "bbbbbbbb-0000-0000-0000-000000000001",
  "parent_id": null
}
```

The token expires in 60 minutes (see `ACCESS_TOKEN_EXPIRE_MINUTES` in `app/core/security.py`).

### Test accounts (after running `backend/seed.sql`)

| Role | Username | Password | Notes |
|---|---|---|---|
| `admin` | `admin` | `123456` | user_id=`99999999-...-001` |
| `teacher` | `comai` | `123456` | user_id=`11111111-...-001`, teacher_id=`bbbbbbbb-...-001` |
| `teacher` | `colan` | `123456` | user_id=`11111111-...-002`, teacher_id=`bbbbbbbb-...-002` |
| `parent` | `tuan` | `123456` | user_id=`22222222-...-001`, parent_id=`cccccccc-...-001` |
| `parent` | `nam`, `hung`, ... | `123456` | 10 parents total |

---

## 2. Endpoints Overview

| # | Method | Endpoint | Role | Description |
|---|--------|----------|------|-------------|
| 1 | `POST` | `/api/bug-reports` | teacher / parent / admin | Create new bug report (multipart, with optional attachments) |
| 2 | `GET` | `/api/bug-reports/me` | teacher / parent / admin | List MY bug reports (paginated) |
| 3 | `GET` | `/api/bug-reports/me/{report_id}` | teacher / parent / admin | Get MY bug report detail (with attachments + history) |
| 4 | `GET` | `/api/bug-reports` | admin | List ALL bug reports (filter + paginate) |
| 5 | `GET` | `/api/bug-reports/{report_id}` | admin | Get any bug report detail |
| 6 | `PATCH` | `/api/bug-reports/{report_id}` | admin | Update status / assignee / add comment |
| 7 | `POST` | `/api/bug-reports/{report_id}/attachments` | author / admin | Upload more attachments to existing report |

### 2.1. Rate limit

- **POST /api/bug-reports** is rate-limited to **10 requests / user / hour**.
- Excess requests receive `429 Too Many Requests` with the message:
  *"Bạn đã gửi quá nhiều báo cáo. Vui lòng thử lại sau."*

### 2.2. Validation summary

| Field | Required | Type | Constraints |
|---|---|---|---|
| `title` | yes | string | 1–200 chars |
| `description` | yes | string | 1–4000 chars |
| `category` | no | enum | `ui` `performance` `crash` `data` `notification` `network` `auth` `other` (default `other`) |
| `severity` | no | enum | `low` `medium` `high` `critical` (default `medium`) |
| `attachments` | no | file[] | max 5 files, each ≤ 5MB, MIME `image/*` or `text/plain` |
| `app_version` | no | string | e.g. "1.2.3" |
| `build_number` | no | string | e.g. "42" |
| `os_version` | no | string | e.g. "Android 14" |
| `device_model` | no | string | e.g. "Samsung SM-A546B" |
| `network_type` | no | string | `wifi` `cellular` `offline` |

---

## 3. Endpoint Details

### 3.1. `POST /api/bug-reports` — Create a new bug report

**Auth:** Bearer (teacher / parent / admin)
**Content-Type:** `multipart/form-data`
**Rate limit:** 10/hour/user

**Request body** (form fields):
```
title:           string (required, 1-200 chars)
description:     string (required, 1-4000 chars)
category:        string (optional, default "other")
severity:        string (optional, default "medium")
app_version:     string (optional)
build_number:    string (optional)
os_version:      string (optional)
device_model:    string (optional)
network_type:    string (optional)
attachments:     file[] (optional, max 5 files, each ≤ 5MB, image/* or text/plain)
```

**Response 201:**
```json
{
  "bug_report_id": "c09315d1-1234-5678-9abc-def012345678",
  "user_id": "11111111-0000-0000-0000-000000000001",
  "title": "App crash khi mở báo cáo của bé An",
  "description": "Bước tái hiện: ...",
  "category": "crash",
  "severity": "high",
  "status": "open",
  "app_version": "1.2.3",
  "build_number": "42",
  "os_version": "Android 14",
  "device_model": "Samsung SM-A546B",
  "network_type": "wifi",
  "resolved_at": null,
  "closed_at": null,
  "attachments": [
    {
      "attachment_id": "...",
      "file_url": "http://minio:9000/bug-reports/abc.png",
      "file_name": "screenshot.png",
      "file_size": 102400,
      "mime_type": "image/png"
    }
  ],
  "created_at": "2026-10-12T10:00:00Z",
  "updated_at": "2026-10-12T10:00:00Z"
}
```

**Side effects:**
- 1 entry auto-inserted into `bug_report_history` (status: NULL → open).
- Celery task `notify_admin_new_bug_report` dispatched — sends push notification + email
  to all admin users. Failure to dispatch does NOT block the API response.

**Error responses:**

| Status | When | Body |
|---|---|---|
| `400` | Validation error (e.g. 6 attachments, file > 5MB, wrong MIME) | `{ "detail": "..." }` |
| `401` | No / invalid JWT | `{ "detail": "Không thể xác thực thông tin đăng nhập" }` |
| `403` | User role not in {teacher, parent, admin} | `{ "detail": "Endpoint này chỉ dành cho: [...]" }` |
| `422` | Pydantic validation (e.g. empty title, too long description) | `{ "detail": [{ "loc": [...], "msg": "..." }] }` |
| `429` | Rate limit exceeded (>10 reports in 1 hour) | `{ "detail": "Bạn đã gửi N/10 báo cáo..." }` |

---

### 3.2. `GET /api/bug-reports/me` — List MY bug reports

**Auth:** Bearer (teacher / parent / admin)

**Query parameters:**
```
page         int (default 1, min 1)
page_size    int (default 20, max 100)
```

**Response 200:**
```json
{
  "items": [
    {
      "bug_report_id": "...",
      "title": "...",
      "category": "crash",
      "severity": "high",
      "status": "open",
      "created_at": "...",
      "updated_at": "...",
      "attachment_count": 1
    }
  ],
  "total": 3,
  "page": 1,
  "page_size": 20
}
```

Items are ordered by `created_at DESC` (newest first).

---

### 3.3. `GET /api/bug-reports/me/{report_id}` — Get MY bug report detail

**Auth:** Bearer (teacher / parent / admin)

**Path parameters:**
- `report_id` (UUID) — must be a report **owned by the current user**.

**Response 200:**
Same structure as `GET /api/bug-reports/{report_id}` (see 3.5), but the report must be
owned by the requester, otherwise `403 Forbidden`.

**Error responses:**
- `403` — User is not the report's author.
- `404` — Report does not exist.

---

### 3.4. `GET /api/bug-reports` — [Admin] List ALL bug reports

**Auth:** Bearer + `role=admin`

**Query parameters (all optional):**
```
page             int         (default 1, min 1)
page_size        int         (default 20, max 100)
status           enum        open | in_progress | resolved | closed | wont_fix
severity         enum        low | medium | high | critical
category         enum        ui | performance | crash | data | notification | network | auth | other
user_role        enum        teacher | parent | admin
user_id          uuid        filter by reporter
teacher_id       uuid        filter by assignee
search           string      case-insensitive substring on title
date_from        datetime    ISO 8601 (e.g. 2026-10-01T00:00:00Z)
date_to          datetime    ISO 8601
order_by         enum        created_at_desc (default) | created_at_asc | severity_desc
```

**Response 200:**
Same shape as `/me`, but `items` contains reports from ALL users.

**Ordering:**
- `created_at_desc` (default) — newest first
- `created_at_asc` — oldest first
- `severity_desc` — critical → high → medium → low, then `created_at DESC`

**Example:**
```
GET /api/bug-reports?status=open&severity=high&order_by=severity_desc&page=1&page_size=20
```

---

### 3.5. `GET /api/bug-reports/{report_id}` — [Admin] Get any bug report detail

**Auth:** Bearer + `role=admin`

**Response 200:**
```json
{
  "bug_report_id": "...",
  "user_id": "...",
  "user": {
    "user_id": "...",
    "username": "comai",
    "role": "teacher",
    "full_name": "Cô Nguyễn Thị Mai",
    "email": "..."
  },
  "teacher_id": "...",
  "teacher": {
    "teacher_id": "...",
    "full_name": "Cô Mai"
  },
  "title": "...",
  "description": "...",
  "category": "crash",
  "severity": "high",
  "status": "in_progress",
  "app_version": "1.2.3",
  "build_number": "42",
  "os_version": "Android 14",
  "device_model": "Samsung SM-A546B",
  "network_type": "wifi",
  "resolved_at": null,
  "closed_at": null,
  "attachments": [
    {
      "attachment_id": "...",
      "file_url": "...",
      "file_name": "...",
      "file_size": 102400,
      "mime_type": "image/png"
    }
  ],
  "history": [
    {
      "history_id": "...",
      "old_status": null,
      "new_status": "open",
      "old_teacher_id": null,
      "new_teacher_id": null,
      "comment": "Report created by teacher",
      "changed_by": {
        "user_id": "11111111-...",
        "username": "comai",
        "role": "teacher"
      },
      "created_at": "2026-10-12T10:00:00Z"
    },
    {
      "history_id": "...",
      "old_status": "open",
      "new_status": "in_progress",
      "old_teacher_id": null,
      "new_teacher_id": "bbbbbbbb-...",
      "comment": "Đang fix responsive layout...",
      "changed_by": { ... admin ... },
      "created_at": "2026-10-12T11:00:00Z"
    }
  ],
  "created_at": "2026-10-12T10:00:00Z",
  "updated_at": "2026-10-12T11:00:00Z"
}
```

The `history` array provides a complete audit trail of all status / assignment changes.
The first entry has `old_status: null` (initial report creation).

---

### 3.6. `PATCH /api/bug-reports/{report_id}` — [Admin] Update status

**Auth:** Bearer + `role=admin`
**Content-Type:** `application/json`

**Request body:**
```json
{
  "status": "in_progress",
  "teacher_id": "bbbbbbbb-0000-0000-0000-000000000001",
  "comment": "Đang fix responsive layout cho mobile nhỏ."
}
```

All fields are optional, but **at least one** of `status` or `teacher_id` must differ
from the current value (no-op request returns 200 with no changes recorded).

**Response 200:**
Same shape as `GET /api/bug-reports/{report_id}` (with updated `status`, `resolved_at`,
`closed_at`, and a new `history` entry).

**Status transition effects:**
- `resolved` → sets `resolved_at = NOW()` (if not already set)
- `closed` → sets `closed_at = NOW()` (if not already set)

**Side effects:**
- A new entry is inserted into `bug_report_history` with the change details.
- Celery task `notify_user_status_changed` is dispatched — sends push notification (FCM)
  + email to the report's author. Failure to dispatch does NOT block the API response.

**Allowed status transitions:** any → any (the API does not enforce a strict state
machine). The admin is expected to use sensible transitions.

**Error responses:**

| Status | When | Body |
|---|---|---|
| `400` | Invalid status value (e.g. "garbage") that bypassed Pydantic but failed in service | `{ "detail": "Status '...' không hợp lệ. Cho phép: [...]" }` |
| `404` | Report does not exist | `{ "detail": "Bug report not found" }` |
| `422` | Pydantic validation | (validation error) |

---

### 3.7. `POST /api/bug-reports/{report_id}/attachments` — Add attachments

**Auth:** Bearer (admin OR author of the report)
**Content-Type:** `multipart/form-data`

**Request body:**
```
attachments:    file[] (required, 1-5 files, each ≤ 5MB, image/* or text/plain)
```

Total attachments per report is limited to 5 (existing + new). Adding more returns `400`.

**Response 200:**
```json
{
  "bug_report_id": "...",
  "new_attachments": [
    {
      "attachment_id": "...",
      "file_url": "...",
      "file_name": "extra.png",
      "file_size": 50000,
      "mime_type": "image/png"
    }
  ],
  "total_attachments": 3
}
```

**Error responses:**
- `400` — 0 files, file > 5MB, wrong MIME, would exceed 5 total
- `403` — User is not admin and not the report's author
- `404` — Report does not exist

---

## 4. Status State Machine

```
       ┌──────────┐
       │   open   │ ◀─────── initial state
       └────┬─────┘
            │
            ▼
   ┌────────────────┐
   │  in_progress   │
   └────────┬───────┘
            │
      ┌─────┴──────┐
      ▼            ▼
 ┌──────────┐  ┌──────────┐
 │ resolved │  │ wont_fix │  (terminal)
 └────┬─────┘  └──────────┘
      │
      ▼
 ┌──────────┐
 │  closed  │  (terminal)
 └──────────┘
```

The API does not enforce strict transitions — admins can move to any state.
But the recommended flow is: `open` → `in_progress` → `resolved` → `closed`.

`wont_fix` is appropriate for: duplicate reports, outside-scope issues, feature requests
mistakenly filed as bugs.

---

## 5. Enums

### 5.1. `BugCategory` (`category` field)

| Value | Vietnamese | Use case |
|---|---|---|
| `ui` | Giao diện | Visual glitches, layout issues |
| `performance` | Hiệu năng | Slow / lag |
| `crash` | Crash | App force-close, freeze |
| `data` | Dữ liệu | Wrong / missing data |
| `notification` | Thông báo | Push / email not received |
| `network` | Mạng | Connection issues |
| `auth` | Xác thực | Login / session problems |
| `other` | Khác | Anything else (default) |

### 5.2. `BugSeverity` (`severity` field)

| Value | Vietnamese | SLA |
|---|---|---|
| `low` | Thấp | 2 weeks |
| `medium` | Trung bình | 1 week (default) |
| `high` | Cao | 3 days |
| `critical` | Nghiêm trọng | 24h (app unusable) |

### 5.3. `BugStatus` (`status` field)

| Value | Vietnamese | Description |
|---|---|---|
| `open` | Mới | Newly submitted, not yet reviewed |
| `in_progress` | Đang xử lý | Admin is working on it |
| `resolved` | Đã xử lý | Fix deployed, waiting user confirmation |
| `closed` | Đã đóng | User confirmed or admin closed |
| `wont_fix` | Không sửa | Duplicate / outside scope / feature request |

---

## 6. Configuration (env vars)

| Variable | Default | Description |
|---|---|---|
| `BUG_REPORT_NOTIFY_EMAIL` | `""` | Comma-separated list of admin emails. If empty → auto-detect all admin users. |
| `MAX_ATTACHMENT_SIZE_MB` | `5` | Max file size per attachment. |
| `MAX_ATTACHMENTS_PER_REPORT` | `5` | Max number of attachments per report. |
| `RATE_LIMIT_REPORTS_PER_HOUR` | `10` | Max reports per user per hour. |

---

## 7. Notifications

When a report is created or its status changes, the backend dispatches **Celery tasks**
to send notifications. These tasks run asynchronously and do NOT block the API response.

| Event | Task | Recipients | Channels |
|---|---|---|---|
| Report created | `notify_admin_new_bug_report` | All admin users (filtered by `BUG_REPORT_NOTIFY_EMAIL` or auto-detected) | Push (FCM) + Email |
| Status changed | `notify_user_status_changed` | The report's author (if has device token or email) | Push (FCM) + Email |

If the Celery broker (Redis) is unavailable, the API still returns success — but
notifications will be silently dropped. The error is logged for debugging.

---

## 8. Postman Collection

A ready-to-use Postman collection is available at
`postman/collections/🏫 KinderLog API/🐛 Bug Reports/`.

The collection includes:
- **3 Login requests** (admin / teacher / parent) — auto-save tokens to variables
- **2 Create requests** (with / without attachment)
- **2 List MY requests**
- **2 Admin List requests** (with / without filters)
- **2 Detail requests** (user / admin)
- **4 PATCH requests** (open→in_progress, in_progress→resolved, resolved→closed, →wont_fix)
- **1 Add attachments request**

**Total: 15 requests in 3 folders.**

Import the collection into Postman (or Postman v10+ with the local file system watcher)
and run requests in order. Tokens are auto-managed via test scripts.

---

## 9. Testing

Run all bug-report tests:

```bash
cd backend
pytest tests/test_bug_reports.py tests/test_bug_report_notifications.py -v
```

**Test count:** 72 (61 in `test_bug_reports.py` + 11 in `test_bug_report_notifications.py`)
**Coverage:** 91% (target: 80%)

---

## 10. Database Schema

See `Document/Doc/user-report-story.md` section 6 for the complete ER diagram.

3 tables:
- `bug_report` — main table
- `bug_report_attachment` — 1:N from bug_report
- `bug_report_history` — 1:N from bug_report (audit trail)
