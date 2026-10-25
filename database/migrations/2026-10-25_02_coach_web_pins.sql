-- Coaches log in to the web registration pages with mobile number + a 6-digit PIN they set themselves
-- (replaces the private manage link). One PIN per coach covers all his teams. The PIN is stored as an
-- HMAC with a server secret; 5 wrong PINs lock it for 15 minutes; staff can reset it from the admin portal.
CREATE TABLE coach_web_pins (
  user_id          INT              NOT NULL PRIMARY KEY,
  pin_hash         CHAR(64)         NOT NULL,
  failed_attempts  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until     DATETIME         NULL,
  updated_at       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_cwp_user FOREIGN KEY (user_id) REFERENCES app_users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
