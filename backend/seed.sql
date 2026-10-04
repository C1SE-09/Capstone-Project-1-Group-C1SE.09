SET client_encoding = 'UTF8';

-- Seed data cho KinderLog Test Environment
-- HƯỚNG DẪN NẠP DATA KHÔNG BỊ LỖI FONT TIẾNG VIỆT:
-- 
-- 1. Chạy Alembic migrations trước:
--    docker compose exec api alembic upgrade head
--
-- 2. Nạp dữ liệu seed vào PostgreSQL:
--    Cách 1 (Khuyên dùng - Hoạt động chuẩn trên mọi OS / Windows PowerShell / CMD):
--      docker compose cp backend/seed.sql db:/tmp/seed.sql
--      docker compose exec db psql -U kinderlog -d kinderlog -f /tmp/seed.sql
--
--    Cách 2 (Dành cho Windows PowerShell nếu dùng pipeline `|`):
--      $OutputEncoding = [System.Text.Encoding]::UTF8; Get-Content -Raw -Encoding UTF8 backend/seed.sql | docker compose exec -T db psql -U kinderlog -d kinderlog
--
--    Cách 3 (Dành cho Linux / macOS / Bash):
--      docker compose exec -T db psql -U kinderlog -d kinderlog < backend/seed.sql

-- 1. Thêm Trường học mẫu (School)
INSERT INTO school (
    school_id, 
    name, 
    code, 
    address, 
    phone, 
    email, 
    status, 
    created_at, 
    updated_at
) VALUES (
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Trường Mầm Non Họa Mi',
    'KG-HCM-01',
    '123 Nguyễn Văn Cừ, Quận 5, TP.HCM',
    '0901234567',
    'hoami@kindergarten.edu.vn',
    'ACTIVE',
    NOW(),
    NOW()
) ON CONFLICT (school_id) DO UPDATE SET
    name = EXCLUDED.name,
    code = EXCLUDED.code,
    address = EXCLUDED.address,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    status = EXCLUDED.status,
    updated_at = NOW();

-- 2. Thêm Lớp học mẫu (Class)
-- Lớp 1: Lớp Mầm A
INSERT INTO class (
    class_id, 
    school_id, 
    name, 
    grade_label, 
    room_number, 
    capacity, 
    is_active, 
    created_at, 
    updated_at
) VALUES (
    'aaaaaaaa-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Lớp Mầm A',
    'Mầm',
    'Room 101',
    25,
    true,
    NOW(),
    NOW()
) ON CONFLICT (class_id) DO UPDATE SET
    school_id = EXCLUDED.school_id,
    name = EXCLUDED.name,
    grade_label = EXCLUDED.grade_label,
    room_number = EXCLUDED.room_number,
    capacity = EXCLUDED.capacity,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Lớp 2: Lớp Mầm B
INSERT INTO class (
    class_id, 
    school_id, 
    name, 
    grade_label, 
    room_number, 
    capacity, 
    is_active, 
    created_at, 
    updated_at
) VALUES (
    'aaaaaaaa-0000-0000-0000-000000000002',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Lớp Mầm B',
    'Mầm',
    'Room 102',
    25,
    true,
    NOW(),
    NOW()
) ON CONFLICT (class_id) DO UPDATE SET
    school_id = EXCLUDED.school_id,
    name = EXCLUDED.name,
    grade_label = EXCLUDED.grade_label,
    room_number = EXCLUDED.room_number,
    capacity = EXCLUDED.capacity,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- 3. Thêm Giáo viên mẫu (Teacher)
-- Giáo viên chủ nhiệm Lớp Mầm A
INSERT INTO teacher (
    teacher_id, 
    school_id, 
    class_id, 
    full_name, 
    email, 
    phone, 
    status, 
    is_verified, 
    created_at, 
    updated_at
) VALUES (
    'bbbbbbbb-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Cô Nguyễn Thị Mai',
    'teacher.mai@hoami.edu.vn',
    '0987654321',
    'ACTIVE',
    true,
    NOW(),
    NOW()
) ON CONFLICT (teacher_id) DO UPDATE SET
    school_id = EXCLUDED.school_id,
    class_id = EXCLUDED.class_id,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    status = EXCLUDED.status,
    is_verified = EXCLUDED.is_verified,
    updated_at = NOW();

