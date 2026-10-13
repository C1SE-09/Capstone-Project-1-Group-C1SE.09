# KinderLog Admin Web

Web quản lý bug reports cho **Admin App / dev team**.

> ⚠️ **Phân biệt rõ 2 loại admin:**
> - **Admin nhà trường** → dùng **Flutter app** (quản lý giáo viên, phụ huynh, học sinh, lịch học)
> - **Admin app (bọn tôi)** → dùng **web này** (xử lý bug reports từ giáo viên / phụ huynh gửi lên)

## 🎯 Tính năng hiện tại (v1.0)

- ✅ Đăng nhập / đăng xuất (JWT)
- ✅ Dashboard thống kê (tổng, theo status, severity, category, role)
- ✅ Danh sách bug reports (filter + search + pagination)
- ✅ Chi tiết bug report + đổi trạng thái + thêm ghi chú

## 🚀 Cách chạy

### 1. Setup backend (1 lần)

```bash
cd backend

# Cài dependencies (nếu chưa có)
pip install -r requirements.txt

# Chạy migration để tạo bảng admin_user
alembic upgrade head

# Tạo web admin đầu tiên
python -m scripts.seed_admin \
  --email admin@kinderlog.dev \
  --password "Admin@123" \
  --name "Web Admin" \
  --super
```

### 2. Chạy backend FastAPI

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

Backend chạy ở: `http://localhost:8000`
Swagger docs: `http://localhost:8000/docs`

### 3. Chạy web admin

```bash
cd admin-web

# Cài dependencies
npm install

# Copy env
cp .env.example .env.local

# Chạy dev
npm run dev
```

Web chạy ở: `http://localhost:3001`

### 4. Đăng nhập

Mở `http://localhost:3001` → dùng email/password đã tạo ở bước 1.

## 📡 API Backend được dùng

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| `POST` | `/api/admin-auth/login` | Đăng nhập, lấy JWT |
| `GET` | `/api/admin-auth/me` | Lấy thông tin admin hiện tại |
| `GET` | `/api/bug-reports/stats` | Thống kê cho dashboard |
| `GET` | `/api/bug-reports` | Danh sách (filter + pagination) |
| `GET` | `/api/bug-reports/{id}` | Chi tiết 1 report |
| `PATCH` | `/api/bug-reports/{id}` | Cập nhật status + comment |

## 🗂️ Cấu trúc thư mục

```
admin-web/
├── pages/
│   ├── _app.tsx              # Root component
│   ├── _document.tsx         # HTML document
│   ├── login.tsx             # Trang đăng nhập
│   ├── index.tsx             # Dashboard
│   └── bug-reports/
│       ├── index.tsx         # Danh sách
│       └── [id].tsx          # Chi tiết
├── components/
│   ├── AdminLayout.tsx       # Sidebar + header
│   └── ui.tsx                # Card, Badge, StatCard...
├── lib/
│   ├── api.ts                # Fetch wrapper + JWT
│   └── format.ts             # Format helpers
├── styles/
│   └── globals.css           # Tailwind + global styles
├── package.json
├── next.config.js
├── tailwind.config.js
└── tsconfig.json
```

## 🎨 Tech stack

- **Next.js 14** (App Router dùng Pages Router cho đơn giản)
- **TypeScript**
- **Tailwind CSS**
- **SWR** cho data fetching + auto-revalidation
- **JWT** lưu trong `localStorage`

## 🔐 Bảo mật

- JWT token lưu ở `localStorage` (đơn giản cho MVP)
- Token hết hạn sau **8 tiếng** (cấu hình ở `ACCESS_TOKEN_EXPIRE_MINUTES` trong `admin_auth_service.py`)
- Khi token hết hạn → API trả 401 → user cần login lại
- Web admin **TÁCH BIỆT** với `users.role=admin` của nhà trường (bảng `admin_user` riêng)

## ❓ Câu hỏi thường gặp

**Tôi quên password admin web thì sao?**
Chạy lại `python -m scripts.seed_admin` với email khác, hoặc tự reset trong DB.

**Tôi có thể tạo nhiều admin web không?**
Có. Mỗi lần chạy `seed_admin` với email khác sẽ tạo thêm 1 admin.

**Admin web có cần thay đổi gì khi deploy lên server thật không?**
Sửa `NEXT_PUBLIC_API_BASE_URL` trong `.env.production` thành URL backend thật.

**Có thể thêm trang quản lý users / teachers ở đây không?**
Được nhưng CẢNH BÁO: sẽ tạo thêm bảng và quyền phức tạp. Tốt nhất để admin nhà trường dùng app, admin app chỉ lo bug reports.
