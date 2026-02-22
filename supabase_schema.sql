-- =========================================================
-- OFFLINE-FIRST SCHOOL MANAGEMENT SYSTEM (SUPABASE)
-- SINGLE FILE – COPY & RUN
-- =========================================================

-- 1. Enable UUID support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 2. updated_at trigger function
-- =========================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 3. TEACHERS
-- =========================================================
CREATE TABLE teachers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trg_teachers_updated
BEFORE UPDATE ON teachers
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 4. CLASSES
-- =========================================================
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  name TEXT NOT NULL,
  teacher_id UUID REFERENCES teachers(id),
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trg_classes_updated
BEFORE UPDATE ON classes
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 5. STUDENTS
-- =========================================================
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  name TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  guardian_contact TEXT,
  class_id UUID REFERENCES classes(id),
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trg_students_updated
BEFORE UPDATE ON students
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 6. SUBJECTS
-- =========================================================
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  name TEXT NOT NULL,
  class_id UUID REFERENCES classes(id),
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trg_subjects_updated
BEFORE UPDATE ON subjects
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 7. ATTENDANCE
-- =========================================================
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  student_id UUID REFERENCES students(id),
  date DATE NOT NULL,
  is_present BOOLEAN DEFAULT TRUE,
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (student_id, date)
);

CREATE TRIGGER trg_attendance_updated
BEFORE UPDATE ON attendance
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 8. EXAM MARKS
-- =========================================================
CREATE TABLE exam_marks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  student_id UUID REFERENCES students(id),
  subject_id UUID REFERENCES subjects(id),
  term INT CHECK (term IN (1,2,3)),
  score INT CHECK (score BETWEEN 0 AND 100),
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (student_id, subject_id, term)
);

CREATE TRIGGER trg_exam_marks_updated
BEFORE UPDATE ON exam_marks
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 9. FEE PAYMENTS
-- =========================================================
CREATE TABLE fee_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL,
  student_id UUID REFERENCES students(id),
  amount NUMERIC(10,2) NOT NULL,
  payment_date DATE NOT NULL,
  payment_method TEXT,
  sync_status TEXT DEFAULT 'SYNCED',
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER trg_fee_payments_updated
BEFORE UPDATE ON fee_payments
FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- =========================================================
-- 10. INDEXES (FAST SYNC ON LOW INTERNET)
-- =========================================================
CREATE INDEX idx_students_school_id ON students(school_id);
CREATE INDEX idx_students_updated_at ON students(updated_at);

CREATE INDEX idx_attendance_student_date ON attendance(student_id, date);
CREATE INDEX idx_attendance_updated_at ON attendance(updated_at);

CREATE INDEX idx_exam_marks_student ON exam_marks(student_id);
CREATE INDEX idx_exam_marks_updated_at ON exam_marks(updated_at);

CREATE INDEX idx_fee_payments_student ON fee_payments(student_id);
CREATE INDEX idx_fee_payments_updated_at ON fee_payments(updated_at);

-- =========================================================
-- 11. ENABLE ROW LEVEL SECURITY
-- =========================================================
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_marks ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_payments ENABLE ROW LEVEL SECURITY;

-- =========================================================
-- 12. RLS POLICIES (SCHOOL ISOLATION)
-- school_id must be in auth.users.user_metadata.school_id
-- =========================================================

CREATE POLICY teachers_school_policy
ON teachers FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

CREATE POLICY classes_school_policy
ON classes FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

CREATE POLICY students_school_policy
ON students FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

CREATE POLICY subjects_school_policy
ON subjects FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

CREATE POLICY attendance_school_policy
ON attendance FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

CREATE POLICY exam_marks_school_policy
ON exam_marks FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

CREATE POLICY fee_payments_school_policy
ON fee_payments FOR ALL
USING (school_id = (auth.jwt() -> 'user_metadata' ->> 'school_id')::uuid);

-- =========================================================
-- END OF FILE
-- =========================================================
