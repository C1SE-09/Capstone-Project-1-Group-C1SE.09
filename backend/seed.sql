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
    'shimarin395@gmail.com',
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
    relationship,
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
    'Bố',
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
    'Bố',
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
    'Bố',
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
    'Mẹ',
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
    'Bố',
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
    'Bố',
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
    'Bố',
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
    'Bố',
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
    'Bố',
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
    'Bố',
    'ACTIVE',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (parent_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    relationship = EXCLUDED.relationship,
    status = EXCLUDED.status,
    is_verified = EXCLUDED.is_verified,
    updated_at = NOW();

-- 4.5. Thêm Tài khoản Đăng nhập (Users)
-- Tất cả mật khẩu mặc định: 123456 (hashed với bcrypt: $2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW)
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
-- Tài khoản Quản trị viên (Admin)
(
    '99999999-0000-0000-0000-000000000001',
    'admin',
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
    'admin',
    NULL,
    NULL,
    'active',
    true,
    NOW(),
    NOW()
),
-- Tài khoản Giáo viên
(
    '11111111-0000-0000-0000-000000000001',
    'comai',
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
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

-- 5.1. Thêm liên kết Phụ huynh - Học sinh (ParentChild)
INSERT INTO parent_child (
    id,
    parent_id,
    child_id,
    relationship,
    is_primary,
    can_pickup,
    created_at,
    updated_at
) VALUES 
(
    'eeeeeeee-0000-0000-0000-000000000001',
    'cccccccc-0000-0000-0000-000000000001',
    'dddddddd-0000-0000-0000-000000000001',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000002',
    'cccccccc-0000-0000-0000-000000000002',
    'dddddddd-0000-0000-0000-000000000002',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000003',
    'cccccccc-0000-0000-0000-000000000003',
    'dddddddd-0000-0000-0000-000000000003',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000004',
    'cccccccc-0000-0000-0000-000000000004',
    'dddddddd-0000-0000-0000-000000000004',
    'Mẹ',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000005',
    'cccccccc-0000-0000-0000-000000000005',
    'dddddddd-0000-0000-0000-000000000005',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000006',
    'cccccccc-0000-0000-0000-000000000006',
    'dddddddd-0000-0000-0000-000000000006',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000007',
    'cccccccc-0000-0000-0000-000000000007',
    'dddddddd-0000-0000-0000-000000000007',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000008',
    'cccccccc-0000-0000-0000-000000000008',
    'dddddddd-0000-0000-0000-000000000008',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000009',
    'cccccccc-0000-0000-0000-000000000009',
    'dddddddd-0000-0000-0000-000000000009',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
),
(
    'eeeeeeee-0000-0000-0000-000000000010',
    'cccccccc-0000-0000-0000-000000000010',
    'dddddddd-0000-0000-0000-000000000010',
    'Bố',
    true,
    true,
    NOW(),
    NOW()
)
ON CONFLICT (parent_id, child_id) DO NOTHING;

-- ===========================================================================
-- 6. Thêm Khung tiết học mẫu (TimeSlot)
-- ===========================================================================
DELETE FROM class_schedule WHERE slot_id IN ('e0000000-0000-0000-0000-000000000013', 'e0000000-0000-0000-0000-000000000014');
DELETE FROM time_slot WHERE slot_id IN ('e0000000-0000-0000-0000-000000000013', 'e0000000-0000-0000-0000-000000000014');

INSERT INTO time_slot (
    slot_id, name, start_time, end_time, order_index, created_at, updated_at
) VALUES
('e0000000-0000-0000-0000-000000000001', '7h00 - 7h30', '07:00', '07:30', 1, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000002', '7h30 - 8h00', '07:30', '08:00', 2, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000003', '8h10 - 8h40', '08:10', '08:40', 3, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000004', '8h40 - 9h00', '08:40', '09:00', 4, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000005', '9h00 - 9h45', '09:00', '09:45', 5, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000006', '9h45 - 10h30', '09:45', '10:30', 6, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000007', '10h30 - 11h30', '10:30', '11:30', 7, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000008', '11h30 - 14h00', '11:30', '14:00', 8, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000009', '14h00 - 14h30', '14:00', '14:30', 9, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000010', '14h30 - 15h00', '14:30', '15:00', 10, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000011', '15h00 - 16h00', '15:00', '16:00', 11, NOW(), NOW()),
('e0000000-0000-0000-0000-000000000012', '16h00 - 17h00', '16:00', '17:00', 12, NOW(), NOW())
ON CONFLICT (slot_id) DO UPDATE SET
    name = EXCLUDED.name, start_time = EXCLUDED.start_time, end_time = EXCLUDED.end_time, order_index = EXCLUDED.order_index, updated_at = NOW();

-- ===========================================================================
-- 7. Thêm Môn học / Hoạt động mẫu (Subject) - Đổi Tiếng Anh thành Tiếng Việt
-- ===========================================================================
INSERT INTO subject (
    subject_id, name, code, color_code, description, created_at, updated_at
) VALUES
('f0000000-0000-0000-0000-000000000001', 'Đón & Trả trẻ', 'REC', '#FF9800', 'Đón trẻ, quản chơi tự do, trao đổi phụ huynh', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000002', 'Thể dục & Vận động', 'PHY', '#4CAF50', 'Thể dục buổi sáng, vận động thể chất', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000003', 'Ăn uống', 'MEAL', '#FF5722', 'Ăn sáng, ăn giữa giờ, ăn trưa, ăn xế', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000004', 'Tiếng Việt', 'VIE', '#2196F3', 'Rèn luyện kỹ năng ngôn ngữ Tiếng Việt, làm quen chữ cái và kể chuyện', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000005', 'Mỹ thuật & Tạo hình', 'ART', '#E91E63', 'Vẽ tranh, nặn đất màu, dán giấy', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000006', 'Âm nhạc & Vận động', 'MUS', '#9C27B0', 'Hát, nghe nhạc, vận động theo nhạc', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000007', 'Vui chơi & Ngoài trời', 'PLAY', '#00BCD4', 'Hoạt động vui chơi góc, vận động ngoài trời, quan sát tự nhiên', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000008', 'Vệ sinh & Ngủ trưa', 'SLEEP', '#607D8B', 'Vệ sinh cá nhân, rửa tay, ngủ trưa', NOW(), NOW()),
('f0000000-0000-0000-0000-000000000009', 'Kỹ năng sống', 'SKI', '#8BC34A', 'Rèn luyện kỹ năng tự phục vụ, giao tiếp lễ phép', NOW(), NOW())
ON CONFLICT (subject_id) DO UPDATE SET
    name = EXCLUDED.name, code = EXCLUDED.code, color_code = EXCLUDED.color_code, description = EXCLUDED.description, updated_at = NOW();

-- ===========================================================================
-- 7.5. Thêm Danh sách Địa điểm / Phòng học mẫu (Room)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS room (
    room_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES school(school_id) ON DELETE CASCADE,
    class_id UUID REFERENCES class(class_id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    room_type VARCHAR(50) NOT NULL DEFAULT 'CLASSROOM',
    capacity INT DEFAULT 30,
    is_shared BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_room_school_id ON room(school_id);
CREATE INDEX IF NOT EXISTS ix_room_class_id ON room(class_id);
CREATE INDEX IF NOT EXISTS ix_room_type ON room(room_type);

INSERT INTO room (
    room_id, school_id, class_id, name, room_type, capacity, is_shared, is_active, created_at, updated_at
) VALUES
-- 1. Phòng học riêng của lớp (Dedicated classrooms)
('10000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Phòng học Mầm A', 'CLASSROOM', 25, false, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'Phòng học Mầm B', 'CLASSROOM', 25, false, true, NOW(), NOW()),

-- 2. Phòng chức năng chuyên biệt (Functional rooms - 1 lớp/ca)
('10000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Phòng Mỹ thuật & Tạo hình', 'FUNCTIONAL', 30, false, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Phòng Âm nhạc & Vận động', 'FUNCTIONAL', 30, false, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Phòng Thể chất & Đa năng', 'FUNCTIONAL', 35, false, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Phòng Tin học / Đa phương tiện', 'FUNCTIONAL', 25, false, true, NOW(), NOW()),

-- 3. Khu vực ngoài trời & Sân chơi dùng chung (Outdoor & shared areas - is_shared = true)
('10000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Sân cỏ', 'OUTDOOR', 60, true, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Sân trường', 'OUTDOOR', 100, true, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Khu vui chơi cát nước', 'OUTDOOR', 40, true, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Vườn cổ tích & Khám phá', 'OUTDOOR', 40, true, true, NOW(), NOW()),

-- 4. Khu vực sinh hoạt chung (Common areas)
('10000000-0000-0000-0000-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Nhà ăn & Bếp bán trú', 'COMMON', 80, true, true, NOW(), NOW()),
('10000000-0000-0000-0000-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Phòng y tế', 'COMMON', 10, true, true, NOW(), NOW())
ON CONFLICT (room_id) DO UPDATE SET
    school_id = EXCLUDED.school_id, class_id = EXCLUDED.class_id, name = EXCLUDED.name,
    room_type = EXCLUDED.room_type, capacity = EXCLUDED.capacity, is_shared = EXCLUDED.is_shared,
    is_active = EXCLUDED.is_active, updated_at = NOW();

-- ===========================================================================
-- 8. Thêm Thời khóa biểu chi tiết (ClassSchedule) - Lớp Mầm A (Thứ 2 đến Thứ 6)
-- ===========================================================================
DELETE FROM class_schedule WHERE class_id = 'aaaaaaaa-0000-0000-0000-000000000001';

INSERT INTO class_schedule (
    schedule_id, class_id, subject_id, slot_id, teacher_id, day_of_week, activity_name, content, room_name, is_active, created_at, updated_at
) VALUES
-- --- THỨ 2 (Day 2) ---
('fa000000-0000-0000-0002-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 2, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động có chủ đích', '- Giáo viên tổ chức giờ học rèn luyện kỹ năng Tiếng Việt cho trẻ theo kế hoạch chương trình giáo dục độ tuổi', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 2, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000001', 2, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0002-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000001', 2, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm A', true, NOW(), NOW()),

-- --- THỨ 3 (Day 3) ---
('fa000000-0000-0000-0003-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 3, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Hoạt động có chủ đích (Mỹ thuật)', '- Giáo viên tổ chức giờ học vẽ tranh nét đơn giản và nặn đất màu', 'Phòng Mỹ thuật & Tạo hình', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 3, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000001', 3, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0003-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000001', 3, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm A', true, NOW(), NOW()),

-- --- THỨ 4 (Day 4) ---
('fa000000-0000-0000-0004-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 4, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Hoạt động có chủ đích (Âm nhạc)', '- Giáo viên tổ chức giờ học hát và vận động nhịp điệu', 'Phòng Âm nhạc & Vận động', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 4, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000001', 4, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0004-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000001', 4, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm A', true, NOW(), NOW()),

-- --- THỨ 5 (Day 5) ---
('fa000000-0000-0000-0005-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 5, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Hoạt động có chủ đích (Kỹ năng)', '- Rèn luyện kỹ năng rửa tay đúng cách và xếp hàng trật tự', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 5, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000001', 5, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0005-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000001', 5, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm A', true, NOW(), NOW()),

-- --- THỨ 6 (Day 6) ---
('fa000000-0000-0000-0006-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 6, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Hoạt động có chủ đích (Tiếng Việt)', '- Giáo viên tổ chức đọc truyện cổ tích Tiếng Việt và kể chuyện theo tranh', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 6, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000006', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000007', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000008', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm A', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000011', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000001', 6, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fa000000-0000-0000-0006-000000000012', 'aaaaaaaa-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000001', 6, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm A', true, NOW(), NOW())
ON CONFLICT (schedule_id) DO UPDATE SET
    class_id = EXCLUDED.class_id, subject_id = EXCLUDED.subject_id, slot_id = EXCLUDED.slot_id, teacher_id = EXCLUDED.teacher_id, day_of_week = EXCLUDED.day_of_week, activity_name = EXCLUDED.activity_name, content = EXCLUDED.content, room_name = EXCLUDED.room_name, is_active = EXCLUDED.is_active, updated_at = NOW();

-- 8b. Thêm Thời khóa biểu chi tiết (ClassSchedule) - Lớp Mầm B (Thứ 2 đến Thứ 6)
-- ===========================================================================
DELETE FROM class_schedule WHERE class_id = 'aaaaaaaa-0000-0000-0000-000000000002';

INSERT INTO class_schedule (
    schedule_id, class_id, subject_id, slot_id, teacher_id, day_of_week, activity_name, content, room_name, is_active, created_at, updated_at
) VALUES
-- --- THỨ 2 (Day 2) ---
('fb000000-0000-0000-0002-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Hoạt động có chủ đích (Kỹ năng)', '- Rèn luyện kỹ năng chào hỏi, cất dép và đồ dùng ngăn nắp', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000008', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000010', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000011', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000002', 2, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0002-000000000012', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm B', true, NOW(), NOW()),

-- --- THỨ 3 (Day 3) ---
('fb000000-0000-0000-0003-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 3, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Hoạt động có chủ đích (Tiếng Việt)', '- Rèn luyện kỹ năng nghe nói Tiếng Việt và làm quen các sự vật xung quanh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 3, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000008', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000010', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000011', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000002', 3, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0003-000000000012', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000002', 3, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm B', true, NOW(), NOW()),

-- --- THỨ 4 (Day 4) ---
('fb000000-0000-0000-0004-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 4, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Hoạt động có chủ đích (Mỹ thuật)', '- Giáo viên tổ chức giờ học vẽ tranh và tạo hình thủ công', 'Phòng Mỹ thuật & Tạo hình', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 4, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000008', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000010', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000011', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000002', 4, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0004-000000000012', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000002', 4, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm B', true, NOW(), NOW()),

-- --- THỨ 5 (Day 5) ---
('fb000000-0000-0000-0005-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 5, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Hoạt động có chủ đích (Âm nhạc)', '- Giáo viên tổ chức giờ học hát và làm quen các nhạc cụ gõ', 'Phòng Âm nhạc & Vận động', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 5, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000008', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000010', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000011', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000002', 5, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0005-000000000012', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000002', 5, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm B', true, NOW(), NOW()),

-- --- THỨ 6 (Day 6) ---
('fb000000-0000-0000-0006-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Đón trẻ', 'Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những thông tin cần thiết', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 6, 'Tập thể dục - Ăn sáng', '7h30 Thể dục buổi sáng. 7h40 Ăn sáng', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Hoạt động có chủ đích (Tiếng Việt)', '- Giáo viên tổ chức đọc truyện cổ tích Tiếng Việt và kể chuyện theo tranh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 6, 'Ăn giữa giờ - Vệ sinh', 'Trẻ uống nước trái cây hoặc ăn nhẹ giữa giờ. Trẻ đi vệ sinh', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Hoạt động vui chơi', '- Giáo viên tổ chức cho trẻ hoạt động vui chơi theo kế hoạch', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000006', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000006', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Hoạt động ngoài trời', 'Vận động phát triển thể chất, trò chơi dân gian. Quan sát các hiện tượng tự nhiên và thiên nhiên', 'Sân cỏ', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000007', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Ăn trưa', '- Trẻ vệ sinh, rửa tay và ăn cơm trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000008', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Ngủ trưa', '- Trẻ vệ sinh cá nhân, thay đồ và ngủ trưa', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Hoạt động nhẹ', '- Trẻ thức giấc, vận động nhẹ theo nhạc', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000010', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000010', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Ăn xế', '- Trẻ ăn xế. - Vệ sinh sau giờ ăn xế', 'Phòng học Mầm B', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000011', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000011', 'bbbbbbbb-0000-0000-0000-000000000002', 6, '- Sinh hoạt ngoại khóa - Hoạt động vui chơi', '- Trẻ tham gia các hoạt động ngoại khóa, phát triển năng khiếu - Giáo viên tổ chức cho trẻ sinh hoạt vui chơi theo kế hoạch', 'Sân trường', true, NOW(), NOW()),
('fb000000-0000-0000-0006-000000000012', 'aaaaaaaa-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000012', 'bbbbbbbb-0000-0000-0000-000000000002', 6, 'Trả trẻ', '- Cô quản trẻ chơi tự do. Cô trao đổi với phụ huynh những sinh hoạt trong ngày của trẻ tại nhóm lớp', 'Phòng học Mầm B', true, NOW(), NOW())
ON CONFLICT (schedule_id) DO UPDATE SET
    class_id = EXCLUDED.class_id, subject_id = EXCLUDED.subject_id, slot_id = EXCLUDED.slot_id, teacher_id = EXCLUDED.teacher_id, day_of_week = EXCLUDED.day_of_week, activity_name = EXCLUDED.activity_name, content = EXCLUDED.content, room_name = EXCLUDED.room_name, is_active = EXCLUDED.is_active, updated_at = NOW();

-- ===========================================================================
-- 9. Thêm Tài khoản Admin (cho Bug Report B-04)
-- ===========================================================================
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
(
    '99999999-0000-0000-0000-000000000001',
    'admin',
    '$2b$12$TkaOWed2gmZwMOYzn3zHt.cTK7wQjAkvhy0gSDTPovjxZ9A/8k.PW',
    'admin',
    NULL,
    NULL,
    'active',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    is_verified = EXCLUDED.is_verified,
    updated_at = NOW();

-- ===========================================================================
-- 10. Thêm Bug Report mẫu (US-BUG-01 → US-BUG-04) — cho môi trường dev
-- Bao gồm đầy đủ 5 trạng thái: open / in_progress / resolved / closed / wont_fix
-- Mỗi report có 1 history entry initial (created) + các entry khi status thay đổi
-- ===========================================================================

-- 10.1. Bug Report #1: App crash khi mở báo cáo (HIGH, OPEN) — Cô Mai report
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000001',
    '11111111-0000-0000-0000-000000000001',  -- comai (teacher)
    NULL,
    'App crash khi mở báo cáo của bé An',
    'Bước tái hiện: 1) Mở trang Dashboard 2) Bấm vào bé An 3) App thoát ra ngay. Đã thử 3 lần đều crash. Điện thoại Samsung Galaxy A54, Android 14, app v1.2.3 build 42.',
    'crash', 'high', 'open',
    '1.2.3', '42', 'Android 14', 'Samsung SM-A546B', 'wifi',
    NULL, NULL,
    NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    updated_at = NOW();

-- 10.2. Bug Report #2: Notification không gửi (MEDIUM, IN_PROGRESS) — Phụ huynh Tuấn report
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000002',
    '22222222-0000-0000-0000-000000000001',  -- tuan (parent)
    'bbbbbbbb-0000-0000-0000-000000000001',  -- assigned to Cô Mai
    'Không nhận được thông báo khi có báo cáo mới',
    'Tôi đã bật notification trong cài đặt app nhưng không nhận được thông báo nào khi cô giáo gửi báo cáo. Đã thử cả wifi và 4G. Pixel 7, Android 14.',
    'notification', 'medium', 'in_progress',
    '1.2.3', '42', 'Android 14', 'Google Pixel 7', 'cellular',
    NULL, NULL,
    NOW() - INTERVAL '1 day', NOW() - INTERVAL '12 hours'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    teacher_id = EXCLUDED.teacher_id,
    updated_at = NOW();

-- 10.3. Bug Report #3: Giao diện bị lệch trên màn hình nhỏ (LOW, RESOLVED) — Cô Lan report
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000003',
    '11111111-0000-0000-0000-000000000002',  -- colan (teacher)
    'bbbbbbbb-0000-0000-0000-000000000001',  -- assigned to Cô Mai
    'Giao diện bị lệch trên điện thoại màn hình nhỏ',
    'Trên điện thoại nhỏ hơn 5.5 inch, button "Tạo báo cáo" bị che bởi navigation bar. Đã test trên iPhone SE 2 và Samsung A13.',
    'ui', 'low', 'resolved',
    '1.2.2', '40', 'iOS 17.2', 'iPhone SE 2', 'wifi',
    NOW() - INTERVAL '2 hours', NULL,
    NOW() - INTERVAL '5 days', NOW() - INTERVAL '2 hours'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    teacher_id = EXCLUDED.teacher_id,
    resolved_at = EXCLUDED.resolved_at,
    updated_at = NOW();

-- 10.4. Bug Report #4: Upload audio chậm (CRITICAL, CLOSED) — Phụ huynh Nam report
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000004',
    '22222222-0000-0000-0000-000000000002',  -- nam (parent)
    'bbbbbbbb-0000-0000-0000-000000000002',  -- assigned to Cô Lan
    'Upload audio bị timeout sau 30 giây',
    'Mỗi lần upload file audio 3-5 phút, app báo timeout dù wifi rất ổn định. Phải upload lại 3-4 lần mới được. Đã test trên wifi 100Mbps.',
    'performance', 'critical', 'closed',
    '1.2.0', '38', 'Android 13', 'Xiaomi Redmi Note 11', 'wifi',
    NOW() - INTERVAL '10 days', NOW() - INTERVAL '8 days',
    NOW() - INTERVAL '15 days', NOW() - INTERVAL '8 days'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    teacher_id = EXCLUDED.teacher_id,
    resolved_at = EXCLUDED.resolved_at,
    closed_at = EXCLUDED.closed_at,
    updated_at = NOW();

-- 10.5. Bug Report #5: Đề xuất thêm Dark mode (OTHER, WONT_FIX) — Phụ huynh Hùng report
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000005',
    '22222222-0000-0000-0000-000000000003',  -- hung (parent)
    NULL,
    'Đề xuất: Thêm chế độ Dark mode',
    'App hiện tại chỉ có light mode, mong muốn team thêm dark mode để bảo vệ mắt khi dùng ban đêm. Cảm ơn team!',
    'other', 'low', 'wont_fix',
    NULL, NULL, NULL, NULL, NULL,
    NULL, NULL,
    NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    updated_at = NOW();

-- ===========================================================================
-- 11. Bug Report History (audit trail) — ghi log cho từng status change
-- Mỗi report có 1 entry "created" + các entry khi admin đổi status
-- ===========================================================================

-- Report #1: chỉ có 1 entry created (status=open, hiện tại vẫn OPEN)
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '11111111-0000-0000-0000-000000000001',  -- Cô Mai tạo
    NULL, 'open', NULL, NULL,
    'Report created by teacher',
    NOW() - INTERVAL '2 hours'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #2: created → in_progress (admin assign + đổi status)
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    '22222222-0000-0000-0000-000000000001',  -- Phụ huynh Tuấn tạo
    NULL, 'open', NULL, NULL,
    'Report created by parent',
    NOW() - INTERVAL '1 day'
),
(
    'a0000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'open', 'in_progress', NULL, 'bbbbbbbb-0000-0000-0000-000000000001',
    'Đã assign cho Cô Mai xử lý FCM token. Đang kiểm tra log.',
    NOW() - INTERVAL '12 hours'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #3: created → in_progress → resolved (full lifecycle)
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000003',
    '11111111-0000-0000-0000-000000000002',  -- Cô Lan tạo
    NULL, 'open', NULL, NULL,
    'Report created by teacher',
    NOW() - INTERVAL '5 days'
),
(
    'a0000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000003',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'open', 'in_progress', NULL, 'bbbbbbbb-0000-0000-0000-000000000001',
    'Đang fix responsive layout cho mobile nhỏ.',
    NOW() - INTERVAL '3 days'
),
(
    'a0000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000003',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'in_progress', 'resolved', 'bbbbbbbb-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
    'Đã fix bằng cách thêm SafeArea + MediaQuery padding. Build mới 1.2.3 đã deploy lên TestFlight.',
    NOW() - INTERVAL '2 hours'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #4: created → in_progress → resolved → closed
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000004',
    '22222222-0000-0000-0000-000000000002',  -- Phụ huynh Nam tạo
    NULL, 'open', NULL, NULL,
    'Report created by parent',
    NOW() - INTERVAL '15 days'
),
(
    'a0000000-0000-0000-0000-000000000008',
    '10000000-0000-0000-0000-000000000004',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'open', 'in_progress', NULL, 'bbbbbbbb-0000-0000-0000-000000000002',
    'Cô Lan đang investigate timeout issue.',
    NOW() - INTERVAL '12 days'
),
(
    'a0000000-0000-0000-0000-000000000009',
    '10000000-0000-0000-0000-000000000004',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'in_progress', 'resolved', 'bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002',
    'Root cause: MinIO chunk size quá nhỏ (5MB). Đã bump lên 15MB. PR #141 merged.',
    NOW() - INTERVAL '10 days'
),
(
    'a0000000-0000-0000-0000-00000000000a',
    '10000000-0000-0000-0000-000000000004',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'resolved', 'closed', 'bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002',
    'Phụ huynh Nam đã xác nhận app upload OK. Đóng ticket.',
    NOW() - INTERVAL '8 days'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #5: created → wont_fix
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-00000000000b',
    '10000000-0000-0000-0000-000000000005',
    '22222222-0000-0000-0000-000000000003',  -- Phụ huynh Hùng tạo
    NULL, 'open', NULL, NULL,
    'Report created by parent',
    NOW() - INTERVAL '7 days'
),
(
    'a0000000-0000-0000-0000-00000000000c',
    '10000000-0000-0000-0000-000000000005',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'open', 'wont_fix', NULL, NULL,
    'Dark mode là feature mới, không phải bug. Sẽ đưa vào backlog Q1/2027.',
    NOW() - INTERVAL '6 days'
)
ON CONFLICT (history_id) DO NOTHING;

-- ===========================================================================
-- 12. EDGE CASES (bổ sung) — 4 report + 5 attachment + 12 history entry
-- Mục đích: test boundary (max length), SLA (stale open), re-assignment,
-- pagination (multi-reports cùng user), enum mới (network/auth),
-- và populate bảng bug_report_attachment trước giờ đang rỗng.
-- ===========================================================================

-- 12.1. Report #6: BOUNDARY TEST — title dài tối đa, description gần 4000 chars,
--       kèm 3 attachment (nhiều MIME khác nhau) → test form validation + UI grid
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000006',
    '11111111-0000-0000-0000-000000000002',  -- colan (teacher)
    NULL,
    -- title 200 ký tự (đúng giới hạn VARCHAR(200))
    'Lỗi giao diện: danh sách trẻ trong lớp bị tràn ra ngoài khung màn hình khi cuộn xuống dưới cùng - đã thử trên nhiều thiết bị Android và iOS khác nhau',
    -- description ~3800 ký tự (gần giới hạn TEXT 4000) — test max length validation
    E'Lỗi mô tả chi tiết:\n\n' ||
    repeat(E'Khi em cuộn danh sách trẻ trong lớp xuống khoảng 20 dòng thì giao diện bắt đầu hiển thị tràn ra ngoài khung màn hình và làm che mất nút "Tạo báo cáo mới" ở phía dưới. Em đã thử trên nhiều thiết bị khác nhau gồm: Samsung Galaxy A54 (Android 14), Google Pixel 7 (Android 14), iPhone 14 Pro (iOS 17.4), iPhone SE 2 (iOS 17.2), iPad Air thế hệ 5 (iPadOS 17) — đều gặp tình trạng tương tự như nhau. Em cũng đã thử xoay ngang màn hình nhưng vẫn bị tràn.\n\nCác bước tái hiện:\n1. Đăng nhập bằng tài khoản giáo viên Cô Lan (colan)\n2. Chọn lớp Mầm B\n3. Bấm vào "Xem danh sách trẻ" trong menu bên trái\n4. Cuộn danh sách xuống khoảng 20 dòng\n5. Quan sát: layout bị tràn, nút bị che\n\nMong team kiểm tra vấn đề này sớm để giáo viên và phụ huynh không bị gián đoạn khi sử dụng. Cảm ơn team rất nhiều!\n\n', 16),
    'ui', 'medium', 'open',
    '1.2.3', '42', 'Android 14', 'Samsung SM-A546B', 'wifi',
    NULL, NULL,
    NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    updated_at = NOW();

-- 12.2. Report #7: STALE OPEN — báo lỗi cũ 35 ngày chưa được xử lý → test SLA badge
--       Dùng enum `network` chưa xuất hiện ở các report trước
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000007',
    '22222222-0000-0000-0000-000000000004',  -- thao (parent)
    NULL,
    'Không tải được danh sách trẻ khi dùng 3G',
    'Khi tôi dùng 3G (mạng di động) để mở danh sách trẻ, app báo lỗi "Không thể kết nối máy chủ" dù trước đó vẫn dùng bình thường. Wifi thì vẫn OK. Mong admin xem xét.',
    'network', 'medium', 'open',
    '1.1.5', '35', 'Android 12', 'Samsung Galaxy A13', 'cellular',
    NULL, NULL,
    NOW() - INTERVAL '35 days', NOW() - INTERVAL '35 days'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    updated_at = NOW();

-- 12.3. Report #8: RE-ASSIGNMENT — test audit trail với teacher được assign 2 lần
--       Dùng enum `auth` chưa xuất hiện + 2 attachment (hóa đơn + screenshot)
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000008',
    '22222222-0000-0000-0000-000000000005',  -- thanh (parent)
    'bbbbbbbb-0000-0000-0000-000000000002',  -- hiện tại: assigned to Cô Lan (sau khi re-assign)
    'Lỗi thanh toán học phí: hệ thống báo sai số tiền',
    'Tôi thanh toán học phí tháng 10 là 2.500.000đ nhưng hệ thống ghi nhận 5.000.000đ (gấp đôi). Tôi đã gửi kèm hóa đơn chuyển khoản ngân hàng và ảnh chụp màn hình lỗi. Mong team xử lý sớm để khỏi ảnh hưởng tới bé.',
    'auth', 'high', 'in_progress',
    '1.2.3', '42', 'Android 14', 'OPPO Reno 8', 'wifi',
    NULL, NULL,
    NOW() - INTERVAL '3 days', NOW() - INTERVAL '6 hours'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    teacher_id = EXCLUDED.teacher_id,
    updated_at = NOW();

-- 12.4. Report #9: 4th report từ cùng user (Cô Mai) → test pagination "my reports"
--       Full lifecycle: open → in_progress → resolved → closed
INSERT INTO bug_report (
    bug_report_id, user_id, teacher_id, title, description,
    category, severity, status,
    app_version, build_number, os_version, device_model, network_type,
    resolved_at, closed_at, created_at, updated_at
) VALUES (
    '10000000-0000-0000-0000-000000000009',
    '11111111-0000-0000-0000-000000000001',  -- comai (teacher) — user này đã có report #1
    'bbbbbbbb-0000-0000-0000-000000000002',  -- assigned to Cô Lan
    'Âm thanh thông báo bị ngắt giữa chừng khi nhận báo cáo mới',
    'Mỗi lần có thông báo báo cáo mới từ phụ huynh, âm thanh chỉ phát được 1-2 giây rồi bị ngắt, dù file âm thanh dài 5 giây. Đã test trên cả chế độ im lặng và chuông.',
    'notification', 'low', 'closed',
    '1.2.1', '39', 'Android 13', 'Xiaomi Redmi Note 11', 'wifi',
    NOW() - INTERVAL '20 days', NOW() - INTERVAL '18 days',
    NOW() - INTERVAL '25 days', NOW() - INTERVAL '18 days'
)
ON CONFLICT (bug_report_id) DO UPDATE SET
    title = EXCLUDED.title, description = EXCLUDED.description,
    category = EXCLUDED.category, severity = EXCLUDED.severity, status = EXCLUDED.status,
    teacher_id = EXCLUDED.teacher_id,
    resolved_at = EXCLUDED.resolved_at,
    closed_at = EXCLUDED.closed_at,
    updated_at = NOW();

-- ===========================================================================
-- 13. Bug Report Attachments (populate bảng đang rỗng) — 5 file
-- Phân bổ: Report #6 (3 ảnh), Report #8 (2 ảnh)
-- MIME mix: image/jpeg, image/png để test ảnh đa định dạng
-- ===========================================================================

-- Report #6: 3 ảnh
INSERT INTO bug_report_attachment (
    attachment_id, bug_report_id, file_url, file_name, file_size, mime_type, description,
    created_at, updated_at
) VALUES
(
    'b0000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000006',
    'https://minio.kinderlog.local/bug-reports/2026/10/12/screenshot-trang-chi-tiet.jpeg',
    'screenshot-trang-chi-tiet.jpeg',
    248531, 'image/jpeg',
    'Ảnh chụp màn hình trang chi tiết lớp khi bị tràn layout',
    NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'
),
(
    'b0000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000006',
    'https://minio.kinderlog.local/bug-reports/2026/10/12/screenshot-ipad-portrait.png',
    'screenshot-ipad-portrait.png',
    412876, 'image/png',
    'Ảnh chụp trên iPad Air xoay dọc - vẫn bị lỗi tương tự',
    NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'
),
(
    'b0000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000006',
    'https://minio.kinderlog.local/bug-reports/2026/10/12/screenshot-iphone-se.jpeg',
    'screenshot-iphone-se.jpeg',
    187432, 'image/jpeg',
    'Ảnh chụp trên iPhone SE 2 (màn hình nhỏ nhất trong bộ test)',
    NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'
)
ON CONFLICT (attachment_id) DO UPDATE SET
    file_url = EXCLUDED.file_url,
    file_name = EXCLUDED.file_name,
    file_size = EXCLUDED.file_size,
    mime_type = EXCLUDED.mime_type,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Report #8: 2 ảnh (hóa đơn + screenshot)
INSERT INTO bug_report_attachment (
    attachment_id, bug_report_id, file_url, file_name, file_size, mime_type, description,
    created_at, updated_at
) VALUES
(
    'b0000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000008',
    'https://minio.kinderlog.local/bug-reports/2026/10/09/hoa-don-ngan-hang.jpeg',
    'hoa-don-chuyen-khoan-thang-10.jpeg',
    356201, 'image/jpeg',
    'Hóa đơn chuyển khoản ngân hàng - số tiền thực tế 2.500.000đ',
    NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'
),
(
    'b0000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000008',
    'https://minio.kinderlog.local/bug-reports/2026/10/09/screenshot-loi-thanh-toan.png',
    'screenshot-app-bao-sai-so-tien.png',
    198437, 'image/png',
    'Screenshot app báo số tiền sai (5.000.000đ thay vì 2.500.000đ)',
    NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'
)
ON CONFLICT (attachment_id) DO UPDATE SET
    file_url = EXCLUDED.file_url,
    file_name = EXCLUDED.file_name,
    file_size = EXCLUDED.file_size,
    mime_type = EXCLUDED.mime_type,
    description = EXCLUDED.description,
    updated_at = NOW();

-- ===========================================================================
-- 14. Bug Report History (bổ sung) — 10 entry cho 4 report mới
-- Pattern: Report #6 (1 created), Report #7 (1 created),
--          Report #8 (4: created → assign A → re-assign A→B → comment),
--          Report #9 (4: created → in_progress → resolved → closed)
-- ===========================================================================

-- Report #6: chỉ 1 entry "created" (chưa ai xem)
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-00000000000d',
    '10000000-0000-0000-0000-000000000006',
    '11111111-0000-0000-0000-000000000002',  -- Cô Lan tạo
    NULL, 'open', NULL, NULL,
    'Report created by teacher',
    NOW() - INTERVAL '6 hours'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #7: chỉ 1 entry "created" 35 ngày trước (stale, chưa xử lý)
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-00000000000e',
    '10000000-0000-0000-0000-000000000007',
    '22222222-0000-0000-0000-000000000004',  -- Phụ huynh Thảo tạo
    NULL, 'open', NULL, NULL,
    'Report created by parent',
    NOW() - INTERVAL '35 days'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #8: 4 entry (created → assign A → re-assign A→B → admin comment kèm status update)
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-00000000000f',
    '10000000-0000-0000-0000-000000000008',
    '22222222-0000-0000-0000-000000000005',  -- Phụ huynh Thành tạo
    NULL, 'open', NULL, NULL,
    'Report created by parent',
    NOW() - INTERVAL '3 days'
),
(
    'a0000000-0000-0000-0000-000000000010',
    '10000000-0000-0000-0000-000000000008',
    '99999999-0000-0000-0000-000000000001',  -- Admin assign lần đầu
    'open', 'in_progress', NULL, 'bbbbbbbb-0000-0000-0000-000000000001',  -- Cô Mai
    'Đã giao cho Cô Mai liên hệ phụ huynh xác minh hóa đơn.',
    NOW() - INTERVAL '2 days'
),
(
    'a0000000-0000-0000-0000-000000000011',
    '10000000-0000-0000-0000-000000000008',
    '99999999-0000-0000-0000-000000000001',  -- Admin re-assign
    NULL, NULL, 'bbbbbbbb-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002',  -- Cô Mai → Cô Lan
    'Cô Mai bận họp phụ huynh, chuyển qua Cô Lan (có kinh nghiệm xử lý payment issues).',
    NOW() - INTERVAL '1 day'
),
(
    'a0000000-0000-0000-0000-000000000012',
    '10000000-0000-0000-0000-000000000008',
    '11111111-0000-0000-0000-000000000002',  -- Cô Lan (giáo viên được assign) tự thêm ghi chú
    NULL, NULL, 'bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002',
    'Đã xác minh: payment gateway trả về amount*2 do bug ở webhook handler. Đang liên hệ backend team rollback.',
    NOW() - INTERVAL '6 hours'
)
ON CONFLICT (history_id) DO NOTHING;

-- Report #9: 4 entry full lifecycle
INSERT INTO bug_report_history (
    history_id, bug_report_id, changed_by_id,
    old_status, new_status, old_teacher_id, new_teacher_id,
    comment, created_at
) VALUES
(
    'a0000000-0000-0000-0000-000000000013',
    '10000000-0000-0000-0000-000000000009',
    '11111111-0000-0000-0000-000000000001',  -- Cô Mai tạo
    NULL, 'open', NULL, NULL,
    'Report created by teacher',
    NOW() - INTERVAL '25 days'
),
(
    'a0000000-0000-0000-0000-000000000014',
    '10000000-0000-0000-0000-000000000009',
    '99999999-0000-0000-0000-000000000001',  -- Admin assign
    'open', 'in_progress', NULL, 'bbbbbbbb-0000-0000-0000-000000000002',
    'Cô Lan đang kiểm tra AudioService config.',
    NOW() - INTERVAL '23 days'
),
(
    'a0000000-0000-0000-0000-000000000015',
    '10000000-0000-0000-0000-000000000009',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'in_progress', 'resolved', 'bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002',
    'Root cause: notification channel dùng IMPORTANCE_LOW bị hệ thống cắt ngắn. Đã bump lên IMPORTANCE_DEFAULT. Build 1.2.2 deploy lên Play Store.',
    NOW() - INTERVAL '20 days'
),
(
    'a0000000-0000-0000-0000-000000000016',
    '10000000-0000-0000-0000-000000000009',
    '99999999-0000-0000-0000-000000000001',  -- Admin
    'resolved', 'closed', 'bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002',
    'Cô Mai xác nhận âm thanh phát đủ sau khi cập nhật app. Đóng ticket.',
    NOW() - INTERVAL '18 days'
)
ON CONFLICT (history_id) DO NOTHING;
