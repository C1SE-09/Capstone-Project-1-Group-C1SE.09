# Backend API — Ghi nhiều bản âm rồi gửi trích xuất 1 lần

> **Phạm vi:** Chỉ backend. Frontend do bạn/bạn bè xử lý.
> **Nguyên tắc:** Backend **không** thay đổi logic extraction. Transcript của N bản
> được **gộp thành 1 text** rồi chạy NLP **1 lần** — đúng như `extract_multi_person`
> đang xử lý (nó tự tách segment bằng regex `[.!?\n]+`, nên newline là ranh giới
> segment sạch sẽ).

---

## 1. Tóm tắt flow

```
[Mở màn hình ghi âm]
   POST /voice/sessions            → tạo phiên, nhận session_id
                                     (mặc định idempotent: vào lại app vẫn
                                      nhận đúng phiên cũ + các bản ghi cũ)
   (hoặc GET /voice/sessions       → liệt kê phiên ACTIVE của hôm nay nếu mở lại app)

[Ghi âm bản 1]
   POST /voice/upload  (session_id) → 201 { id, status: "pending" }
   GET  /voice/{id}                → poll tới khi status = "completed"
   → hiển thị thanh ghi âm #1

[Ghi âm bản 2 ... bản N]           → lặp lại y như trên, cùng session_id

[Bấm nút X trên thanh ghi âm]
   DELETE /voice/{id}              → xoá bản ghi + file MinIO

[Bấm "Gửi" 1 lần]
   POST /voice/sessions/{sid}/merge → gộp transcript N bản → 1 text
   POST /voice/{representative_id}/analyze  (edited_transcript = text gộp)
   → kết quả extraction như flow hiện tại
```

---

## 2. Endpoints mới

### 2.1 `POST /api/teacher/voice/sessions` — Tạo / mở lại phiên ghi âm

**Body (JSON):**
```json
{
  "teacher_id": "bbbbbbbb-0000-0000-0000-000000000001",
  "class_id": "aaaaaaaa-0000-0000-0000-000000000001",
  "child_id": null,
  "scope": "whole_class",
  "recorded_at": null,
  "force_new": false
}
```

| Field | Bắt buộc | Ghi chú |
|---|---|---|
| `teacher_id` | ✅ | UUID giáo viên |
| `class_id` | ✅ | UUID lớp |
| `child_id` | ❌ | Chỉ khi `scope = "single_child"` |
| `scope` | ❌ | `"whole_class"` (mặc định) hoặc `"single_child"` |
| `recorded_at` | ❌ | `YYYY-MM-DD`, mặc định = hôm nay (giờ VN) |
| `force_new` | ❌ | `false` (mặc định) → **tái sử dụng** phiên ACTIVE của (teacher, lớp, ngày) nếu đã có. `true` → luôn tạo phiên mới |

> ⚠️ **`force_new` rất quan trọng:** mặc định endpoint này là **idempotent**.
> Khi cô vào lại màn hình ghi âm sau khi thoát app, gọi lại `POST /voice/sessions`
> sẽ **trả về đúng phiên cũ** kèm các bản ghi đã có — không sinh phiên rác,
> không làm mất bản ghi.
> Chỉ dùng `force_new: true` khi cố ý bắt đầu phiên mới trong cùng 1 ngày.

**Response `201`:**
```json
{
  "session_id": "…uuid…",
  "teacher_id": "…",
  "class_id": "…",
  "child_id": null,
  "scope": "whole_class",
  "status": "active",
  "recorded_at": "2026-11-03",
  "merged_transcript": null,
  "representative_voice_record_id": null,
  "pending_count": 0,
  "completed_count": 0,
  "clips": []
}
```

> **Không bắt buộc gọi**: nếu bạn upload mà không truyền `session_id`, backend tự
> tạo/lấy phiên ACTIVE của `(teacher, lớp, hôm nay)`.

---

### 2.2 `GET /api/teacher/voice/sessions` — Liệt kê phiên

**Query params (tất cả optional):**

| Param | Kiểu | Ghi chú |
|---|---|---|
| `teacher_id` | UUID | **Bắt buộc** |
| `class_id` | UUID | Lọc theo lớp |
| `recorded_at` | `YYYY-MM-DD` | Lọc theo ngày |
| `status` | `active`\|`merged`\|`discarded` | Lọc theo trạng thái |

**Response `200`:** mảng các session (cùng shape với 2.1).

> Dùng để mở lại phiên ghi âm cũ khi app được kill giữa buổi.

---

### 2.3 `GET /api/teacher/voice/sessions/{session_id}` — Chi tiết phiên

**Query:** `teacher_id` (bắt buộc)

**Response `200`:** shape như 2.1, kèm `clips`:

```json
{
  "clips": [
    {
      "voice_record_id": "…uuid…",
      "status": "completed",
      "audio_url": "http://minio:9000/audio/teacher_…_clip1.m4a",
      "audio_duration": 42.5,
      "file_size_bytes": 128000,
      "transcript": "Bé Lan ăn sáng cháo.",
      "error_message": null,
      "is_representative": true,
      "created_at": "2026-11-03T09:15:00+00:00"
    }
  ],
  "pending_count": 1,
  "completed_count": 2
}
```

