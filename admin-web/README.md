# KinderLog Admin Web

Web admin cho hệ thống KinderLog — hỗ trợ 2 loại tài khoản trên cùng 1 trang đăng nhập:

| Loại tài khoản | Bảng backend | Trang sau đăng nhập |
|---|---|---|
| **Admin trường** (School Admin) | `users.role='admin'` | `/school-admin` (Tổng quan / Chức năng / Tài khoản) |
| **Web Admin** (Dev team) | `admin_user` | `/` (Trang chủ + Bug Reports) |

Trang login `pages/login.tsx` tự nhận diện loại tài khoản và điều hướng.

## Khởi chạy

```bash
npm install
npm run dev    # http://localhost:3001
```

Biến môi trường (xem `.env.local`):

```
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

## Cấu trúc

```
admin-web/
├── pages/
│   ├── login.tsx              ← Đăng nhập chung (auto-detect role)
│   ├── index.tsx              ← Trang chủ Web Admin (bug reports dashboard)
│   ├── bug-reports/
│   │   ├── index.tsx          ← Danh sách bug reports
│   │   └── [id].tsx           ← Chi tiết bug report
│   └── school-admin/
│       ├── index.tsx          ← Tổng quan (KPI + class progress + chart)
│       ├── features.tsx       ← Hub: 4 danh mục (GV/HS/PH/Lịch)
│       ├── teachers.tsx       ← CRUD giáo viên
│       ├── students.tsx       ← CRUD học sinh
│       ├── parents.tsx        ← CRUD phụ huynh
│       ├── schedules.tsx      ← CRUD thời khóa biểu
│       └── account.tsx        ← Tài khoản + đổi mật khẩu
├── components/
│   ├── AdminLayout.tsx        ← Layout Web Admin (bug reports)
│   ├── SchoolAdminLayout.tsx  ← Layout School Admin
│   ├── ui.tsx                 ← UI shared (Card, Badge, ...)
│   └── ui-school.tsx          ← UI School Admin (KpiCard, Modal, Toast, ...)
├── lib/
│   ├── api.ts                 ← fetch wrapper (2 loại account)
│   ├── admin-api.ts           ← Type-safe CRUD cho school-admin
│   └── format.ts              ← Format helpers
└── styles/globals.css         ← Design tokens (canvas, line, ink, brand…)
```

## Design system

Đồng bộ 100% với Flutter app (`frontend/lib/features/kindergarten_dashboard/theme.dart`):

| Token | Hex | Mô tả |
|---|---|---|
| `brand` | `#16665A` | Primary teal |
| `brandStrong` | `#114F46` | Brand đậm |
| `canvas` | `#F6F4EF` | Background warm beige |
| `surface` | `#FFFFFF` | Card |
| `sunken` | `#EFECE5` | Vùng chìm |
| `ink` | `#2A2926` | Text chính |
| `ink-soft` | `#605D57` | Text phụ |
| `ink-faint` | `#757169` | Text mờ |
| `line` | `#E7E3DA` | Border |
| `ok` | `#3F8B5C` | Success |
| `warn` | `#B0791B` | Warning |
| `bad` | `#BB4A34` | Danger |
| `info` | `#4B6F8C` | Info |

## API backend (đã có sẵn)

- `POST /api/school-admin/login` — School admin (role=admin) đăng nhập.
- `POST /api/admin-auth/login` — Web admin (admin_user table) đăng nhập.
- `POST /api/auth/login` — Login dùng chung (cũ, vẫn hoạt động).
- `GET/POST/PUT/DELETE /api/admin/{teachers,parents,children,classes,schedules,time-slots}` — CRUD school admin.
- `GET /api/admin/dashboard/{stats,classes-progress,report-trends}` — Dashboard data.
- `GET /api/bug-reports/...` — Bug reports (Web Admin).

Xem thêm chi tiết tại `backend/app/api/endpoints/`.

## Tài khoản test

| Loại | Username/Email | Mật khẩu |
|---|---|---|
| Admin trường | (username trong `users` table, role=admin) | (password bạn đã tạo) |
| Web Admin | (email trong `admin_user` table) | (password bạn đã tạo) |