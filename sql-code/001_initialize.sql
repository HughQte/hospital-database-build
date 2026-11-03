-- Project: Hospital and Insurance Database
-- File: 001_initialize.sql
-- PostgreSQL

-- Create domain
CREATE SCHEMA HOSPITAL;
CREATE SCHEMA CLINICAL;
CREATE SCHEMA INSURANCE;
CREATE SCHEMA BILLING;
CREATE SCHEMA AUDIT;

-- Create table
CREATE TABLE HOSPITAL.PATIENTS (
  patient_id BIGINT GENERATED ALWAYS AS IDENTITY  -- PATIENTS primary key
        PRIMARY KEY,
  mrn VARCHAR(30) NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  sex_at_birth VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT valid_dob
        CHECK (date_of_birth >= DATE '1900-01-01')
);

-- Example test patients (synthetic only)
INSERT INTO hospital.patients
(mrn, first_name, last_name, date_of_birth, sex_at_birth)
VALUES
('MRN0001', 'John', 'Smith', '1985-04-12', 'Male'),
('MRN0002', 'Emily', 'Johnson', '1992-07-24', 'Female'),
('MRN0003', 'Michael', 'Brown', '1974-11-05', 'Male');

-- Verify records
SELECT
    patient_id,
    mrn,
    first_name,
    last_name,
    date_of_birth
FROM hospital.patients
ORDER BY patient_id;
