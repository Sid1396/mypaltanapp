USE mypaltan_db;
DROP TABLE IF EXISTS app_user_sports;
DROP TABLE IF EXISTS app_users;
DROP TABLE IF EXISTS otp_sessions;

CREATE TABLE otp_sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  phone CHAR(10) NOT NULL,
  otp_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME NOT NULL,
  attempts TINYINT NOT NULL DEFAULT 0,
  verified TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_phone (phone),
  KEY idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE app_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  phone CHAR(10) NOT NULL,
  name VARCHAR(50) NULL,
  birthdate DATE NULL,
  gender ENUM('MALE','FEMALE','UNDISCLOSED') NULL,
  jersey_name VARCHAR(12) NULL,
  jersey_number TINYINT UNSIGNED NULL,
  jersey_size ENUM('XS','S','M','L','XL','XXL','3XL') NULL,
  photo_key VARCHAR(255) NULL,
  pincode CHAR(6) NULL,
  area VARCHAR(100) NULL,
  city VARCHAR(100) NULL,
  state VARCHAR(100) NULL,
  profile_complete TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_phone (phone),
  CONSTRAINT chk_jersey_number CHECK (jersey_number IS NULL OR jersey_number <= 99)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE app_user_sports (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  sport ENUM('CRICKET','FOOTBALL','BADMINTON','PICKLEBALL') NOT NULL,
  role VARCHAR(20) NOT NULL,
  batting_hand ENUM('RIGHT','LEFT') NULL,
  bowling_style ENUM('PACE','SPIN','NONE') NULL,
  `rank` TINYINT NOT NULL,
  UNIQUE KEY uq_user_sport (user_id, sport),
  KEY idx_sport (sport),
  CONSTRAINT fk_user_sports_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SHOW TABLES LIKE 'app_%';
SELECT 'otp_sessions' t, COUNT(*) n FROM otp_sessions UNION ALL SELECT 'app_users', COUNT(*) FROM app_users UNION ALL SELECT 'app_user_sports', COUNT(*) FROM app_user_sports;
