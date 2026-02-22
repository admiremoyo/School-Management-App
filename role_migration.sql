-- 1. Add user_id and email to students table if not exists
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='students' AND column_name='user_id') THEN
    ALTER TABLE students ADD COLUMN user_id UUID REFERENCES auth.users(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='students' AND column_name='email') THEN
    ALTER TABLE students ADD COLUMN email TEXT;
  END IF;
END $$;

-- 2. Update RLS policies to handle roles
-- DROPPING PREVIOUS POLICIES
DROP POLICY IF EXISTS teachers_admin_policy ON teachers;
DROP POLICY IF EXISTS classes_admin_policy ON classes;
DROP POLICY IF EXISTS students_role_policy ON students;
DROP POLICY IF EXISTS students_admin_policy ON students;
DROP POLICY IF EXISTS students_student_select ON students;
DROP POLICY IF EXISTS subjects_role_policy ON subjects;
DROP POLICY IF EXISTS subjects_admin_policy ON subjects;
DROP POLICY IF EXISTS subjects_student_select ON subjects;
DROP POLICY IF EXISTS exam_marks_role_policy ON exam_marks;
DROP POLICY IF EXISTS exam_marks_admin_policy ON exam_marks;
DROP POLICY IF EXISTS exam_marks_student_select ON exam_marks;
DROP POLICY IF EXISTS fee_payments_role_policy ON fee_payments;
DROP POLICY IF EXISTS fee_payments_admin_policy ON fee_payments;
DROP POLICY IF EXISTS fee_payments_student_select ON fee_payments;

-- ==========================================
-- ADMIN POLICIES (Full Access)
-- ==========================================

CREATE POLICY teachers_admin_policy ON teachers FOR ALL USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' AND 
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

CREATE POLICY classes_admin_policy ON classes FOR ALL USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' AND 
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

CREATE POLICY students_admin_policy ON students FOR ALL USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' AND 
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

CREATE POLICY subjects_admin_policy ON subjects FOR ALL USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' AND 
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

CREATE POLICY exam_marks_admin_policy ON exam_marks FOR ALL USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' AND 
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

CREATE POLICY fee_payments_admin_policy ON fee_payments FOR ALL USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin' AND 
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

-- ==========================================
-- STUDENT POLICIES (Read-Only Self Access)
-- ==========================================

-- Students can see their own student record
CREATE POLICY students_student_select ON students FOR SELECT USING (
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid AND
  user_id = auth.uid()
);

-- Students can see all subjects in their school
CREATE POLICY subjects_student_select ON subjects FOR SELECT USING (
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid
);

-- Students can see their own exam marks
CREATE POLICY exam_marks_student_select ON exam_marks FOR SELECT USING (
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid AND
  student_id IN (SELECT id FROM students WHERE user_id = auth.uid())
);

-- Students can see their own fee payments
CREATE POLICY fee_payments_student_select ON fee_payments FOR SELECT USING (
  school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid AND
  student_id IN (SELECT id FROM students WHERE user_id = auth.uid())
);
