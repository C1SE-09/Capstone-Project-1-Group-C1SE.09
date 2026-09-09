-- Seed data cho KinderLog Test Environment

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

-- 3. Thêm Giáo viên mẫu (Teacher)
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
