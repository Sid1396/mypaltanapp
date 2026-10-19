-- SSPL: payment is optional. "Pay later" players register without a screenshot; staff mark them paid later.
ALTER TABLE event_registrations
  MODIFY COLUMN payment_key VARCHAR(255) NULL,
  ADD COLUMN payment_status ENUM('PAID','PENDING') NOT NULL DEFAULT 'PAID' AFTER food;
