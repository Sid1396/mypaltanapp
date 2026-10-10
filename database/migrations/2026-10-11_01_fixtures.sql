-- Fixtures: the match schedule for each division.

CREATE TABLE tournament_matches (
  id INT NOT NULL AUTO_INCREMENT,
  tournament_id INT NOT NULL,
  division_id INT NOT NULL,
  match_no SMALLINT NOT NULL,                       -- order within the division: 1, 2, 3...
  stage ENUM('GROUP','KNOCKOUT') NOT NULL,
  group_no TINYINT NULL,                            -- group matches: 1 = Group A
  round_no TINYINT NOT NULL,                        -- group round, or knockout round (1 = first knockout round)
  label VARCHAR(40) NULL,                           -- 'Final', 'Semi-final 1'
  home_entry_id INT NULL,                           -- NULL until known (knockouts)
  away_entry_id INT NULL,
  home_ref VARCHAR(12) NULL,                        -- where an unknown team comes from: 'G1#1' = Group A 1st, 'W#5' = winner of match 5
  away_ref VARCHAR(12) NULL,
  pitch TINYINT NOT NULL DEFAULT 1,
  scheduled_at DATETIME NOT NULL,
  status ENUM('SCHEDULED','LIVE','COMPLETED','CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
  home_score SMALLINT NULL,
  away_score SMALLINT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_division_match (division_id, match_no),
  KEY idx_tournament_time (tournament_id, scheduled_at),
  KEY idx_home (home_entry_id),
  KEY idx_away (away_entry_id),
  CONSTRAINT fk_tm_tournament FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_division FOREIGN KEY (division_id) REFERENCES tournament_divisions (id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_home FOREIGN KEY (home_entry_id) REFERENCES tournament_entries (id) ON DELETE SET NULL,
  CONSTRAINT fk_tm_away FOREIGN KEY (away_entry_id) REFERENCES tournament_entries (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which group a confirmed team is in, and its knockout seed (random draw or picked by the organiser).
ALTER TABLE tournament_entries
  ADD COLUMN group_no TINYINT NULL AFTER division_id,
  ADD COLUMN seed TINYINT NULL AFTER group_no;

-- The organiser's schedule settings per division, kept so the fixtures can be made again.
ALTER TABLE tournament_divisions
  ADD COLUMN fixture_start DATETIME NULL,           -- NULL = straight after the previous division
  ADD COLUMN fixture_pitches TINYINT NULL,
  ADD COLUMN fixture_gap_minutes SMALLINT NULL,     -- kick-off to kick-off
  ADD COLUMN fixture_draw ENUM('RANDOM','MANUAL') NULL;

-- Daily playing window (matches spill to the next day after day_end) and publish state.
ALTER TABLE tournaments
  ADD COLUMN fixtures_day_start TIME NULL,
  ADD COLUMN fixtures_day_end TIME NULL,
  ADD COLUMN fixtures_published_at DATETIME NULL;
