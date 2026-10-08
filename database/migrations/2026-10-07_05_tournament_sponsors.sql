USE mypaltan_db;

-- Organizer's own sponsors (MyPaltan shows no third-party ads). Label is free text chosen by the organizer.
CREATE TABLE tournament_sponsors (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tournament_id INT NOT NULL,
  name VARCHAR(80) NOT NULL,
  label VARCHAR(40) NOT NULL,
  is_title TINYINT(1) NOT NULL DEFAULT 0,
  logo_key VARCHAR(255) NOT NULL,
  banner_key VARCHAR(255) NULL,
  link_url VARCHAR(255) NULL,
  tagline VARCHAR(80) NULL,
  sort_order TINYINT NOT NULL DEFAULT 0,
  KEY idx_t (tournament_id),
  CONSTRAINT fk_ts_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily view / tap counters per sponsor, for organizers to show their sponsors.
CREATE TABLE sponsor_daily_stats (
  sponsor_id INT NOT NULL,
  day DATE NOT NULL,
  views INT NOT NULL DEFAULT 0,
  taps INT NOT NULL DEFAULT 0,
  PRIMARY KEY (sponsor_id, day),
  CONSTRAINT fk_sds_s FOREIGN KEY (sponsor_id) REFERENCES tournament_sponsors(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
