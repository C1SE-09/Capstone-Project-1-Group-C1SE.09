# Kế hoạch: Auto-detect Single/Multi Recording Flow

> **Trạng thái:** 📝 Đang planning — chưa code
> **Owner:** Backend (a) + Frontend (em)
> **Branch:** `feature/auto-detect-recording-mode` (đã tạo sẵn)
> **Last updated:** 2026-09-30 (đã chốt 7 edge cases + flow duyệt từng item)

---

## 🎯 Mục tiêu

Thay vì user chọn "Cả lớp" / "1 bé" trước khi ghi âm → user **chỉ cần ghi âm 1 lần**, hệ thống **tự động nhận biết** transcript thuộc nhóm nào:

| Case | Mô tả | UI hiển thị |
|---|---|---|
| **1** | Transcript chỉ nhắc **1 bé** (có đọc tên) | 1 item → confirm → tạo 1 report |
| **2** | Transcript nhắc **vài bé** | N items (mỗi bé 1 item) |
| **3** | Transcript có **cả lớp + vài bé đặc biệt** | **1 item "Cả lớp"** + **N items đặc biệt** |
| **4** | Transcript có **đoạn ambiguous / unmatched** | Item "Chưa rõ bé nào" + nút **Gán** |

---

## 🔁 Flow tổng quan (đã chốt)

### 1. Ghi âm & Extract
- User bấm ghi âm → upload → backend STT + `extract_multi_person()`
- Backend trả về `child_extractions`, `class_wide_extraction`, `unmatched_segments`
- **KHÔNG tạo report nào** tại bước này

### 2. Review screen (hiển thị items)
- Mỗi item có 2 nút: **Duyệt** ✅ / **Loại bỏ** ❌
- Item có thể ở 1 trong 3 trạng thái:
  - 🟡 **Pending** (chưa làm gì) → hiển thị cả 2 nút
  - 🟢 **Approved** (đã duyệt) → **chỉ hiển thị trạng thái, KHÔNG có nút Loại bỏ**
  - 🔴 **Discarded** (đã loại bỏ) → chỉ hiển thị trạng thái, KHÔNG có nút Duyệt

### 3. Per-item Duyệt (tạo draft)
- Bấm **Duyệt** trên item → **gọi backend NGAY** để tạo draft DailyReport
- Approve không thể undo (1 lần duy nhất)
- Có thể duyệt các item theo bất kỳ thứ tự nào → override luôn thắng (xem logic bên dưới)

### 4. Global Xác nhận (gửi tất cả drafts)
- Sau khi review xong, bấm **Xác nhận gửi** ở top màn hình
- Backend gửi tất cả draft reports cho phụ huynh (qua `notification_service` đã có)
- Chuyển status: draft → sent

### Quy tắc cốt lõi
- ✅ Override luôn thắng dù duyệt trước/sau class-wide
- ✅ Duyệt rồi KHÔNG cho loại bỏ (one-way state)
- ✅ Mỗi bé chỉ có tối đa 1 draft report / ngày (unique constraint)
- ✅ "Cả lớp" = content default áp dụng cho từng DailyReport (không phải entity riêng)

---

## 🏗️ Kiến trúc đã chốt (KHÔNG dùng ClassBroadcastReport)

### Nguyên tắc cốt lõi

> **"Cả lớp" KHÔNG phải 1 entity riêng — chỉ là nội dung default áp dụng cho từng DailyReport**

- 1 voice record → **N DailyReports** (mỗi bé 1 cái, **luôn luôn individual**)
- Mỗi phụ huynh chỉ thấy **1 báo cáo riêng của con mình** — không có "báo cáo cả lớp" gửi đi
- "Cả lớp" = content mặc định (ăn, ngủ, mood...) được apply vào từng DailyReport
- Bé nào có override → ghi đè fields đó lên default của bé đó

### Công thức áp dụng cho mọi bé trong lớp

```
Nếu class-wide được duyệt:
    → TẤT CẢ bé trong lớp có report
    → Bé có override: dùng override content
    → Bé không có override: dùng class-wide default

Nếu class-wide KHÔNG được duyệt (bị bỏ):
    → Chỉ những bé có override được duyệt mới có report
    → Bé không có override: KHÔNG có report hôm nay
```

### Ví dụ minh hoạ

**Transcript:** *"Cả lớp ăn cơm ngon, ngủ đủ giấc. Riêng bé Lan ăn ít, quấy. Riêng bé Huy ho nhẹ."*

**UI hiển thị 3 items:**
1. **Cả lớp** — "ăn cơm ngon, ngủ đủ giấc"
2. **Bé Lan** — "ăn ít, quấy" (override)
3. **Bé Huy** — "ho nhẹ" (override)

**Cô giữ nguyên tất cả + bấm Xác nhận → Backend tạo 25 DailyReports:**

| Bé | Có report? | Nội dung |
|---|---|---|
| Lan | ✅ | `ăn="ăn ít"`, `ngủ="đủ giấc"`, `mood="quấy"` (override + class-wide ngủ) |
| Huy | ✅ | `ăn="cơm ngon"`, `ngủ="đủ giấc"`, `health="ho nhẹ"` (override + class-wide ăn/ngủ) |
| 23 bé khác | ✅ | `ăn="cơm ngon"`, `ngủ="đủ giấc"` (class-wide default) |

