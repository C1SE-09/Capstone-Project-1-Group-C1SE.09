import psycopg2

#File này để Huy test thoi

conn = psycopg2.connect(
    host="localhost",
    database="capstone_db",
    user="postgres",
    password="123456"
)
cur = conn.cursor()

# 1. Tạo school nếu chưa có
cur.execute("SELECT school_id FROM school LIMIT 1")
school_row = cur.fetchone()
if school_row:
    school_id = school_row[0]
    print(f"✅ Dùng school có sẵn: {school_id}")
else:
    cur.execute("""
        INSERT INTO school (school_id, name, code, status, created_at, updated_at)
        VALUES (gen_random_uuid(), 'Trường Mầm Non Test', 'TEST-001', 'ACTIVE', NOW(), NOW())
        RETURNING school_id
    """)
    school_id = cur.fetchone()[0]
    print(f"✅ Tạo school mới: {school_id}")

# 2. Tạo class nếu chưa có
cur.execute("SELECT class_id FROM class WHERE school_id = %s LIMIT 1", (school_id,))
class_row = cur.fetchone()
if class_row:
    class_id = class_row[0]
    print(f"✅ Dùng class có sẵn: {class_id}")
else:
    cur.execute("""
        INSERT INTO class (class_id, school_id, name, grade_label, is_active, created_at, updated_at)
        VALUES (gen_random_uuid(), %s, 'Lớp Mầm A', 'Mầm', true, NOW(), NOW())
        RETURNING class_id
    """, (school_id,))
    class_id = cur.fetchone()[0]
    print(f"✅ Tạo class mới: {class_id}")

# 3. Tạo teacher nếu chưa có
cur.execute("SELECT teacher_id FROM teacher WHERE school_id = %s LIMIT 1", (school_id,))
teacher_row = cur.fetchone()
if teacher_row:
    teacher_id = teacher_row[0]
    print(f"✅ Dùng teacher có sẵn: {teacher_id}")
else:
    cur.execute("""
        INSERT INTO teacher (teacher_id, school_id, class_id, full_name, email, status, is_verified, created_at, updated_at)
        VALUES (gen_random_uuid(), %s, %s, 'Cô Giáo Test', 'test_teacher@example.com', 'ACTIVE', true, NOW(), NOW())
        RETURNING teacher_id
    """, (school_id, class_id))
    teacher_id = cur.fetchone()[0]
    print(f"✅ Tạo teacher mới: {teacher_id}")

# 4. Tạo child nếu chưa có
cur.execute("SELECT child_id FROM child WHERE class_id = %s LIMIT 1", (class_id,))
child_row = cur.fetchone()
if child_row:
    child_id = child_row[0]
    print(f"✅ Dùng child có sẵn: {child_id}")
else:
    cur.execute("""
        INSERT INTO child (child_id, class_id, full_name, nickname, status, created_at, updated_at)
        VALUES (gen_random_uuid(), %s, 'Bé Nam', 'Nam', 'ENROLLED', NOW(), NOW())
        RETURNING child_id
    """, (class_id,))
    child_id = cur.fetchone()[0]
    print(f"✅ Tạo child mới: {child_id}")

# 5. Tạo voice_record
cur.execute("""
    INSERT INTO voice_record (
        voice_record_id, teacher_id, child_id, audio_url,
        transcription, status, created_at, updated_at
    ) VALUES (
        gen_random_uuid(), %s, %s, 'test_audio.wav',
        'Hôm nay bé Nam ăn ngon miệng, ngủ trưa tốt, vui vẻ và vẽ tranh rất đẹp.',
        'COMPLETED', NOW(), NOW()
    ) RETURNING voice_record_id
""", (teacher_id, child_id))

voice_id = cur.fetchone()[0]
print(f"\n🎉 Tạo VoiceRecord thành công!")
print(f"   voice_record_id: {voice_id}")
print(f"   teacher_id:      {teacher_id}")
print(f"   child_id:        {child_id}")

conn.commit()
cur.close()
conn.close()
