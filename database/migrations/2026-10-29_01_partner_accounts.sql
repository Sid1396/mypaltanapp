-- Partner accounts: organisers of a partner league (e.g. SSPL) log in at mypaltan.com/partner/<slug> with
-- mobile + password and manage only their own event's registrations.
ALTER TABLE users
  MODIFY COLUMN role ENUM('superadmin','admin','employee','partner') NOT NULL DEFAULT 'employee',
  ADD COLUMN event_slug VARCHAR(40) NULL COMMENT 'Partner accounts: the only event they can manage' AFTER role;
