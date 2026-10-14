-- Match officials: the organiser asks MyPaltan for scorers, umpires/referees and live streaming;
-- MyPaltan's team arranges them (payment happens directly, outside the app).

CREATE TABLE tournament_officials_requests (
  tournament_id INT NOT NULL,
  need_scorer TINYINT(1) NOT NULL DEFAULT 0,
  scorers TINYINT NOT NULL DEFAULT 1,               -- people per day
  need_umpires TINYINT(1) NOT NULL DEFAULT 0,
  umpires TINYINT NOT NULL DEFAULT 1,
  need_stream TINYINT(1) NOT NULL DEFAULT 0,
  note VARCHAR(300) NULL,                           -- organiser's note, e.g. "finals only"
  status ENUM('NOT_NEEDED','REQUESTED','CONFIRMED','CANCELLED') NOT NULL DEFAULT 'NOT_NEEDED',
  staff_note VARCHAR(300) NULL,                     -- shown to the organiser, e.g. agreed price
  youtube_url VARCHAR(255) NULL,                    -- stream link once confirmed
  confirmed_by INT NULL,                            -- staff user (users.id)
  confirmed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (tournament_id),
  KEY idx_status (status),
  CONSTRAINT fk_tor_tournament FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The people MyPaltan sends. user_id links an app account (by phone) so a scorer can score in the app.
CREATE TABLE tournament_officials (
  id INT NOT NULL AUTO_INCREMENT,
  tournament_id INT NOT NULL,
  role ENUM('SCORER','UMPIRE','STREAMER') NOT NULL,
  name VARCHAR(60) NOT NULL,
  phone CHAR(10) NOT NULL,
  user_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_official (tournament_id, role, phone),
  KEY idx_user (user_id),
  CONSTRAINT fk_to_tournament FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE,
  CONSTRAINT fk_to_user FOREIGN KEY (user_id) REFERENCES app_users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
