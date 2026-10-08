USE mypaltan_db;

ALTER TABLE app_users
  ADD COLUMN food_pref ENUM('VEG','NON_VEG','JAIN','EGG') NULL AFTER jersey_size,
  ADD COLUMN is_verified TINYINT(1) NOT NULL DEFAULT 0 AFTER profile_complete;

CREATE TABLE identity_verifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  id_type ENUM('AADHAAR_MASKED','PAN','DRIVING_LICENCE','VOTER_ID','PASSPORT') NOT NULL,
  id_last4 CHAR(4) NOT NULL,
  name_on_id VARCHAR(100) NOT NULL,
  id_front_key VARCHAR(255) NOT NULL,
  id_back_key VARCHAR(255) NULL,
  selfie_key VARCHAR(255) NOT NULL,
  status ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
  reject_reason VARCHAR(255) NULL,
  reviewed_by INT NULL,
  reviewed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user (user_id), KEY idx_status (status),
  CONSTRAINT fk_idv_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
  CONSTRAINT fk_idv_staff FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE teams (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code CHAR(6) NOT NULL,
  sport ENUM('CRICKET','FOOTBALL','BADMINTON','PICKLEBALL') NOT NULL,
  name VARCHAR(60) NOT NULL,
  short_name VARCHAR(4) NOT NULL,
  logo_key VARCHAR(255) NOT NULL,
  area VARCHAR(100) NULL,
  city VARCHAR(50) NOT NULL DEFAULT 'Mumbai',
  captain_user_id INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_code (code), KEY idx_captain (captain_user_id),
  CONSTRAINT fk_team_captain FOREIGN KEY (captain_user_id) REFERENCES app_users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE team_members (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id INT NOT NULL,
  user_id INT NULL,
  guest_phone CHAR(10) NULL,
  guest_name VARCHAR(50) NULL,
  role ENUM('CAPTAIN','VICE_CAPTAIN','PLAYER') NOT NULL DEFAULT 'PLAYER',
  status ENUM('ACTIVE','PENDING','REMOVED') NOT NULL DEFAULT 'ACTIVE',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_team_user (team_id, user_id),
  UNIQUE KEY uq_team_guest (team_id, guest_phone),
  CONSTRAINT fk_tm_team FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tournaments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code CHAR(6) NOT NULL,
  organizer_user_id INT NOT NULL,
  sport ENUM('CRICKET','FOOTBALL','BADMINTON','PICKLEBALL') NOT NULL,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(1000) NULL,
  logo_key VARCHAR(255) NOT NULL,
  banner_key VARCHAR(255) NULL,
  category ENUM('OPEN','CORPORATE','COMMUNITY','SCHOOL','COLLEGE','UNIVERSITY','OTHER') NOT NULL,
  city VARCHAR(50) NOT NULL DEFAULT 'Mumbai',
  area VARCHAR(100) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  match_days ENUM('WEEKEND','WEEKDAYS','ALL') NOT NULL DEFAULT 'ALL',
  match_timing ENUM('DAY','NIGHT','BOTH') NOT NULL DEFAULT 'BOTH',
  format ENUM('LEAGUE','KNOCKOUT','LEAGUE_KNOCKOUT') NOT NULL,
  group_count TINYINT NULL,
  qualify_per_group TINYINT NULL,
  max_teams SMALLINT NOT NULL,
  squad_min TINYINT NOT NULL,
  squad_max TINYINT NOT NULL,
  entry_fee INT NOT NULL DEFAULT 0,
  jersey_fee INT NOT NULL DEFAULT 0,
  prize_type ENUM('NONE','CASH','TROPHY','BOTH') NOT NULL DEFAULT 'NONE',
  prize_details VARCHAR(255) NULL,
  food_provided TINYINT(1) NOT NULL DEFAULT 0,
  meals SET('BREAKFAST','LUNCH','DINNER','SNACKS') NULL,
  jersey_provided TINYINT(1) NOT NULL DEFAULT 0,
  jersey_print ENUM('NAME_NUMBER','NUMBER','PLAIN') NULL,
  registration_deadline DATETIME NOT NULL,
  checklist_deadline DATETIME NULL,
  visibility ENUM('PRIVATE','PUBLIC_PENDING','PUBLIC') NOT NULL DEFAULT 'PRIVATE',
  status ENUM('DRAFT','REGISTRATION_OPEN','REGISTRATION_CLOSED','FIXTURES_READY','LIVE','COMPLETED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
  published_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_code (code),
  KEY idx_organizer (organizer_user_id),
  KEY idx_public (visibility, status, start_date),
  CONSTRAINT chk_t_dates CHECK (end_date >= start_date),
  CONSTRAINT chk_t_squad CHECK (squad_max >= squad_min),
  CONSTRAINT chk_t_fee CHECK (entry_fee >= 0 AND jersey_fee >= 0 AND jersey_fee <= entry_fee),
  CONSTRAINT fk_t_organizer FOREIGN KEY (organizer_user_id) REFERENCES app_users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tournament_rules (
  tournament_id INT PRIMARY KEY,
  match_rules JSON NOT NULL,
  points JSON NOT NULL,
  CONSTRAINT fk_tr_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tournament_grounds (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tournament_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  KEY idx_t (tournament_id),
  CONSTRAINT fk_tg_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tournament_payment_details (
  tournament_id INT PRIMARY KEY,
  upi_id VARCHAR(100) NOT NULL,
  upi_name VARCHAR(100) NOT NULL,
  upi_name_matched TINYINT(1) NULL,
  qr_key VARCHAR(255) NULL,
  accept_cash TINYINT(1) NOT NULL DEFAULT 0,
  note VARCHAR(255) NULL,
  CONSTRAINT fk_tp_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tournament_entries (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tournament_id INT NOT NULL,
  team_id INT NOT NULL,
  registered_by INT NOT NULL,
  status ENUM('PENDING','APPROVED','REJECTED','WAITLISTED','WITHDRAWN') NOT NULL DEFAULT 'PENDING',
  payment_method ENUM('UPI','CASH','NONE') NOT NULL DEFAULT 'NONE',
  amount INT NOT NULL DEFAULT 0,
  utr VARCHAR(30) NULL,
  proof_key VARCHAR(255) NULL,
  payment_claimed_at DATETIME NULL,
  reject_reason VARCHAR(255) NULL,
  reviewed_by INT NULL,
  reviewed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tournament_team (tournament_id, team_id),
  KEY idx_status (tournament_id, status),
  CONSTRAINT fk_te_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE,
  CONSTRAINT fk_te_team FOREIGN KEY (team_id) REFERENCES teams(id),
  CONSTRAINT fk_te_by FOREIGN KEY (registered_by) REFERENCES app_users(id),
  CONSTRAINT fk_te_reviewer FOREIGN KEY (reviewed_by) REFERENCES app_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tournament_entry_players (
  id INT AUTO_INCREMENT PRIMARY KEY,
  entry_id INT NOT NULL,
  tournament_id INT NOT NULL,
  team_member_id INT NOT NULL,
  user_id INT NULL,
  food_pref ENUM('VEG','NON_VEG','JAIN','EGG') NULL,
  jersey_name VARCHAR(12) NULL,
  jersey_number TINYINT UNSIGNED NULL,
  jersey_size ENUM('XS','S','M','L','XL','XXL','3XL') NULL,
  checklist_done_at DATETIME NULL,
  UNIQUE KEY uq_entry_member (entry_id, team_member_id),
  UNIQUE KEY uq_entry_jersey (entry_id, jersey_number),
  UNIQUE KEY uq_tournament_user (tournament_id, user_id),
  CONSTRAINT fk_tep_entry FOREIGN KEY (entry_id) REFERENCES tournament_entries(id) ON DELETE CASCADE,
  CONSTRAINT fk_tep_member FOREIGN KEY (team_member_id) REFERENCES team_members(id),
  CONSTRAINT fk_tep_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE organizer_ratings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tournament_id INT NOT NULL,
  rater_user_id INT NOT NULL,
  rating TINYINT NOT NULL,
  review VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_rating (tournament_id, rater_user_id),
  CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT fk_or_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE,
  CONSTRAINT fk_or_user FOREIGN KEY (rater_user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reports (
  id INT AUTO_INCREMENT PRIMARY KEY,
  reporter_user_id INT NOT NULL,
  target_type ENUM('ORGANIZER','TOURNAMENT','TEAM','USER') NOT NULL,
  target_id INT NOT NULL,
  reason ENUM('NO_SHOW','PAYMENT_ISSUE','FAKE','ABUSE','OTHER') NOT NULL,
  details VARCHAR(1000) NULL,
  status ENUM('OPEN','REVIEWING','RESOLVED') NOT NULL DEFAULT 'OPEN',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_status (status),
  CONSTRAINT fk_rep_user FOREIGN KEY (reporter_user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

