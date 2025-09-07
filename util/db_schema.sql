-- Company master (unique by rssd_id)
CREATE TABLE company (
  company_name TEXT,
  type         TEXT,
  rssd_id      BIGINT PRIMARY KEY,
  city         TEXT,
  state        TEXT
);

-- Financial metrics (one row per metric observation)
CREATE TABLE financial_metrics (
  rssd_id       BIGINT REFERENCES company(rssd_id),
  company_name  TEXT,              -- denormalized for convenience
  type          TEXT,              -- denormalized for convenience
  property_name TEXT,              -- header row 1
  qa_field_id   TEXT,              -- header row 2
  field_type    TEXT,              -- header row 3
  period_date   DATE,              -- header row 4 (OLE → DATE)
  duration      TEXT,              -- header row 5 (MRQ/LTM/"")
  value         TEXT,              -- raw value; see typed view below
  PRIMARY KEY (rssd_id, qa_field_id, field_type, period_date, duration)
);

-- Helpful indexes for common filters
CREATE INDEX fm_idx_rssd ON financial_metrics(rssd_id);
CREATE INDEX fm_idx_field ON financial_metrics(qa_field_id, field_type);
CREATE INDEX fm_idx_period ON financial_metrics(period_date);