---

## 📊 Phân tích hiện trạng

### ✅ Backend đã có sẵn (KHÔNG cần đụng)

- `app/services/extraction_service.py::extract_multi_person()`
  - Đã trả `{segments, child_extractions, unmatched_segments, class_wide_segments}`
  - Đã có logic override: child-specific ghi đè class-wide default
- `app/services/name_matching_service.py`
  - Word-overlap scoring + nickname bonus + ambiguity detection
- `app/services/validation_service.py`
  - Keyword validation → raise `ValidationError` → frontend đã handle 400
- `app/services/stt_service.py` (PhoWhisper)
- `app/services/notification_service.py`
- `app/models/report.py`
  - `VoiceRecord`, `DailyReport`, `ActivityEntry`
  - `VoiceRecordScope { SINGLE_CHILD, WHOLE_CLASS }`
  - `DailyReportType { INDIVIDUAL, EXCEPTION }`
  - `ClassBroadcastReport` (model tồn tại nhưng **KHÔNG dùng** trong flow mới)
- `app/api/teacher.py`
  - `POST /api/teacher/voice/upload` (đã handle `child_id` optional)
  - `POST /api/teacher/voice/{id}/analyze` (đã detect single vs multi theo `child_id`)
  - `POST /api/teacher/reports/manual` (1 call / 1 child — sẽ thay bằng batch)
  - `POST /api/reports/{id}/send` (PR #128)
  - `POST /api/teacher/reports/send-all` (loop)

### ⚠️ Khoảng trống cần fill

#### A. Backend chưa có endpoint "confirm batch"

Hiện tại:
- `POST /api/teacher/reports/manual` — tạo 1 report / 1 child (cũ)
- `POST /api/teacher/reports/{id}/publish` — publish 1 report (deprecated)
- `POST /api/reports/{id}/send` — send 1 report (PR #128)
- `POST /api/teacher/reports/send-all` — send nhiều (loop)

**Thiếu:** endpoint **tạo + publish batch** từ 1 voice recording:
- Input: danh sách items (classwide + override + assigned)
- Output: tạo N DailyReports (1/child trong class) theo công thức trên

#### B. Frontend đang có 2 nhánh explicit

```dart
// record_screens.dart:34
enum RecordMode { classroom, child }
```

`RecordHubScreen` có 2 button:
- "Cả [Tên lớp]" → `RecordFlowScreen(mode: classroom)`
- Tap 1 bé → `RecordFlowScreen(mode: child, child: ...)`

→ Cần **bỏ enum** này, chỉ 1 flow duy nhất.

#### C. `_buildObservations()` chưa đúng logic Case 3

Hiện tại (`record_screens.dart:1020`):
- Với `mode == classroom` → loop **tất cả children trong class**, mỗi bé 1 item
- Với `childMap` match theo `child.id` hoặc `child.name` → set extraction fields

**Vấn đề:** Case 3 muốn chỉ hiện **1 item "Cả lớp" + N items đặc biệt**, KHÔNG hiện 25 items cho 25 bé không được nhắc.

→ Cần rewrite dựa trên `child_extractions` keys + `class_wide_segments`.

#### D. `_confirmAndPublish()` đang loop + auto-publish

```dart
// record_screens.dart:1180
for (final item in approvedItems) {
  final res = await teacherRepository.createManualReport(...);  // 1 call / child
  await teacherRepository.publishReport(...);                    // 1 call / child
}
```

→ Cần đổi sang **1 batch call** mới, gửi list items (kèm kind để backend biết class-wide vs override).

---

## 🎯 Edge cases đã chốt (7/7)

> ✅ Tất cả đã được giải thích kèm ví dụ cụ thể

---

### ✅ Edge case 1 — Transcript chỉ có class-wide

**Tình huống:** Cô ghi âm:
> *"Hôm nay cả lớp ăn cơm ngon, ngủ trưa đủ giấc, vui chơi ngoài trời."*

Lớp 25 bé, không nhắc tên ai.

**Cô duyệt item "Cả lớp" + Xác nhận gửi → Backend tạo 25 DailyReports:**
- Tất cả 25 cái có cùng content class-wide: `ăn uống="cơm ngon"`, `ngủ="đủ giấc"`, `activities="vui chơi ngoài trời"`
- 25 phụ huynh nhận 25 báo cáo (giống nhau vì không có override)

✅ **Chốt: 25 DailyReports** — luôn luôn individual, mỗi phụ huynh thấy 1 báo cáo riêng

---

### ✅ Edge case 2 — 1 child nhắc + class-wide

**Tình huống:** Cô ghi âm:
> *"Hôm nay cả lớp ăn cơm ngon, ngủ trưa đủ giấc. Riêng bé Lan hôm nay ăn ít hơn, hơi quấy."*

UI hiển thị 2 items:
1. **Cả lớp** — "ăn cơm ngon, ngủ đủ giấc"
2. **Bé Lan** — "ăn ít, quấy" (override)

**Sau khi cô duyệt cả 2 items + Xác nhận gửi → Backend tạo 25 DailyReports:**

| Bé | Có report? | Nội dung |
|---|---|---|
| Lan | ✅ | `ăn uống="ăn ít"`, `ngủ="đủ giấc"`, `mood="quấy"` (override + class-wide ngủ) |
| 24 bé kia | ✅ | `ăn uống="cơm ngon"`, `ngủ="đủ giấc"` (class-wide default) |

✅ **Chốt: 25 DailyReports** — 24 dùng default + 1 với override (không ai bị bỏ rơi)

---

### ✅ Edge case 3 — Tất cả special bị discard

**Tình huống:** Cô ghi âm nhắc cả class-wide + Lan + Huy. Cô bấm **"Loại bỏ"** Lan & Huy trên UI. Chỉ giữ class-wide.

**Sau khi duyệt class-wide + Xác nhận gửi → Backend tạo 25 DailyReports:**

| Bé | Có report? | Nội dung |
|---|---|---|
| 25 bé | ✅ | `ăn uống="cơm ngon"`, `ngủ="đủ giấc"` (chỉ class-wide, không override) |

✅ **Chốt: 25 DailyReports** — tất cả dùng class-wide default, tôn trọng "Loại bỏ"

---

### ✅ Edge case 4 — Class-wide bị discard + vài special

**Tình huống:** Cô bỏ class-wide. Giữ Lan, Huy.

**Sau khi duyệt 2 items Lan + Huy + Xác nhận gửi → Backend tạo 2 DailyReports:**

| Bé | Có report? | Nội dung |
|---|---|---|
| Lan | ✅ | Override của Lan |
| Huy | ✅ | Override của Huy |
| 23 bé kia | ❌ | — (không có report hôm nay) |

✅ **Chốt: 2 DailyReports** — chỉ những bé có override được duyệt

⚠️ **Lưu ý:** Trường hợp này sẽ phát sinh vấn đề UX (23 phụ huynh không nhận được báo cáo → có thể lo lắng). Team đã ghi nhận và chấp nhận rủi ro này.

---

### ✅ Edge case 5 — Unmatched assigned cho cùng child

**Tình huống:** Transcript có 2 đoạn ambiguous, cô gán **cả 2 cho Lan**:

> *"Có một bé ăn ít. Sau đó cũng có một bé ho nhẹ."*

UI hiển thị 2 unmatched items → cô gán cả 2 cho Lan → 2 items đều có `kind=assigned, child_id=Lan`.

**Sau khi duyệt → Backend:**
- Lan đã có draft chưa? Chưa → tạo 1 DailyReport cho Lan
- **Merge** content: `ăn uống="ăn ít"`, `health="ho nhẹ"` (không trùng field)
- Nếu cùng field (vd: 2 đoạn đều nói "ăn ít") → nối lại: `ăn uống="ăn ít, ăn ít"`

✅ **Chốt: 1 DailyReport** — auto-merge (unique constraint `(child_id, report_date)` ép buộc)

---

### ✅ Edge case 6 — Transcript rỗng / không hợp lệ

**Tình huống:** STT trả về rỗng, hoặc chỉ có từ khoá không phù hợp.

**Ví dụ:** *"à ừm thì..."* (STT không ra content rõ ràng)

**Hành vi:**
- `validation_service` raise `ValidationError` → backend trả 400
- Frontend dialog "Transcript không hợp lệ, vui lòng ghi âm lại"
- **Không vào review screen**

✅ **Chốt: Validation error từ đầu** — không cần thêm logic

---

### ✅ Edge case 7 — 1 child có 2 segments riêng

**Tình huống:** Cô nói về Lan 2 lần trong transcript:

> *"Bé Lan ăn ít hơn mọi khi. Lát sau bé Lan ho nhẹ 1 tiếng."*

**Hệ thống nhận biết:**
- `extract_multi_person()` đã auto-merge trong `child_extractions["Lan"]`: `{ăn uống: "ăn ít", health: "ho nhẹ"}`

UI hiển thị **1 item** "Bé Lan" với cả 2 fields.

**Sau khi duyệt → Backend:** Tạo 1 DailyReport cho Lan với merged content.

✅ **Chốt: 1 DailyReport merged** — không phải 2 reports

---

## 🔄 Quy tắc ordering (override luôn thắng)

### Nguyên tắc cốt lõi

> **Class-wide content LUÔN là default template** — không cần user duyệt Cả lớp thì mới dùng được.
> Việc duyệt Cả lớp chỉ có ý nghĩa: tạo draft cho **TẤT CẢ các bé** trong lớp (kể cả bé không có override).

Khi user duyệt bất kỳ item nào (override / assigned), hệ thống **TỰ ĐỘNG** merge:
- Class-wide defaults cho các field còn thiếu
- Override fields ghi đè lên defaults

### Setup ví dụ
Transcript có Cả lớp + Lan override + Huy override (lớp 25 bé).

---

### Order A: Duyệt Lan → Cả lớp → Huy

| Bước | Action | DB sau bước | Tổng |
|---|---|---|---|
| 1 | **Duyệt Lan** | Lan: `ăn="ăn ít" (override)`, `ngủ="đủ giấc" (class-wide default)`, `mood="quấy"` | 1 draft |
| 2 | **Duyệt Cả lớp** | 24 drafts mới cho 24 bé chưa có (Lan skip) | 25 drafts |
| 3 | **Duyệt Huy** | UPDATE Huy: `health="ho nhẹ"`, `ăn="cơm ngon" (default)` | 25 drafts |

**Kết quả:** Lan & Huy = override, 23 bé khác = class-wide default ✅

---

### Order B: Duyệt Cả lớp → Lan → Huy

| Bước | Action | DB sau bước | Tổng |
|---|---|---|---|
| 1 | **Duyệt Cả lớp** | 25 drafts cho cả 25 bé (tất cả class-wide default) | 25 drafts |
| 2 | **Duyệt Lan** | UPDATE Lan: override (ăn ít, quấy) ghi đè default | 25 drafts |
| 3 | **Duyệt Huy** | UPDATE Huy: override (ho nhẹ) ghi đè default | 25 drafts |

**Kết quả:** Giống Order A (Lan & Huy = override, 23 bé = default) ✅

---

### Order C: Duyệt Lan → Huy (KHÔNG duyệt Cả lớp)

| Bước | Action | DB sau bước | Tổng |
|---|---|---|---|
| 1 | **Duyệt Lan** | Lan: override + class-wide defaults (cho fields chưa override) | 1 draft |
| 2 | **Duyệt Huy** | Huy: override + class-wide defaults | 2 drafts |

**Kết quả:**
- Lan: có report (override + defaults) ✅
- Huy: có report (override + defaults) ✅
- **23 bé khác: KHÔNG có report** (vì không duyệt Cả lớp)

→ Đây chính là **Edge case 4** (chỉ duyệt override, không duyệt Cả lớp → 23 bé khác skip).

---

### So sánh 3 order

| | Order A | Order B | Order C |
|---|---|---|---|
| Tổng drafts cuối | 25 | 25 | **2** |
| Lan = override | ✅ | ✅ | ✅ |
| Huy = override | ✅ | ✅ | ✅ |
| 23 bé khác | default | default | **KHÔNG có report** |

**Order A = Order B** (cùng kết quả)
**Order C ≠ A, B** (vì không duyệt Cả lớp → 23 bé khác skip)

### Backend pseudo-code (final)

```python
def approve_item(db, voice_id, teacher_id, item):
    voice_record = get_voice_record(db, voice_id, teacher_id)
    class_obj = get_class(voice_record.class_id)
    classwide_content = voice_record.extraction_result.get("class_wide_extraction", {})
    # ↑ Lấy từ extraction, KHÔNG phụ thuộc user có duyệt Cả lớp hay không

    if item.kind == "classwide":
        # Approve Cả lớp = tạo draft cho TẤT CẢ children chưa có
        for child in class_obj.children:
            if not has_draft_today(db, child.id):
                create_draft(child, classwide_content, type=INDIVIDUAL)

    elif item.kind in ("override", "assigned"):
        # Approve override = tạo draft cho 1 child, merge class-wide default + override
        merged = {**classwide_content, **item.content}  # override ghi đè default
        if has_draft_today(db, item.child_id):
            update_draft(item.child_id, today, merged)
        else:
            create_draft(item.child_id, merged, type=EXCEPTION)
```

---

## 🚫 Quy tắc discard (one-way state)

> **Đã chốt:** Duyệt rồi KHÔNG cho loại bỏ. Loại bỏ rồi KHÔNG cho duyệt lại.

### UI state transitions

```
       ┌──────────────┐
       │   Pending    │ ← Initial state khi extract xong
       │ [Duyệt][Bỏ] │
       └──────┬───────┘
              │
       ┌──────┴───────┐
       ▼              ▼
   ┌─────────┐   ┌───────────┐
   │Approved │   │ Discarded │
   │  (✓)    │   │   (✗)    │
   └─────────┘   └───────────┘
   • Draft report created/updated in DB
   • "Bỏ" button ẩn        • "Duyệt" button ẩn
   • Show status badge      • Show status badge
```

- **Pending → Approved**: tạo draft, ẩn nút "Bỏ", show badge "Đã duyệt"
- **Pending → Discarded**: ẩn nút "Duyệt", show badge "Đã loại bỏ"
- **Không có transition ngược** — không undo

### Lý do
- Đơn giản hoá state management (không cần xử lý undo phức tạp)
- Tránh race condition khi user vừa duyệt vừa loại bỏ cùng lúc
- UX rõ ràng: mỗi action là final

---

## 📤 Quy tắc nút "Xác nhận gửi"

> **Đã chốt:** Phải xử lý hết (duyệt hoặc bỏ) **TẤT CẢ items** mới được bấm gửi.

### Behavior

```
Trạng thái nút "Xác nhận gửi":

- Có ít nhất 1 item pending       → DISABLED + hiển thị "Đã xử lý X/Y items"
- Tất cả items = approved/discarded → ENABLED + đổi sang màu cam
```

### Ví dụ

| Items | Nút gửi |
|---|---|
| 1 classwide (pending) | DISABLED - "Đã xử lý 0/1" |
| 1 classwide (approved) | DISABLED - "Đã xử lý 0/2" (còn 1 unmatched chưa xử lý) |
| 1 classwide (approved) + 1 unmatched (discarded) | ENABLED |
| 1 classwide (discarded) + 3 special (2 approved, 1 discarded) | ENABLED |

### Lý do chọn Option 1 (thay vì "gửi khi có 1 approved")

1. **Tránh sót**: cô giáo buộc phải review từng item → không bỏ quên bé nào
2. **State đơn giản**: 3 trạng thái (pending/approved/discarded), không có "gửi một phần"
3. **Phù hợp one-way state**: mỗi item phải có quyết định cuối cùng
4. **Tránh race condition**: nếu cho gửi một phần, items pending có logic xử lý không rõ ràng

### Trade-off
- ❌ Hơi rigid: nếu cô vội chỉ muốn gửi 2 bé đặc biệt, vẫn phải bỏ các items còn lại
- ✅ Workaround tương lai: Bulk discard cho unmatched items (chưa implement Phase 1)

---

## 🛣️ Kế hoạch triển khai

### Ghi chú quan trọng

> **Việc 1 WIP đã bỏ rồi** (`git reset --hard origin/develop`), không cần revert thêm.

### Phase 1 — Backend (a lo)

#### 1.1. Endpoint mới (per-item approval)

##### A. `POST /api/teacher/reports/approve-item`

Mỗi lần user bấm **Duyệt** trên 1 item → gọi endpoint này.

**Request:**
```json
{
  "voice_id": "uuid",
  "teacher_id": "uuid",
  "item": {
    "kind": "classwide | override | assigned",
    "child_id": "uuid (nếu override/assigned)",
    "eating": "...",
    "sleeping": "...",
    "health": "...",
    "activities": "...",
    "mood": "..."
  }
}
```

**Logic xử lý:**

```python
def approve_item(db, voice_id, teacher_id, item):
    voice_record = get_voice_record(db, voice_id, teacher_id)
    class_obj = get_class(voice_record.class_id)
    classwide_content = voice_record.extraction_result.get("class_wide_extraction", {})

    if item.kind == "classwide":
        # Tạo draft cho TẤT CẢ children chưa có draft hôm nay
        for child in class_obj.children:
            if not has_draft_today(db, child.id):
                create_daily_report(
                    db, child, item.content, type=INDIVIDUAL, status=DRAFT
                )
            # else: skip (đã có draft từ override trước đó)

    elif item.kind in ("override", "assigned"):
        child_id = item.child_id
        # Merge class-wide default + override (override ghi đè)
        merged_content = {**classwide_content, **item.content}

        if has_draft_today(db, child_id):
            # Đã có draft → UPDATE
            update_daily_report(db, child_id, today, merged_content)
        else:
            # Chưa có → CREATE
            create_daily_report(
                db, child_id, merged_content, type=EXCEPTION, status=DRAFT
            )

    # Resume
```

**Response:**
```json
{
  "status": "ok",
  "created": 1,          // số report mới tạo
  "updated": 0,          // số report updated (nếu override ghi đè default trước đó)
  "skipped": 24          // số children đã có draft (chỉ áp dụng cho classwide)
}
```

##### B. `POST /api/teacher/reports/send-batch`

Khi user bấm **Xác nhận gửi** → gọi endpoint này để gửi tất cả drafts cho phụ huynh.

**Request:**
```json
{
  "voice_id": "uuid",
  "teacher_id": "uuid"
}
```

**Logic:**
- Lấy tất cả `DailyReport` của `voice_id` có `status=DRAFT`
- Set `status=SENT`, `sent_at=now`
- Gọi `notification_service` gửi cho phụ huynh

**Response:**
```json
{
  "sent_count": 25,
  "report_ids": ["uuid", "uuid", ...]
}
```

#### 1.2. Helper service: `app/services/draft_report_service.py`

```python
def approve_item(db, voice_id, teacher_id, item) -> dict
def send_batch(db, voice_id, teacher_id) -> dict
def _merge_content(classwide_content, override_content) -> dict
def _has_draft_today(db, child_id) -> bool
def _create_daily_report(db, child, content, type, status) -> DailyReport
def _update_daily_report(db, child_id, report_date, content) -> DailyReport
```

#### 1.3. Update `extract_multi_person()`

Đảm bảo `class_wide_extraction` được tách riêng (không trộn vào `child_extractions`):

```python
return {
    "segments": [...],
    "child_extractions": {...},          # per-child (đã có)
    "class_wide_extraction": {          # ← THÊM MỚI: riêng, không trộn
        "meals": "ăn hết suất cơm trưa",
        "sleeping": "ngủ ngon 2 tiếng",
        ...
    },
    "unmatched_segments": [...],
    "class_wide_segments": N,
    "ambiguous_segments": N,
}
```

Hiện tại class-wide extraction đang được trộn vào `child_extractions` (mỗi child default). Cần **tách riêng** để backend dùng cho class-wide default content khi merge với override.

### Phase 2 — Frontend (em lo)

> **Status update (Oct 2026)**: Phase 2.1 (bỏ RecordMode) KHÔNG làm theo quyết định của user
> — giữ enum để không vỡ entry-point cũ; `_buildObservations` chỉ dùng nhánh classroom mode.
> Phase 2.2 → 2.5 đã làm xong (xem chi tiết dưới).

#### 2.1. Bỏ `RecordMode` enum

- ❌ KHÔNG làm (theo quyết định user, giữ enum để tương thích ngược)
- `RecordHubScreen`: giữ nguyên
- `RecordFlowScreen`: giữ nguyên
- Upload: giữ nguyên
- Lý do: nhánh `RecordMode.child` trong `_buildObservations` được giữ làm fallback an toàn,
  không ảnh hưởng flow mới (chỉ chạy khi `widget.mode == child && widget.child != null`)

#### 2.2. Rewrite `_buildObservations()`  ✅ DONE

Input: `class_wide_extraction` + `child_extractions` + `unmatched_segments`/`segments`

Output:
```
1. Classwide item (1) - nếu ext.hasClassWideContent == true
2. Child items (N) - chỉ các bé CÓ override trong childExtractions (lookup theo id hoặc name)
3. Unmatched items (M) - từ rawJson['unmatched_segments'] hoặc ext.segments (filter isClassWide=false, childMatches empty)
```

Helpers: `_classwideItemFromExtraction()`, `_childItemFromExtraction()`, `_unmatchedItem()`

**Không hiển thị 25 items cho 25 bé** — chỉ hiển thị item "Cả lớp" + items override + items unmatched.

#### 2.3. Item state management + approve API  ✅ DONE

Mỗi `_ObservationTile` state: `pending` / `approved` / `discarded` (qua `ObservationDecision` enum, có sẵn)

**Khi user bấm Duyệt** → gọi `_approveItem(item)`:
- Map `item.kind` → API `kind` (classwide/child/unmatched)
- Gọi `teacherRepository.approveItem(voiceRecordId, teacherId, kind, childId?, classId?, extraction?)`
- Lưu `response.draft_report_ids` vào `approvedDraftIds[item.id]`
- Hiển thị spinner trên nút Duyệt (qua `approvingIds: Set<String>`)

**Khi user bấm Loại bỏ** → set state ngay (không gọi BE), xóa draft ids đã thu.

**Khi user bấm "Gửi N báo cáo"** (bottom button) → gọi `_sendBatch()`:
- Gom tất cả draft ids từ `approvedDraftIds.values`
- Dedupe + gọi `teacherRepository.sendBatch(teacherId, reportIds)`
- Lưu `response.sent` → `savedReportsCount` → navigate DoneScreen

#### 2.4. `_ObservationTile` — UI badges theo state  ✅ DONE

- `pending` → show cả 2 nút Duyệt / Loại bỏ
- `approved` → show badge "✓ Đã duyệt" (FilledButton.icon), vẫn có nút Loại bỏ (để có thể bỏ sau)
- `discarded` → show badge "Đã loại bỏ · {name}" + nút "Hoàn tác" (qua `_ObservationTile` early-return)
- `approving` (loading) → show CircularProgressIndicator thay cho 2 nút

#### 2.5. Animation cho discarded tile  ✅ DONE

`_AnimatedObservationWrapper` (TweenAnimationBuilder + Transform.translate + Opacity):
- Khi decision → discarded: slide trái 28px + fade xuống 45% (300ms, easeOutCubic)
- Khi restore: slide về 0 + fade về 100% (300ms)

#### 2.6. Counter X/Y ở header  ✅ DONE

`_CounterPill` ở góc phải header: "Đã duyệt X/Y" — đổi màu khi đủ.

#### 2.7. Disable "Xác nhận gửi" khi còn pending  ✅ DONE

Bottom button `canConfirm = (approvedCount > 0) && (pendingCount == 0) && !isSubmitting`.
Hiển thị 2 banner warning:
- `unmatchedActiveCount > 0` → "Còn M đoạn chưa xử lý..."
- `pendingCount > 0 && unmatchedActiveCount == 0` → "Còn N mục chưa duyệt..."

### Phase 3 — Cleanup

1. Xóa `RecordMode` references trong code cũ
2. Update `teacher_repository.dart`: thêm 2 methods (`approveItem`, `sendBatch`)
3. Test integration: 7 case + ordering (A, B, C) + edge cases

### Phase 3 — Cleanup

1. Xóa `RecordMode` references trong code cũ
2. Update `teacher_repository.dart`: thêm `confirmBatchReport(...)`
3. Test integration: 7 case + edge cases (transcript rỗng, không match ai, tất cả discard)

---

## 📦 Những thứ có thể GIỮ nguyên (không cần đụng)

### Backend
- ✅ `app/services/name_matching_service.py`
- ✅ `app/services/validation_service.py`
- ✅ `app/services/stt_service.py`
- ✅ `app/services/notification_service.py`
- ✅ `app/services/extraction_service.py::extract_multi_person()` (chỉ thêm field `class_wide_extraction`)

### Frontend
- ✅ `_ObservationTile`
- ✅ `_AssignSheet`
- ✅ `_SurfaceBox`
- ✅ `_DestinationPill`
- ✅ `_SummaryRow`
- ✅ `_DoneScreenView`
- ✅ `VoiceRecord`, `ExtractionData` entities
- ✅ `TeacherRepository` (chỉ thêm 1 method `confirmBatchReport`)

### Có thể BỎ (không dùng trong flow mới)
- 🗑️ `ClassBroadcastReport` model (giữ trong DB nhưng không tạo mới)
- 🗑️ `POST /api/teacher/reports/manual` (thay bằng batch)

---

## 📝 Notes & quyết định đã chốt

> Ghi chú thêm trong quá trình làm:

- **2026-09-30 (1):** Chốt kiến trúc: KHÔNG dùng ClassBroadcastReport entity. Mỗi bé luôn có 1 DailyReport riêng, "cả lớp" chỉ là default content áp dụng cho từng report.
- **2026-09-30 (2):** Chốt flow per-item approval:
  - **Duyệt** (per-item) → tạo draft report NGAY, gọi BE
  - **Loại bỏ** (per-item) → chỉ update local state (không gọi BE)
  - **Xác nhận gửi** (global top button) → batch send all drafts
  - 2 endpoints: `approve-item` + `send-batch`
- **2026-09-30 (3):** Chốt 1 chiều: Duyệt rồi KHÔNG cho Loại bỏ (và ngược lại). Mỗi item có 3 state: pending / approved / discarded.
- **2026-09-30 (4):** Override luôn thắng dù duyệt trước/sau class-wide (upsert logic).
- **2026-09-30 (5):** Class-wide content LUÔN là default template. Duyệt Cả lớp chỉ có ý nghĩa tạo draft cho TẤT CẢ các bé trong lớp.
- **2026-09-30 (6):** Nút "Xác nhận gửi" chỉ enabled khi TẤT CẢ items đã xử lý (approved hoặc discarded). Bulk discard cho unmatched = để sau, hiện tại chưa cần.
- **2026-09-30 (7):** **AUDIT & CHỐT Option B** — Sau khi quét toàn project, chốt Option B (Bỏ `ClassBroadcastReport`):
  - Mỗi bé có 1 DailyReport riêng (giống nhau nếu chỉ có class-wide)
  - "Cả lớp" item = content default áp dụng cho từng report
  - Xung đột cần giải quyết: code hiện tại vẫn có `ClassBroadcastReport` table (từ migration `1d221a9914e8`) + `extract_multi_person` chưa tách `class_wide_extraction` riêng
- **2026-09-30 (8):** **Quyết định xử lý `ClassBroadcastReport` table** — **GIỮ NGUYÊN** table + `voice_record.scope` + `daily_report.report_type` để có thể dùng lại trong tương lai. Code MỚI sẽ KHÔNG đụng vào những thứ này. Tương tự, **GIỮ** endpoint `POST /reports/manual` để tương thích ngược (không xóa).

---

## ⚠️ Confirmed: Conficts với Code hiện tại

> Audit 2026-09-30: Plan **đã đúng hướng Option B** từ đầu. Nhưng code hiện tại đang ở Option A (vẫn dùng `ClassBroadcastReport`). Cần fix:

| # | File hiện tại | Vấn đề | Hành động |
|---|---|---|---|
| 1 | `backend/alembic/versions/1d221a9914e8_*.py` | Migration tạo `class_broadcast_report` table + `source_broadcast_id` + `report_type` | ✅ GIỮ migration cũ (không sửa lịch sử), viết **migration mới** drop các thành phần này |
| 2 | `backend/app/models/report.py` (ClassBroadcastReport class) | Model vẫn tồn tại, ORM load nó mỗi lần | ✅ Xóa class `ClassBroadcastReport` + references trong `__init__.py` + `Class_.broadcast_reports`, `Teacher.broadcast_reports`, `VoiceRecord.broadcast_report`, `DailyReport.source_broadcast` |
| 3 | `backend/app/services/extraction_service.py` | `extract_multi_person` KHÔNG có field `class_wide_extraction` riêng trong output | ✅ Modify function để trả về thêm `class_wide_extraction` |
| 4 | `frontend/lib/features/.../record_screens.dart::_buildObservations` | Đang build 25 items (1/child) | ✅ Rewrite để chỉ build cho: classwide (nếu có) + children có override + unmatched segments |
| 5 | `frontend/lib/features/.../record_screens.dart::_confirmAndPublish` | Loop gọi `createManualReport` + `publishReport` cho mỗi item | ✅ Thay bằng: **per-item Duyệt** gọi `approve-item` (tạo draft NGAY), **Xác nhận gửi** gọi `send-batch` 1 lần |
| 6 | `frontend/lib/data/repositories/teacher_repository.dart` | Chỉ có `createManualReport` + `publishReport` | ✅ Thêm method `approveItem(itemId, payload)` + `sendBatch(reportIds)` |
| 7 | `backend/app/api/teacher.py::re_extract_from_edited_transcript` | Đã handle multi-person nhưng schema output không tách `class_wide_extraction` | ✅ Sau khi sửa `extract_multi_person`, output sẽ tự động có field mới |

### Schema mới cho `extraction_result` (sau khi sửa)

```json
{
  "transcript": "Cả lớp ăn cơm ngon. Bé Lan ăn ít.",
  "_mode": "multi_child",
  "segments": [...],
  "class_wide_extraction": {  // ← field MỚI (lưu content class-wide để dùng làm default)
    "meals": "ăn cơm ngon",
    "sleeping": null,
    "health": null,
    "activities": null,
    "mood": null
  },
  "child_extractions": {
    "lan_uuid": {  // ← chỉ chứa children CÓ override, không chứa all 25
      "meals": "ăn ít",
      "sleeping": null,
      "health": null,
      "activities": null,
      "mood": null
    },
    "huy_uuid": {
      "health": "ho nhẹ",
      ...
    }
  },
  "ambiguous_segments": 0,
  "unmatched_segments": 0,
  "class_wide_segments": 1
}
```

---

## 🛣️ Kế hoạch triển khai (CẬP NHẬT - không drop table, không xóa endpoint cũ)

### Phase 1 — Backend (5 tasks)

| # | Task | Files | Status |
|---|---|---|---|
| 1.1 | Modify `extract_multi_person()` → thêm `class_wide_extraction` + chỉ giữ children CÓ override trong `child_extractions` | `services/extraction_service.py` | ✅ |
| 1.2 | Service `app/services/draft_report_service.py` với 3 functions: `create_classwide_drafts`, `create_child_draft`, `create_unmatched_drafts` | services mới | ✅ |
| 1.3 | Endpoint `POST /api/teacher/reports/approve-item` (handle 3 kinds: classwide, child, unmatched) | `api/teacher.py` | ✅ |
| 1.4 | Endpoint `POST /api/teacher/reports/send-batch` (giống `send-all` nhưng filter theo draft IDs returned từ approve-item) | `api/teacher.py` | ✅ |
| 1.5 | Update `re_extract_from_edited_transcript` response (pass through `class_wide_extraction` field mới) | `api/teacher.py` | ✅ |
| 1.6 | **Unify `re_extract_from_edited_transcript`**: bỏ nhánh single-child, LUÔN chạy `extract_multi_person()` (flow mới chỉ có 1 nút ghi âm, backend auto-detect). Bỏ import `extract_from_transcript` ở teacher.py | `api/teacher.py` | ✅ |

### Phase 2 — Frontend (5 tasks)

| # | Task | Files | Status |
|---|---|---|---|
| 2.1 | Thêm methods `approveItem` + `sendBatch` vào `TeacherRepository` | `data/repositories/teacher_repository.dart` | ✅ |
| 2.2 | Rewrite `_buildObservations()` → dùng `class_wide_extraction` cho "Cả lớp", chỉ build items cho children có override + unmatched | `features/kindergarten_dashboard/screens/record_screens.dart` | ⏳ |
| 2.3 | Rewrite approve flow: per-item gọi `approveItem` NGAY, button Xác nhận gọi `sendBatch` 1 lần | `record_screens.dart` | ⏳ |
| 2.4 | Counter "Đã xử lý X/Y items" + disable Xác nhận khi còn pending + logic đếm items | `record_screens.dart` | ⏳ |
| 2.5 | `_ObservationTile` badge discard (hiển thị "Đã loại bỏ") + animation | `record_screens.dart` | ⏳ |

### Phase 3 — Test & Cleanup (3 tasks, KHÔNG xóa code cũ)

| # | Task | Files | Status |
|---|---|---|---|
| 3.1 | Update `test_class_wide.py` → test field `class_wide_extraction` + chỉ chứa children có override | `services/test/test_class_wide.py` | ⏳ |
| 3.2 | Test 7 edge cases (E2E từ upload → extract → approve → send) | `tests/test_e2e_auto_detect.py` (mới) | ⏳ |
| 3.3 | Update `frontend/test/review_screen_test.dart` cho flow mới | `frontend/test/` | ⏳ |

### ⚠️ KHÔNG làm (giữ nguyên để tương thích)
- ❌ KHÔNG drop `class_broadcast_report` table
- ❌ KHÔNG xóa endpoint `POST /reports/manual`
- ❌ KHÔNG xóa `ClassBroadcastReport` model
- ❌ KHÔNG xóa `voice_record.scope` / `daily_report.report_type`
- ✅ Code MỚI chỉ thêm vào, KHÔNG phá code cũ

---

## 🔗 Tham khảo

- Backend code:
  - `backend/app/api/teacher.py` — endpoint hiện tại
  - `backend/app/services/extraction_service.py` — multi-person extraction
  - `backend/app/services/name_matching_service.py` — name matching
  - `backend/app/services/validation_service.py` — content validation
  - `backend/app/models/report.py` — ORM models
- Frontend code:
  - `frontend/lib/features/kindergarten_dashboard/screens/record_screens.dart` — main flow
  - `frontend/lib/data/repositories/teacher_repository.dart` — API client
  - `frontend/lib/domain/entities/report/daily_report.dart` — entity mirror
- Git: branch `feature/auto-detect-recording-mode` (đã sync với `origin/develop` @ `dd2f140`)