-- Giáo viên chủ nhiệm Lớp Mầm B
INSERT INTO teacher (
    teacher_id, 
    school_id, 
    class_id, 
    full_name, 
    email, 
    phone, 
    status, 
    is_verified, 
    created_at, 
    updated_at
) VALUES (
    'bbbbbbbb-0000-0000-0000-000000000002',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'Cô Trần Thị Lan',
    'teacher.lan@hoami.edu.vn',
    '0987654322',
    'ACTIVE',
    true,
    NOW(),
    NOW()
) ON CONFLICT (teacher_id) DO UPDATE SET
    school_id = EXCLUDED.school_id,
    class_id = EXCLUDED.class_id,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    status = EXCLUDED.status,
    is_verified = EXCLUDED.is_verified,
    updated_at = NOW();

-- 4. Thêm Phụ huynh mẫu (Parent) - 10 phụ huynh cho 10 trẻ
INSERT INTO parent (
    parent_id,
    full_name,
    phone,
    email,
    status,
    is_verified,
    created_at,
    updated_at
) VALUES 
-- Phụ huynh của trẻ Lớp Mầm A
(
    'cccccccc-0000-0000-0000-000000000001',
    'Trần Văn Tuấn',
    '0912000001',
    'parent.tuan@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000002',
    'Lê Hoàng Nam',
    '0912000002',
    'parent.nam@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000003',
    'Phạm Quốc Hùng',
    '0912000003',
    'parent.hung@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000004',
    'Đặng Thanh Thảo',
    '0912000004',
    'parent.thao@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000005',
    'Đỗ Văn Thành',
    '0912000005',
    'parent.thanh@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
-- Phụ huynh của trẻ Lớp Mầm B
(
    'cccccccc-0000-0000-0000-000000000006',
    'Nguyễn Quang Dũng',
    '0912000006',
    'parent.dung@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000007',
    'Hoàng Nhật Minh',
    '0912000007',
    'parent.minh@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000008',
    'Bùi Đức Trọng',
    '0912000008',
    'parent.trong@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000009',
    'Dương Đình Tuấn',
    '0912000009',
    'parent.tuan.d@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
),
(
    'cccccccc-0000-0000-0000-000000000010',
    'Ngô Bá Khang',
    '0912000010',
    'parent.khang@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (parent_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    status = EXCLUDED.status,
    is_verified = EXCLUDED.is_verified,
    updated_at = NOW();

-- 4.5. Thêm Tài khoản Đăng nhập (Users)
-- Tất cả mật khẩu mặc định: 123456 (hashed với bcrypt: $2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW)
INSERT INTO users (
    user_id,
    username,
    password_hash,
    role,
    teacher_id,
    parent_id,
    status,
    is_verified,
    created_at,
    updated_at
) VALUES
-- Tài khoản Giáo viên
(
    '11111111-0000-0000-0000-000000000001',
    'comai',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'teacher',
    'bbbbbbbb-0000-0000-0000-000000000001',
    NULL,
    'active',
    true,
    NOW(),
    NOW()
),
(
    '11111111-0000-0000-0000-000000000002',
    'colan',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'teacher',
    'bbbbbbbb-0000-0000-0000-000000000002',
    NULL,
    'active',
    true,
    NOW(),
    NOW()
),
-- Tài khoản Phụ huynh
(
    '22222222-0000-0000-0000-000000000001',
    'tuan',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000001',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000002',
    'nam',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000002',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000003',
    'hung',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000003',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000004',
    'thao',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000004',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000005',
    'thanh',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000005',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000006',
    'dung',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000006',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000007',
    'minh',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000007',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000008',
    'trong',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000008',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000009',
    'tuand',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000009',
    'active',
    true,
    NOW(),
    NOW()
),
(
    '22222222-0000-0000-0000-000000000010',
    'khang',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
    'parent',
    NULL,
    'cccccccc-0000-0000-0000-000000000010',
    'active',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    teacher_id = EXCLUDED.teacher_id,
    parent_id = EXCLUDED.parent_id,
    status = EXCLUDED.status,
    is_verified = EXCLUDED.is_verified,
    updated_at = NOW();

-- 5. Thêm Trẻ mẫu (Child) - 5 trẻ cho mỗi lớp
INSERT INTO child (
    child_id,
    parent_id,
    class_id,
    full_name,
    nickname,
    date_of_birth,
    gender,
    medical_allergies,
    status,
    created_at,
    updated_at
) VALUES 
-- 5 Trẻ thuộc Lớp Mầm A
(
    'dddddddd-0000-0000-0000-000000000001',
    'cccccccc-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Trần Gia Bảo',
    'Bảo Bảo',
    '2021-03-15',
    'male',
    'Không có',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000002',
    'cccccccc-0000-0000-0000-000000000002',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Lê Ngọc Ánh',
    'Bống',
    '2021-05-20',
    'female',
    'Dị ứng đậu phộng',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000003',
    'cccccccc-0000-0000-0000-000000000003',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Phạm Minh Khang',
    'Khang Khang',
    '2021-07-10',
    'male',
    'Dị ứng tôm cua, hải sản',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000004',
    'cccccccc-0000-0000-0000-000000000004',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Vũ Thùy Chi',
    'Bé Thỏ',
    '2021-09-12',
    'female',
    'Không có',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000005',
    'cccccccc-0000-0000-0000-000000000005',
    'aaaaaaaa-0000-0000-0000-000000000001',
    'Đỗ Đức Anh',
    'Mít',
    '2021-11-05',
    'male',
    'Viêm mũi dị ứng thời tiết',
    'ENROLLED',
    NOW(),
    NOW()
),
-- 5 Trẻ thuộc Lớp Mầm B
(
    'dddddddd-0000-0000-0000-000000000006',
    'cccccccc-0000-0000-0000-000000000006',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'Nguyễn Gia Huy',
    'Bơ',
    '2021-02-18',
    'male',
    'Không có',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000007',
    'cccccccc-0000-0000-0000-000000000007',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'Hoàng Bảo Ngọc',
    'Bông',
    '2021-04-22',
    'female',
    'Dị ứng phấn hoa',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000008',
    'cccccccc-0000-0000-0000-000000000008',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'Bùi Khánh Linh',
    'Sushi',
    '2021-06-30',
    'female',
    'Không dung nạp lactose',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000009',
    'cccccccc-0000-0000-0000-000000000009',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'Dương Tuấn Kiệt',
    'Sóc',
    '2021-08-14',
    'male',
    'Không có',
    'ENROLLED',
    NOW(),
    NOW()
),
(
    'dddddddd-0000-0000-0000-000000000010',
    'cccccccc-0000-0000-0000-000000000010',
    'aaaaaaaa-0000-0000-0000-000000000002',
    'Ngô Phương Thảo',
    'Bé Na',
    '2021-10-25',
    'female',
    'Không có',
    'ENROLLED',
    NOW(),
    NOW()
)
ON CONFLICT (child_id) DO UPDATE SET
    parent_id = EXCLUDED.parent_id,
    class_id = EXCLUDED.class_id,
    full_name = EXCLUDED.full_name,
    nickname = EXCLUDED.nickname,
    date_of_birth = EXCLUDED.date_of_birth,
    gender = EXCLUDED.gender,
    medical_allergies = EXCLUDED.medical_allergies,
    status = EXCLUDED.status,
    updated_at = NOW();

-- ===========================================================================
-- 6. Thêm Khung tiết học mẫu (TimeSlot)
-- ===========================================================================
INSERT INTO time_slot (
    slot_id, school_id, name, start_time, end_time, order_index, created_at, updated_at
) VALUES
('e0000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '7h00 - 7h30', '07:00', '07:30', 1, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '7h30 - 8h00', '07:30', '08:00', 2, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', '8h10 - 8h40', '08:10', '08:40', 3, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', '8h40 - 9h00', '08:40', '09:00', 4, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', '9h00 - 9h45', '09:00', '09:45', 5, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', '9h45 - 10h30', '09:45', '10:30', 6, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', '10h30 - 10h45', '10:30', '10:45', 7, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', '10h45 - 11h30', '10:45', '11:30', 8, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', '11h30 - 12h00', '11:30', '12:00', 9, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', '12h00 - 14h00', '12:00', '14:00', 10, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', '14h00 - 14h30', '14:00', '14:30', 11, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', '14h30 - 15h00', '14:30', '15:00', 12, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000013', 'aaaaaaaa-0000-0000-0000-000000000001', '15h00 - 16h00', '15:00', '16:00', 13, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000014', 'aaaaaaaa-0000-0000-0000-000000000001', '16h00 - 17h00', '16:00', '17:00', 14, NOW(), NOW())
ON CONFLICT (slot_id) DO UPDATE SET
    name = EXCLUDED.name, start_time = EXCLUDED.start_time, end_time = EXCLUDED.end_time, order_index = EXCLUDED.order_index, updated_at = NOW();

-- ===========================================================================
-- 7. Thêm Môn học / Hoạt động mẫu (Subject) - Đổi Tiếng Anh thành Tiếng Việt
-- ===========================================================================
INSERT INTO subject (
    subject_id, school_id, name, code, color_code, description, created_at, updated_at
) VALUES
('f0000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Đón & Trả trẻ', 'REC', '#FF9800', 'Đón trẻ, quản chơi tự do, trao đổi phụ huynh', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Thể dục & Vận động', 'PHY', '#4CAF50', 'Thể dục buổi sáng, vận động thể chất', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Ăn uống', 'MEAL', '#FF5722', 'Ăn sáng, ăn giữa giờ, ăn trưa, ăn xế', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'Tiếng Việt', 'VIE', '#2196F3', 'Rèn luyện kỹ năng ngôn ngữ Tiếng Việt, làm quen chữ cái và kể chuyện', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'Mỹ thuật & Tạo hình', 'ART', '#E91E63', 'Vẽ tranh, nặn đất màu, dán giấy', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'Âm nhạc & Vận động', 'MUS', '#9C27B0', 'Hát, nghe nhạc, vận động theo nhạc', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'Vui chơi & Ngoài trời', 'PLAY', '#00BCD4', 'Hoạt động vui chơi góc, vận động ngoài trời, quan sát tự nhiên', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'Vệ sinh & Ngủ trưa', 'SLEEP', '#607D8B', 'Vệ sinh cá nhân, rửa tay, ngủ trưa', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'Kỹ năng sống', 'SKI', '#8BC34A', 'Rèn luyện kỹ năng tự phục vụ, giao tiếp lễ phép', NOW(), NOW())
ON CONFLICT (subject_id) DO UPDATE SET
    name = EXCLUDED.name, code = EXCLUDED.code, color_code = EXCLUDED.color_code, description = EXCLUDED.description, updated_at = NOW();

-- ===========================================================================
-- 8. Thêm Thời khóa biểu chi tiết (ClassSchedule) - Lớp Mầm A (Thứ 2 đến Thứ 6)
-- ===========================================================================
INSERT INTO class_schedule (
    schedule_id, class_id, subject_id, slot_id, teacher_id, day_of_week, activity_name, content, room_name, is_active, created_at, updated_at
) VALUES
-- --- THỨ 2 (Day 2) ---
('fa000000-0000-0000-0002-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 2, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường / Phòng ăn', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động có chủ đích', '- Giáo viên tổ chức giờ học rèn luyện kỹ năng Tiếng Việt cho trẻ theo kế hoạch chương trình giáo dục độ tuổi', 'Phòng Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 2, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Góc đồ chơi', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Chuẩn bị ăn trưa', '- Trẻ đi vệ sinh, rửa tay, lau mặt', 'Nhà vệ sinh', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Ăn trưa', '- Trẻ ăn cơm trưa', 'Phòng ăn', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Chuẩn bị ngủ trưa', '- Trẻ đánh răng, vệ sinh, thay đồ chuẩn bị ngủ trưa', 'Phòng ngủ', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Ngủ trưa', '- Trẻ ngủ trưa', 'Phòng ngủ', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Ăn xế', '- Trẻ ăn xế.- Vệ sinh sau giờ ăn xế', 'Phòng ăn', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000013', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000013', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu- Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000014', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000014', 'bbbbbbbb-0000-0000-0000-000000000001', 2, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng Mầm A', true, NOW(), NOW()),

-- --- THỨ 3 (Day 3: Môn Mỹ thuật) ---
('fa000000-0000-0000-0003-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Hoạt động có chủ đích (Mỹ thuật)', '- Giáo viên tổ chức giờ học vẽ tranh nét đơn giản và nặn đất màu', 'Phòng Mỹ thuật', true, NOW(), NOW()),

-- --- THỨ 4 (Day 4: Môn Âm nhạc) ---
('fa000000-0000-0000-0004-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Hoạt động có chủ đích (Âm nhạc)', '- Giáo viên tổ chức giờ học hát và vận động nhịp điệu', 'Phòng Âm nhạc', true, NOW(), NOW()),

-- --- THỨ 5 (Day 5: Môn Kỹ năng sống) ---
('fa000000-0000-0000-0005-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Hoạt động có chủ đích (Kỹ năng)', '- Rèn luyện kỹ năng rửa tay đúng cách và xếp hàng trật tự', 'Phòng Mầm A', true, NOW(), NOW()),

-- --- THỨ 6 (Day 6: Môn Tiếng Việt) ---
('fa000000-0000-0000-0006-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Hoạt động có chủ đích (Tiếng Việt)', '- Giáo viên tổ chức đọc truyện cổ tích Tiếng Việt và kể chuyện theo tranh', 'Phòng Mầm A', true, NOW(), NOW())
ON CONFLICT (schedule_id) DO UPDATE SET
    class_id = EXCLUDED.class_id, subject_id = EXCLUDED.subject_id, slot_id = EXCLUDED.slot_id, teacher_id = EXCLUDED.teacher_id, day_of_week = EXCLUDED.day_of_week, activity_name = EXCLUDED.activity_name, content = EXCLUDED.content, room_name = EXCLUDED.room_name, is_active = EXCLUDED.is_active, updated_at = NOW();