| Field của clip | Ghi chú |
|---|---|
| `status` | `pending` \| `processing` \| `completed` \| `failed` |
| `transcript` | Đã có `edited_transcript` thì ưu tiên `edited_transcript`, không thì `raw_transcript` |
| `audio_url` | URL file trên MinIO — dùng để phát lại (nút nghe) |
| `is_representative` | `true` cho bản đại diện (nơi lưu `extraction_result`) |
| `error_message` | Chỉ có khi `status = "failed"` |

| Field của session | Ghi chú |
|---|---|
| `pending_count` | Số bản **chưa** STT xong → **disable nút "Gửi"** khi > 0 |
| `completed_count` | Số bản sẽ được gộp khi bấm "Gửi" |

> **Thứ tự `clips`** luôn theo đúng thứ tự cô ghi (dựa `clip_order`), không phụ
> thuộc timestamp.

---

### 2.4 `POST /api/teacher/voice/sessions/{session_id}/merge` — Gộp transcript

**Body (JSON):**
```json
{
  "teacher_id": "bbbbbbbb-0000-0000-0000-000000000001",
  "edited_transcript": null
}
```

- `edited_transcript = null` → backend tự gộp từ các bản đã STT xong.
- `edited_transcript = "..."` → dùng luôn text này (trường hợp cô sửa tay).

**Response `200`:**
```json
{
  "session_id": "…uuid…",
  "merged_transcript": "Bé Lan ăn sáng cháo.\nBé Lan ăn chiều cơm.",
  "clip_count": 2,
  "skipped_clips": 1,
  "representative_voice_record_id": "…uuid…"
}
```

| Field | Ghi chú |
|---|---|
| `merged_transcript` | Các bản nối bằng `\n` |
| `clip_count` | Số bản **được gộp** (status = completed, transcript rỗng) |
| `skipped_clips` | Số bản bị bỏ qua (chưa STT xong / lỗi / transcript rỗng) |
| `representative_voice_record_id` | Bản ghi đại diện — dùng `id` này cho `/analyze` |

**Mã lỗi:**

| Code | Ý nghĩa |
|---|---|
| `404` | Không tìm thấy phiên |
| `403` | `teacher_id` không khớp chủ phiên |
| `400` | Chưa có bản nào STT xong thành công → `merged_transcript` rỗng |

> **Ràng buộc:** transcript gộp bị cắt ở **100 000 ký tự**.

---

### 2.5 `DELETE /api/teacher/voice/{voice_id}` — Xoá 1 bản ghi (nút X)

**Query:** `teacher_id` (bắt buộc)

**Response `200`:**
```json
{
  "voice_record_id": "…uuid…",
  "deleted": true,
  "audio_deleted": true,
  "session_id": "…uuid…"
}
```

- Xoá row trong DB **và** file audio trên MinIO.
- Nếu xoá bản đại diện → backend tự trỏ đại diện về `null`; lúc merge sẽ chọn
  lại bản đầu tiên còn lại.

**Mã lỗi:** `404` (không tồn tại) · `403` (không phải của giáo viên này)

---

### 2.6 `DELETE /api/teacher/voice/sessions/{session_id}` — Huỷ phiên

**Query:** `teacher_id` (bắt buộc)

**Response `200`:** `{ "session_id": "…", "status": "discarded", "deleted": true }`

> Chỉ đánh dấu `discarded`, **không** xoá các bản ghi (giữ lại để tham khảo/audit).

---

## 3. Thay đổi endpoint cũ

### `POST /api/teacher/voice/upload`

Thêm form field **optional**:

| Field | Kiểu | Ghi chú |
|---|---|---|
| `session_id` | UUID | Gom bản ghi này vào phiên đã có. Bỏ trống → backend tự tạo/lấy phiên ACTIVE của `(teacher, lớp, hôm nay)`. |

Các field cũ (`file`, `teacher_id`, `class_id`, `child_id`) **không đổi**.
Response `201` **không đổi**: `{ "id": "...", "voice_record_id": "...", "status": "pending" }`.

> `status` luôn là `"pending"` ngay sau upload. App cần **poll**
> `GET /voice/{voice_id}?teacher_id=…` để biết khi nào `"completed"`.

---

## 4. Gợi ý tích hợp phía Flutter

```dart
// 1. Mở màn hình ghi âm (gọi lại mỗi lần vào màn hình — idempotent, an toàn)
final session = await repo.createVoiceSession(
  teacherId: teacherId, classId: classId, scope: 'whole_class',
);
// → session.sessionId, session.clips (đã có sẵn bản ghi cũ nếu có)
// → session.pendingCount, session.completedCount

// 2. Ghi âm & upload từng bản
final res = await repo.uploadVoice(
  file: audioFile,
  teacherId: teacherId,
  classId: classId,
  sessionId: session.sessionId,   // ← thêm param này
);
// → res.id, poll GET /voice/{id} cho tới khi status == 'completed'

// 3. Xoá 1 bản (nút X)
await repo.deleteVoiceClip(voiceId: clipId, teacherId: teacherId);

// 4. Bấm "Gửi" 1 lần
final merged = await repo.mergeVoiceSession(
  sessionId: session.sessionId, teacherId: teacherId,
);
// → merged.mergedTranscript, merged.representativeVoiceRecordId

// 5. Chạy NLP 1 lần trên transcript gộp (endpoint cũ, không đổi)
await repo.analyzeVoice(
  voiceId: merged.representativeVoiceRecordId!,
  editedTranscript: merged.mergedTranscript,
  teacherId: teacherId,
);
```

