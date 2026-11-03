-- Create patient table
CREATE TABLE hospital.patient (
  patient_id BIGINT GENERATED ALWAYS AS IDENTITY  -- primary key
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

-- Create organizations
CREATE TABLE hospital.organizations (
  organization_id BIGINT GENERATED ALWAYS AS IDENTITY -- primary key
          PRIMARY KEY,
  organization_name VARCHAR(200) NOT NULL,
  organization_type VARCHAR(50) NOT NULL,
  npi VARCHAR(10) UNIQUE,
  address_line1 VARCHAR(200),
  city VARCHAR(100),
  state VARCHAR(2),
  zip_code VARCHAR(10),
  phone VARCHAR(20),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT valid_organization_type
      CHECK (organization_type IN (
            'Hospital',
            'Clinic',
            'Urgent Care',
            'Specialty Center'
        )),
  CONSTRAINT valid_organization_npi
        CHECK (npi IS NULL OR npi ~ '^[0-9]{10}$')
  );

....
  
