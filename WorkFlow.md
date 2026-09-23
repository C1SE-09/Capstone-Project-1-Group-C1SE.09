# KinderLog - Hệ Thống Sổ Liên Lạc Điện Tử Mầm Non Thông Minh

KinderLog là giải pháp hỗ trợ giáo viên mầm non ghi nhận nhật ký hoạt động hàng ngày của trẻ thông qua giọng nói, tự động chuyển đổi thành văn bản (Speech-to-Text với **PhoWhisper**) và phân loại ngữ nghĩa (NLP **LSTM Classifier**) để tạo báo cáo ngày gửi tới phụ huynh.

---

## 1. Sơ đồ Kiến trúc & Luồng hoạt động Tổng thể (Architecture Flowchart)

```mermaid
flowchart TD
    %% Định nghĩa các tác nhân người dùng
    subgraph Clients["📱 Lớp Ứng Dụng (Flutter Mobile App)"]
        Teacher["👩‍🏫 Giáo viên<br/>(Teacher Screen / Recording)"]
        Parent["👨‍👩‍👧 Phụ huynh<br/>(Parent Screen / Report View)"]
    end

    %% Backend API
    subgraph Backend["⚡ Backend API Service (FastAPI)"]
        API["FastAPI App (app/main.py)"]
        TeacherRouter["Teacher Router<br/>(/api/teacher)"]
        DashboardRouter["Dashboard & Class Router<br/>(/api/dashboard, /api/class)"]
        NLPEngine["NLP Classifier Service<br/>(app/services/extraction_service.py)"]
    end

    %% Lưu trữ & Hàng đợi
    subgraph StorageQueue["💾 Lưu Trữ & Hàng Đợi (Infrastructure)"]
        MinIO[("🪣 MinIO Object Storage<br/>(Lưu file Audio .m4a/.wav)")]
        PostgreSQL[("🐘 PostgreSQL Database<br/>(Users, Children, Reports, VoiceRecords)")]
        Redis[("⚡ Redis Broker & Result Backend<br/>(Queue: audio)")]
    end

    %% Worker AI ngầm
    subgraph AIWorker["🤖 Asynchronous AI Worker (Celery)"]
        CeleryWorker["Celery Worker (app/tasks/celery_app.py)"]
        PhoWhisper["🎙️ PhoWhisper Large CT2<br/>(Speech-to-Text CTranslate2)"]
    end

    %% Luồng Giáo viên ghi âm và xử lý Voice
    Teacher -->|"1. Ghi âm & Upload Audio<br/>POST /api/teacher/voice/upload"| TeacherRouter
    TeacherRouter -->|"2. Lưu file âm thanh"| MinIO
    TeacherRouter -->|"3. Tạo VoiceRecord (status: PENDING)"| PostgreSQL
    TeacherRouter -->|"4. Đẩy job phiên âm vào Queue"| Redis

    %% Celery Worker lấy task từ Redis
    Redis -->|"5. Nhận task process_audio_task"| CeleryWorker
    CeleryWorker -->|"6. Tải audio từ MinIO URL"| MinIO
    CeleryWorker -->|"7. Nhận dạng giọng nói (STT)"| PhoWhisper
    PhoWhisper -->|"8. Trả về transcript tiếng Việt"| CeleryWorker
    CeleryWorker -->|"9. Cập nhật raw_transcript & status: COMPLETED"| PostgreSQL

    %% Giáo viên xem và chỉnh sửa transcript
    Teacher -->|"10. Lấy kết quả transcript & Sửa nếu cần<br/>GET/PUT /api/teacher/voice/{id}"| TeacherRouter
    TeacherRouter <-->|"Truy vấn / Cập nhật transcript"| PostgreSQL

    %% Trích xuất nội dung bằng NLP
    Teacher -->|"11. Yêu cầu bóc tách nội dung<br/>POST /api/teacher/voice/{id}/extract"| TeacherRouter
    TeacherRouter -->|"12. Phân loại câu (Meals, Sleep, Health,...)"| NLPEngine
    NLPEngine -->|"13. Trả về JSON 5 danh mục hoạt động"| TeacherRouter

    %% Lưu nháp và Xuất bản báo cáo
    Teacher -->|"14. Lưu báo cáo nháp (DRAFT)<br/>POST /api/teacher/reports/draft"| TeacherRouter
    Teacher -->|"15. Phát hành báo cáo (PUBLISH)<br/>POST /api/teacher/reports/{id}/publish"| TeacherRouter
    TeacherRouter -->|"16. Ghi DailyReport & ActivityEntries"| PostgreSQL

    %% Phụ huynh theo dõi
    Parent -->|"17. Xem nhật ký hoạt động & Báo cáo của con<br/>GET /api/parent/{id}/child & /reports"| DashboardRouter
    DashboardRouter -->|"18. Đọc báo cáo PUBLISHED"| PostgreSQL
```

---

