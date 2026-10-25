-- Web registration for tournaments: coach registers on mypaltan.com/register/<slug>, parents add children
-- through the team's player link, the coach approves them on a private manage link.

-- Readable link name for a tournament, with the per-player fee used by the web form.
CREATE TABLE tournament_web_links (
  slug            VARCHAR(40)  NOT NULL PRIMARY KEY,
  tournament_id   INT          NOT NULL,
  fee_per_player  INT          NOT NULL DEFAULT 0,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_twl_tournament FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Players the coach has paid for, and the private manage link (only its SHA-256 is stored).
ALTER TABLE tournament_entries
  ADD COLUMN paid_players    SMALLINT UNSIGNED NULL COMMENT 'Players paid for through the web form (fee per player)' AFTER amount,
  ADD COLUMN manage_key_hash CHAR(64)          NULL COMMENT 'SHA-256 of the coach''s private manage link key' AFTER paid_players,
  ADD UNIQUE KEY uq_manage_key (manage_key_hash);

-- Every payment a coach makes: the first one and any for extra players.
CREATE TABLE entry_payments (
  id          INT               NOT NULL AUTO_INCREMENT PRIMARY KEY,
  entry_id    INT               NOT NULL,
  players     SMALLINT UNSIGNED NOT NULL,
  amount      INT               NOT NULL,
  utr         VARCHAR(30)       NULL,
  proof_key   VARCHAR(255)      NULL,
  created_at  DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_entry (entry_id),
  CONSTRAINT fk_ep_entry FOREIGN KEY (entry_id) REFERENCES tournament_entries (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- mypaltan.com/register/football-fiesta → MyPaltan Football Fiesta, Rs 999 per player.
INSERT INTO tournament_web_links (slug, tournament_id, fee_per_player)
  SELECT 'football-fiesta', id, 999 FROM tournaments WHERE code = 'VV3J9V';
