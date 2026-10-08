USE mypaltan_db;

-- Early-access signups from the website. Saved before the notification email is sent,
-- so a Gmail problem can never lose a signup.
CREATE TABLE waitlist_signups (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  phone CHAR(10) NOT NULL,
  city VARCHAR(100) NOT NULL,
  role VARCHAR(100) NOT NULL,
  source VARCHAR(30) NOT NULL DEFAULT 'website',
  email_sent TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
