-- SSPL form: jersey name and number become optional; numbers go up to 4 digits (0-9999).
ALTER TABLE event_registrations
  MODIFY COLUMN jersey_name VARCHAR(12) NULL,
  MODIFY COLUMN jersey_number SMALLINT UNSIGNED NULL;
