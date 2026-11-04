-- Create patient table
CREATE TABLE hospital.patient (
  patient_id BIGINT GENERATED ALWAYS AS IDENTITY  
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
  organization_id BIGINT GENERATED ALWAYS AS IDENTITY 
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

-- create provider table

CREATE TABLE hospital.providers (
    provider_id BIGINT GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,
    organization_id BIGINT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    npi VARCHAR(10) UNIQUE,
    specialty VARCHAR(100),
    provider_type VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_provider_organization
        FOREIGN KEY (organization_id)
        REFERENCES hospital.organizations(organization_id),
    CONSTRAINT valid_provider_type
        CHECK (provider_type IN (
            'Physician',
            'Nurse Practitioner',
            'Physician Assistant',
            'Registered Nurse',
            'Other'
        )),
    CONSTRAINT valid_provider_npi
        CHECK (npi IS NULL OR npi ~ '^[0-9]{10}$')
);

-- create department table
CREATE TABLE hospital.departments (
    department_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_id BIGINT NOT NULL
        REFERENCES hospital.organizations(organization_id),
    department_name VARCHAR(150) NOT NULL,
    department_code VARCHAR(30) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (organization_id, department_code),
    UNIQUE (department_id, organization_id)
);

-- create provider affiliations
CREATE TABLE hospital.provider_affiliations (
    affiliation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_id BIGINT NOT NULL
        REFERENCES hospital.providers(provider_id),
    organization_id BIGINT NOT NULL
        REFERENCES hospital.organizations(organization_id),
    start_date DATE NOT NULL,
    end_date DATE,
    affiliation_role VARCHAR(100),
    CHECK (end_date IS NULL OR end_date >= start_date),
    UNIQUE (provider_id, organization_id, start_date)
);

-- create encounters
CREATE TABLE hospital.encounters (
    encounter_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id BIGINT NOT NULL
        REFERENCES hospital.patient(patient_id),
    organization_id BIGINT NOT NULL
        REFERENCES hospital.organizations(organization_id),
    department_id BIGINT,
    encounter_type VARCHAR(30) NOT NULL,
    encounter_status VARCHAR(30) NOT NULL DEFAULT 'registered',
    admission_time TIMESTAMPTZ NOT NULL,
    discharge_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (department_id, organization_id)
        REFERENCES hospital.departments(
            department_id, organization_id
        ),
    CHECK (encounter_type IN (
        'inpatient', 'outpatient', 'emergency',
        'observation', 'telehealth'
    )),
    CHECK (encounter_status IN (
        'registered', 'in-progress', 'finished',
        'cancelled', 'entered-in-error'
    )),
    CHECK (
        discharge_time IS NULL
        OR discharge_time >= admission_time
    )
);

-- create encounter providers
CREATE TABLE hospital.encounter_providers (
    encounter_id BIGINT NOT NULL
        REFERENCES hospital.encounters(encounter_id),
    provider_id BIGINT NOT NULL
        REFERENCES hospital.providers(provider_id),
    provider_role VARCHAR(50) NOT NULL,
    PRIMARY KEY (encounter_id, provider_id, provider_role)
);

-- create diagnose code catalog
CREATE TABLE hospital.diagnosis_codes (
    diagnosis_code_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_system VARCHAR(30) NOT NULL,
    code VARCHAR(30) NOT NULL,
    code_version VARCHAR(30) NOT NULL,
    description TEXT NOT NULL,
    valid_from DATE,
    valid_to DATE,
    UNIQUE (code_system, code, code_version),
    CHECK (valid_to IS NULL OR
           valid_from IS NULL OR valid_to >= valid_from)
);

-- create encounter diagnoses
CREATE TABLE hospital.encounter_diagnoses (
    encounter_diagnosis_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    encounter_id BIGINT NOT NULL
        REFERENCES hospital.encounters(encounter_id),
    diagnosis_code_id BIGINT NOT NULL
        REFERENCES hospital.diagnosis_codes(diagnosis_code_id),
    diagnosis_rank INTEGER,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (diagnosis_rank IS NULL OR diagnosis_rank > 0),
    UNIQUE (encounter_id, diagnosis_code_id)
);

CREATE UNIQUE INDEX uq_encounter_primary_diagnosis
ON hospital.encounter_diagnoses(encounter_id)
WHERE is_primary = TRUE;

-- PROCEDURE CODE CATALOG
CREATE TABLE hospital.procedure_codes (
    procedure_code_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code_system VARCHAR(30) NOT NULL,
    code VARCHAR(30) NOT NULL,
    code_version VARCHAR(30) NOT NULL,
    description TEXT NOT NULL,
    valid_from DATE,
    valid_to DATE,
    UNIQUE (code_system, code, code_version)
);

-- ENCOUNTER PROCEDURES
CREATE TABLE hospital.encounter_procedures (
    encounter_procedure_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    encounter_id BIGINT NOT NULL
        REFERENCES hospital.encounters(encounter_id),
    procedure_code_id BIGINT NOT NULL
        REFERENCES hospital.procedure_codes(procedure_code_id),
    performed_by BIGINT
        REFERENCES hospital.providers(provider_id),
    performed_at TIMESTAMPTZ,
    procedure_status VARCHAR(30) NOT NULL DEFAULT 'completed',
    CHECK (procedure_status IN (
        'planned', 'in-progress', 'completed',
        'cancelled', 'entered-in-error'
    )),
    UNIQUE (encounter_procedure_id, encounter_id)
);

-- CLINICAL OBSERVATIONS
-- Vitals, laboratory results, and other measurements.
CREATE TABLE hospital.observations (
    observation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    encounter_id BIGINT NOT NULL
        REFERENCES hospital.encounters(encounter_id),
    observation_code VARCHAR(40) NOT NULL,
    code_system VARCHAR(50) NOT NULL,
    observation_name VARCHAR(200) NOT NULL,
    observed_at TIMESTAMPTZ NOT NULL,
    value_numeric NUMERIC(14,4),
    value_text TEXT,
    unit_code VARCHAR(40),
    status VARCHAR(30) NOT NULL DEFAULT 'final',
    CHECK (
        value_numeric IS NOT NULL
        OR value_text IS NOT NULL
    ),
    CHECK (status IN (
        'preliminary', 'final', 'amended',
        'corrected', 'entered-in-error'
    ))
);

-- PATIENT ALLERGIES
CREATE TABLE hospital.allergies (
    allergy_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id BIGINT NOT NULL
        REFERENCES hospital.patient(patient_id),
    substance_code VARCHAR(50),
    code_system VARCHAR(50),
    substance_name VARCHAR(200) NOT NULL,
    clinical_status VARCHAR(30) NOT NULL DEFAULT 'active',
    reaction_description TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (clinical_status IN (
        'active', 'inactive', 'resolved'
    ))
);

-- MEDICATION CATALOG
CREATE TABLE hospital.medications (
    medication_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medication_name VARCHAR(250) NOT NULL,
    rxnorm_code VARCHAR(30),
    strength VARCHAR(100),
    dosage_form VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- MEDICATION ORDERS
CREATE TABLE hospital.medication_orders (
    medication_order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    encounter_id BIGINT NOT NULL
        REFERENCES hospital.encounters(encounter_id),
    medication_id BIGINT NOT NULL
        REFERENCES hospital.medications(medication_id),
    prescribing_provider_id BIGINT NOT NULL
        REFERENCES hospital.providers(provider_id),
    dosage_instruction TEXT NOT NULL,
    route VARCHAR(100),
    frequency VARCHAR(100),
    ordered_at TIMESTAMPTZ NOT NULL,
    order_status VARCHAR(30) NOT NULL DEFAULT 'active',
    CHECK (order_status IN (
        'draft', 'active', 'completed',
        'cancelled', 'stopped', 'entered-in-error'
    ))
);

-- MEDICATION ADMINISTRATIONS
-- Actual medication delivery, separate from orders.
CREATE TABLE hospital.medication_administrations (
    administration_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medication_order_id BIGINT NOT NULL
        REFERENCES hospital.medication_orders(medication_order_id),
    administered_by BIGINT
        REFERENCES hospital.providers(provider_id),
    administered_at TIMESTAMPTZ NOT NULL,
    dose_given VARCHAR(100),
    administration_status VARCHAR(30) NOT NULL,
    CHECK (administration_status IN (
        'completed', 'not-done', 'in-progress',
        'entered-in-error'
    ))
);

-- HOSPITAL CHARGES
-- Hospital revenue-cycle source records.
CREATE TABLE hospital.charges (
    charge_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    encounter_id BIGINT NOT NULL
        REFERENCES hospital.encounters(encounter_id),
    encounter_procedure_id BIGINT,
    charge_code VARCHAR(40) NOT NULL,
    charge_description TEXT NOT NULL,
    quantity NUMERIC(12,3) NOT NULL DEFAULT 1,
    unit_price NUMERIC(14,2) NOT NULL,
    charge_amount NUMERIC(16,2)
        GENERATED ALWAYS AS (quantity * unit_price) STORED,
    charged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (encounter_procedure_id, encounter_id)
        REFERENCES hospital.encounter_procedures(
            encounter_procedure_id, encounter_id
        ),

    CHECK (quantity > 0),
    CHECK (unit_price >= 0)
);

-- INDEXES FOR COMMON RELATIONSHIP QUERIES
CREATE INDEX idx_encounters_patient
ON hospital.encounters(patient_id);

CREATE INDEX idx_encounters_organization
ON hospital.encounters(organization_id);

CREATE INDEX idx_encounters_admission
ON hospital.encounters(admission_time);

CREATE INDEX idx_encounter_providers_provider
ON hospital.encounter_providers(provider_id);

CREATE INDEX idx_affiliations_provider
ON hospital.provider_affiliations(provider_id);

CREATE INDEX idx_affiliations_organization
ON hospital.provider_affiliations(organization_id);

CREATE INDEX idx_encounter_diagnoses_encounter
ON hospital.encounter_diagnoses(encounter_id);

CREATE INDEX idx_encounter_diagnoses_code
ON hospital.encounter_diagnoses(diagnosis_code_id);

CREATE INDEX idx_procedures_encounter
ON hospital.encounter_procedures(encounter_id);

CREATE INDEX idx_observations_encounter_time
ON hospital.observations(encounter_id, observed_at);

CREATE INDEX idx_allergies_patient
ON hospital.allergies(patient_id);

CREATE INDEX idx_medication_orders_encounter
ON hospital.medication_orders(encounter_id);

CREATE INDEX idx_medication_administrations_order
ON hospital.medication_administrations(medication_order_id);

CREATE INDEX idx_charges_encounter
ON hospital.charges(encounter_id);
