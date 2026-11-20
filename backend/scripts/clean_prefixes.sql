-- clean_prefixes.sql
-- Script làm sạch tiền tố tiếng Việt (Cô, Thầy, Lớp, Trường Mầm Non)
-- để chuyển thành text tĩnh đa ngôn ngữ trên Frontend.

BEGIN;

-- 1. Làm sạch tên trường
UPDATE school
SET name = 'Họa Mi'
WHERE school_id = 'aaaaaaaa-0000-0000-0000-000000000001'
   OR name ILIKE '%Trường Mầm Non Họa Mi%';

-- 2. Làm sạch tên lớp: loại bỏ tiền tố "Lớp "
UPDATE class
SET name = REGEXP_REPLACE(name, '^(Lớp|Class)\s+', '', 'i')
WHERE name ~* '^(Lớp|Class)\s+';

-- 3. Làm sạch tên giáo viên: loại bỏ tiền tố "Cô ", "Thầy "
UPDATE teacher
SET full_name = REGEXP_REPLACE(full_name, '^(Cô|Thầy)\s+', '', 'i')
WHERE full_name ~* '^(Cô|Thầy)\s+';

COMMIT;
