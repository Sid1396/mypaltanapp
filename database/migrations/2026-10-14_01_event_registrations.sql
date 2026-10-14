-- Temporary web registration forms for partner leagues (first: SSPL 2027 auction), until the app is live.
CREATE TABLE event_registrations (
  id INT NOT NULL AUTO_INCREMENT,
  event_slug VARCHAR(30) NOT NULL,              -- 'sspl'
  name VARCHAR(60) NOT NULL,
  phone CHAR(10) NOT NULL,
  category ENUM('BATSMAN','BOWLER','ALL_ROUNDER','WICKET_KEEPER') NOT NULL,
  jersey_size ENUM('XS','S','M','L','XL','XXL','3XL') NOT NULL,
  jersey_name VARCHAR(12) NOT NULL,
  jersey_number TINYINT UNSIGNED NOT NULL,      -- 0-99
  food ENUM('VEG','NON_VEG') NOT NULL,
  photo_key VARCHAR(255) NOT NULL,              -- private B2: event_registrations/sspl/...
  payment_key VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_event_phone (event_slug, phone),
  KEY idx_event_time (event_slug, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