## 2. Sơ đồ Tuần tự Luồng Nghiệp vụ Chi tiết (Voice-to-Report Sequence Diagram)

```mermaid
sequenceDiagram
    autonumber
    actor T as 👩‍🏫 Giáo viên (Flutter)
    participant API as ⚡ FastAPI Backend
    participant S3 as 🪣 MinIO Storage
    participant DB as 🐘 PostgreSQL
    participant R as ⚡ Redis Queue
    participant W as 🤖 Celery Worker (PhoWhisper)
    participant NLP as 🧠 NLP Model (LSTM)
    actor P as 👨‍👩‍👧 Phụ huynh (Flutter)

    Note over T, API: BƯỚC 1: GHI ÂM & NHẬN DẠNG GIỌNG NÓI (STT)
    T->>API: POST /api/teacher/voice/upload (audio file, teacher_id, child_id)
    API->>API: Validate file & ffprobe đo thời lượng (duration)
    API->>S3: Upload file âm thanh (.m4a/.wav)
    S3-->>API: Trả về audio_url
    API->>DB: Tạo VoiceRecord (status: PENDING)
    API->>R: Dispatch task process_audio_task(voice_record_id)
    API-->>T: Phản hồi 201 Created (voice_record_id, status: PENDING)

    Note over R, W: Celery Worker xử lý nền bất đồng bộ
    R->>W: Nhận task từ queue "audio"
    W->>DB: Cập nhật status = PROCESSING
    W->>S3: Tải file audio từ audio_url
    W->>W: PhoWhisper CT2 chạy phiên âm âm thanh sang text
    W->>DB: Cập nhật raw_transcript, status = COMPLETED
    W-->>R: Hoàn tất task

    Note over T, API: BƯỚC 2: KIỂM TRA & HIỆU CHỈNH BẢN GHI (TRANSCRIPT)
    T->>API: GET /api/teacher/voice/{voice_id} (Polling / kiểm tra trạng thái)
    API->>DB: Lấy VoiceRecord
    DB-->>API: Trả về dữ liệu transcript
    API-->>T: Trả về VoiceRecordDetail (status: COMPLETED, raw_transcript)
    opt Giáo viên chỉnh sửa lỗi chính tả
        T->>API: PUT /api/teacher/voice/{voice_id}/transcript (edited_transcript)
        API->>DB: Lưu edited_transcript
        API-->>T: Xác nhận cập nhật
    end

    Note over T, NLP: BƯỚC 3: AI TRÍCH XUẤT THÔNG TIN HOẠT ĐỘNG (EXTRACTION)
    T->>API: POST /api/teacher/voice/{voice_id}/extract
    API->>NLP: extract_from_transcript(transcript)
    NLP->>NLP: Phân loại từng câu vào: meals, sleeping, health, activities, mood
    NLP-->>API: Trả về JSON cấu trúc 5 mục hoạt động
    API->>DB: Cập nhật extraction_result vào VoiceRecord
    API-->>T: Trả về kết quả phân loại cho giáo viên xem trước

    Note over T, P: BƯỚC 4: TẠO BÁO CÁO & XUẤT BẢN GỬI PHỤ HUYNH
    T->>API: POST /api/teacher/reports/draft (voice_id, edited_extraction)
    API->>DB: Lưu DailyReport (status: DRAFT) + ActivityEntries
    API-->>T: Trả về report_id (DRAFT)
    
    T->>API: POST /api/teacher/reports/{report_id}/publish
    API->>DB: Chuyển DailyReport sang PUBLISHED & gắn published_at
    API-->>T: Xác nhận xuất bản thành công (PUBLISHED)

    Note over P, DB: BƯỚC 5: PHỤ HUYNH XEM BÁO CÁO
    P->>API: GET /api/child/{child_id}/reports
    API->>DB: Lấy danh sách DailyReport đã PUBLISHED kèm ActivityEntries
    DB-->>API: Trả về dữ liệu báo cáo
    API-->>P: Hiển thị nhật ký ngày của bé trên ứng dụng
```

---

## 3. Các Thành phần Công nghệ Chính

- **Frontend**: Flutter (Dart) cho cả Teacher App & Parent App.
- **Backend**: FastAPI (Python), SQLAlchemy ORM, Pydantic.
- **AI / Speech-to-Text**: Celery Worker kết hợp **PhoWhisper-large-ct2** (CTranslate2) chạy GPU (CUDA) hoặc CPU fallback.
- **AI / NLP Classifier**: Model LSTM PyTorch (`text_classifier_model.pt`) phân loại câu thành 5 nhóm:
  - `meals`: Ăn uống
  - `sleeping`: Ngủ nghỉ
  - `health`: Sức khỏe, thân nhiệt
  - `activities`: Vui chơi, học tập
  - `mood`: Tâm trạng, cảm xúc
- **Message Broker & Queue**: Redis.
- **Storage**: MinIO (Object Storage) & PostgreSQL 16 (Relational DB).
