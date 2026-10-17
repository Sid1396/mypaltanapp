-- Live scoring (cricket first). Every scoring action is an event; the server replays them into the live score.

-- One 6-digit scoring PIN per tournament, shown to the organiser.
ALTER TABLE tournaments
  ADD COLUMN scoring_pin CHAR(6) NULL;

-- People who entered the PIN. (Scorers confirmed by MyPaltan through Officials can score without it.)
CREATE TABLE tournament_scorers (
  tournament_id INT NOT NULL,
  user_id INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (tournament_id, user_id),
  KEY idx_user (user_id),
  CONSTRAINT fk_ts_tournament FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE,
  CONSTRAINT fk_ts_user FOREIGN KEY (user_id) REFERENCES app_users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Match state for scoring.
ALTER TABLE tournament_matches
  ADD COLUMN toss_winner_entry_id INT NULL,
  ADD COLUMN toss_decision ENUM('BAT','BOWL') NULL,
  ADD COLUMN scorer_user_id INT NULL,                -- only one phone scores at a time
  ADD COLUMN scorer_seen_at DATETIME NULL,           -- last activity from that phone
  ADD COLUMN started_at DATETIME NULL,
  ADD COLUMN ended_at DATETIME NULL,
  ADD COLUMN winner_entry_id INT NULL,
  ADD COLUMN result_text VARCHAR(120) NULL,          -- e.g. "Tigers won by 4 wickets"
  ADD COLUMN event_count INT NOT NULL DEFAULT 0,     -- events applied so far (offline sync checks this)
  ADD COLUMN live JSON NULL;                         -- live score + scorecard, rebuilt after every event

-- Playing XI for each team in a match (names copied so the scorecard never changes later).
CREATE TABLE match_players (
  match_id INT NOT NULL,
  entry_id INT NOT NULL,
  team_member_id INT NOT NULL,
  user_id INT NULL,
  name VARCHAR(60) NOT NULL,
  is_captain TINYINT(1) NOT NULL DEFAULT 0,
  is_keeper TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (match_id, team_member_id),
  KEY idx_entry (match_id, entry_id),
  CONSTRAINT fk_mp_match FOREIGN KEY (match_id) REFERENCES tournament_matches (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every scoring action in order: START_INNINGS, BALL, NEW_BATTER, NEW_BOWLER, RETIRE, END_INNINGS, END_MATCH ...
CREATE TABLE match_events (
  id BIGINT NOT NULL AUTO_INCREMENT,
  match_id INT NOT NULL,
  seq INT NOT NULL,                                  -- 1, 2, 3... within the match
  client_id CHAR(36) NOT NULL,                       -- made on the phone, so an offline event is never saved twice
  type VARCHAR(20) NOT NULL,
  data JSON NOT NULL,
  scored_by INT NULL,
  undone TINYINT(1) NOT NULL DEFAULT 0,              -- Undo marks the last event instead of deleting it
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_match_client (match_id, client_id),
  UNIQUE KEY uq_match_seq (match_id, seq),
  CONSTRAINT fk_me_match FOREIGN KEY (match_id) REFERENCES tournament_matches (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