### Lưu ý về trạng thái nút "Gửi"

Dùng `session.pendingCount` để disable nút "Gửi":

```dart
final canSend = session.completedCount > 0 && session.pendingCount == 0;
```

Lý do: bản `pending` sẽ bị bỏ qua khi gộp (xem `skipped_clips` trong response merge).

### Xử lý khi app bị kill giữa buổi

`POST /voice/sessions` mặc định **idempotent** → gọi lại khi vào màn hình sẽ
nhận về đúng phiên cũ kèm `clips` đã có. Không cần lưu `session_id` ở local.

Nếu vẫn muốn chủ động tìm phiên (ví dụ muốn hiện danh sách phiên của ngày):
`GET /voice/sessions?teacher_id=…&recorded_at=2026-11-03&status=active`.

### Thoát app thì STT có tự chạy không? → **CÓ**

Đây là điều quan trọng nhất của user story, nên backend đã xử lý chắc chắn:

| Câu hỏi | Trả lời |
|---|---|
| Cô ghi xong rồi **tắt app**, STT có chạy tiếp không? | ✅ **Có.** Toàn bộ việc chuyển giọng nói → chữ chạy trên **server** (Celery worker + Redis + PhoWhisper), không liên quan gì tới app đang mở hay đóng. |
| Mở lại app thì bản ghi còn không? | ✅ **Còn.** Bản ghi nằm trong DB + file trên MinIO, `GET /voice/sessions` trả về đầy đủ `clips` kèm `status` và `transcript`. |
| Cô có cần làm gì thủ công không? | ❌ Không. Chỉ cần gọi `GET /voice/sessions` khi mở màn hình. |

**Cơ chế 3 lớp để bản ghi không bao giờ bị kẹt:**

1. **Upload xong → task đã nằm trong Redis** (queue `audio`). Worker audio (RunPod)
   lấy task ra và chạy PhoWhisper. Tắt app không ảnh hưởng.
2. **Lỡ worker audio đang tắt** → task vẫn nằm trong Redis, worker bật lại là
   xử lý ngay (không mất).
3. **Lỡ task mất** (Redis restart,…) → backend có cơ chế **re-dispatch tự động**:
   - một Celery Beat task quét mỗi **2 phút**, đẩy lại bản ghi nào đang `pending`
     quá 3 phút;
   - **và** ngay khi cô mở lại app, `GET /voice/sessions` cũng tự đẩy lại các bản
     ghi kẹt của cô ấy → cô thấy transcript sớm nhất có thể.

> ℹ️ Nếu `GET /voice/sessions` trả về `status: "pending"` kéo dài, đó là vì
> **worker audio (RunPod) đang tắt**, không phải lỗi của app. Khi worker bật
> lại, transcript sẽ tự xuất hiện (không cần cô upload lại).

---

## 5. Vì sao gộp transcript chứ không gộp kết quả extract?

`extract_multi_person` làm 3 việc: tách segment → match tên bé → gom vào 3 bucket
(`class_wide` / `child_extractions` / `unmatched`).

Nếu extract từng bản riêng rồi ghép kết quả:
- phải tự viết lại logic merge,
- bucket `child_extractions` dùng semantics **REPLACE** → bản sau đè bản trước,
  mất dữ liệu.

Gộp transcript trước rồi gọi 1 lần → giữ nguyên toàn bộ semantics sẵn có,
**không đụng vào logic extraction** (đúng yêu cầu).

---

## 6. Migration

```
b7d8e9f0a1b3  add voice_recording_session (multi-clip recording sessions)
c8e9f0a1b2c4  add stt dispatch tracking to voice_record
```

Đã apply lên DB `capstone_db`.

`b7d8e9f0a1b3` thêm:
- bảng `voice_recording_session`
- `voice_record.session_id` (FK, `ON DELETE SET NULL`)
- `voice_record.clip_order` (thứ tự bản ghi trong phiên)

`c8e9f0a1b2c4` thêm (phục vụ cơ chế re-dispatch — mục "Thoát app thì STT có tự
chạy không?" ở phần 4):
- `voice_record.stt_dispatch_attempts` (số lần đã đẩy task STT)
- `voice_record.last_stt_dispatch_at` (mốc thời gian đẩy gần nhất)

Bản ghi cũ (`session_id = NULL`) vẫn dùng được như trước — không breaking change.

> ⚠️ **Cần chạy `celery beat`** để cơ chế re-dispatch tự động hoạt động.
> Trong `docker-compose.yml` đã thêm service `beat`. Nếu deploy RunPod,
> nhớ khởi động beat trên VPS (worker `notifications` sẽ chạy task này).

