-- Seed data cho KinderLog Test Environment
-- Lần lượt chạy 2 lệnh này để nạp db: docker compose exec api alembic upgrade head
-- & Get-Content -Encoding UTF8 backend/seed.sql | docker compose exec -T db psql -U kinderlog -d kinderlog
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
) ON CONFLICT (school_id) DO NOTHING;

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
) ON CONFLICT (class_id) DO NOTHING;

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
) ON CONFLICT (class_id) DO NOTHING;

-- 3. Thêm Giáo viên mẫu (Teacher)
-- Giáo viên chủ nhiệm Lớp Mầm A
INSERT INTO teacher (
    teacher_id, 
    school_id, 
    class_id, 
    firebase_uid, 
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
    'test_firebase_uid_teacher_01',
    'Cô Nguyễn Thị Mai',
    'teacher.mai@hoami.edu.vn',
    '0987654321',
    'ACTIVE',
    true,
    NOW(),
    NOW()
) ON CONFLICT (teacher_id) DO NOTHING;

-- Giáo viên chủ nhiệm Lớp Mầm B
INSERT INTO teacher (
    teacher_id, 
    school_id, 
    class_id, 
    firebase_uid, 
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
    'test_firebase_uid_teacher_02',
    'Cô Trần Thị Lan',
    'teacher.lan@hoami.edu.vn',
    '0987654322',
    'ACTIVE',
    true,
    NOW(),
    NOW()
) ON CONFLICT (teacher_id) DO NOTHING;

-- 4. Thêm Phụ huynh mẫu (Parent) - 10 phụ huynh cho 10 trẻ
INSERT INTO parent (
    parent_id,
    firebase_uid,
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
    'test_firebase_uid_parent_01',
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
    'test_firebase_uid_parent_02',
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
    'test_firebase_uid_parent_03',
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
    'test_firebase_uid_parent_04',
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
    'test_firebase_uid_parent_05',
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
    'test_firebase_uid_parent_06',
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
    'test_firebase_uid_parent_07',
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
    'test_firebase_uid_parent_08',
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
    'test_firebase_uid_parent_09',
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
    'test_firebase_uid_parent_10',
    'Ngô Bá Khang',
    '0912000010',
    'parent.khang@gmail.com',
    'ACTIVE',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (parent_id) DO NOTHING;

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
ON CONFLICT (child_id) DO NOTHING;
