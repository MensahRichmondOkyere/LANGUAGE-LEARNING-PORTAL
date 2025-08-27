-- Filename: student_portal_postgres.sql
-- PostgreSQL 13+
-- Database for a student portal: students, instructors, departments, courses, terms, sections, enrollments

CREATE DATABASE student_portal;
\connect student_portal;

-- Core tables
CREATE TABLE departments (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL
);

CREATE TABLE instructors (
  id BIGSERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  department_id INT REFERENCES departments(id) ON UPDATE CASCADE ON DELETE SET NULL,
  hired_at DATE DEFAULT CURRENT_DATE
);

CREATE TABLE students (
  id BIGSERIAL PRIMARY KEY,
  student_no TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  enrolled_at DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE terms (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,              -- e.g., '2025 Spring'
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  CHECK (start_date < end_date)
);

CREATE TABLE courses (
  id BIGSERIAL PRIMARY KEY,
  department_id INT NOT NULL REFERENCES departments(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  code TEXT NOT NULL,                     -- e.g., 'CS101'
  title TEXT NOT NULL,
  credit_hours INT NOT NULL CHECK (credit_hours BETWEEN 1 AND 6),
  UNIQUE(department_id, code)
);

CREATE TABLE sections (
  id BIGSERIAL PRIMARY KEY,
  course_id BIGINT NOT NULL REFERENCES courses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  term_id INT NOT NULL REFERENCES terms(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  section_code TEXT NOT NULL,             -- e.g., 'A', 'B'
  instructor_id BIGINT REFERENCES instructors(id) ON UPDATE CASCADE ON DELETE SET NULL,
  capacity INT NOT NULL DEFAULT 30 CHECK (capacity > 0),
  schedule TEXT,                           -- free-form for demo: 'Mon/Wed 10:00-11:15'
  room TEXT,
  UNIQUE(course_id, term_id, section_code)
);

CREATE TABLE enrollments (
  id BIGSERIAL PRIMARY KEY,
  student_id BIGINT NOT NULL REFERENCES students(id) ON UPDATE CASCADE ON DELETE CASCADE,
  section_id BIGINT NOT NULL REFERENCES sections(id) ON UPDATE CASCADE ON DELETE CASCADE,
  enrolled_on DATE NOT NULL DEFAULT CURRENT_DATE,
  grade TEXT,                              -- e.g., 'A', 'B+' (nullable until posted)
  UNIQUE(student_id, section_id)
);

-- Helpful indexes
CREATE INDEX ix_sections_term_course ON sections (term_id, course_id);
CREATE INDEX ix_enrollments_student ON enrollments (student_id);
CREATE INDEX ix_enrollments_section ON enrollments (section_id);

-- Seed data
INSERT INTO departments (code, name) VALUES
  ('CS','Computer Science'),
  ('MATH','Mathematics');

INSERT INTO instructors (full_name, email, department_id) VALUES
  ('Dr. Abena Owusu','abena.owusu@uni.edu', 1),
  ('Dr. Kwame Boateng','kwame.boateng@uni.edu', 2);

INSERT INTO students (student_no, full_name, email) VALUES
  ('UENR2025001','Kofi Mensah','kofi.mensah@uni.edu'),
  ('UENR2025002','Akosua Dapaah','akosua.dapaah@uni.edu');

INSERT INTO terms (name, start_date, end_date) VALUES
  ('2025 Fall','2025-09-01','2025-12-20');

INSERT INTO courses (department_id, code, title, credit_hours) VALUES
  (1,'CS101','Intro to Programming',3),
  (1,'CS201','Data Structures',3),
  (2,'MATH101','Calculus I',4);

INSERT INTO sections (course_id, term_id, section_code, instructor_id, capacity, schedule, room) VALUES
  (1, 1, 'A', 1, 40, 'Mon/Wed 10:00-11:15', 'ENG-101'),
  (3, 1, 'A', 2, 35, 'Tue/Thu 09:00-10:45', 'SCI-202');

INSERT INTO enrollments (student_id, section_id) VALUES
  (1, 1),
  (2, 1),
  (1, 2);

-- Example queries
-- 1) Student schedule for a term
SELECT s.full_name, t.name AS term, c.code, c.title, se.section_code, se.schedule, se.room
FROM enrollments e
JOIN students s ON s.id = e.student_id
JOIN sections se ON se.id = e.section_id
JOIN courses c ON c.id = se.course_id
JOIN terms t ON t.id = se.term_id
WHERE s.student_no = 'UENR2025001' AND t.name = '2025 Fall'
ORDER BY c.code;

-- 2) Course roster
SELECT c.code, c.title, se.section_code, s.student_no, s.full_name
FROM enrollments e
JOIN sections se ON se.id = e.section_id
JOIN courses c ON c.id = se.course_id
JOIN students s ON s.id = e.student_id
WHERE se.id = 1
ORDER BY s.full_name;

-- 3) Credits per student in a term
SELECT s.student_no, s.full_name, SUM(c.credit_hours) AS credit_hours
FROM enrollments e
JOIN sections se ON se.id = e.section_id
JOIN courses c ON c.id = se.course_id
JOIN students s ON s.id = e.student_id
JOIN terms t ON t.id = se.term_id
WHERE t.name = '2025 Fall'
GROUP BY s.student_no, s.full_name
ORDER BY credit_hours DESC;
