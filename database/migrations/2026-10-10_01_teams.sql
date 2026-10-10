USE mypaltan_db;

-- Teams: players join with their own account through the team link, and the coach or captain
-- can add players under 13 by hand (no app needed). Jersey numbers may repeat within a team.
-- A COACH runs the team but does not play (not counted in the squad). Coaches and captains with the
-- app manage the team; teams.captain_user_id keeps pointing at one of them (the team's manager).

ALTER TABLE team_members
  DROP INDEX uq_team_guest,
  CHANGE guest_phone parent_phone CHAR(10) DEFAULT NULL COMMENT 'Parent or guardian phone for a coach-added player',
  MODIFY guest_name VARCHAR(50) DEFAULT NULL COMMENT 'Name of a coach-added player (no app account)',
  MODIFY role ENUM('COACH','CAPTAIN','VICE_CAPTAIN','PLAYER') NOT NULL DEFAULT 'PLAYER' COMMENT 'COACH = runs the team, does not play',
  ADD COLUMN guest_birthdate DATE DEFAULT NULL AFTER guest_name,
  ADD COLUMN guest_gender ENUM('MALE','FEMALE','UNDISCLOSED') DEFAULT NULL AFTER guest_birthdate,
  ADD COLUMN guest_photo_key VARCHAR(255) DEFAULT NULL AFTER guest_gender,
  ADD COLUMN position VARCHAR(20) DEFAULT NULL COMMENT 'Playing role in the team sport, e.g. GOALKEEPER' AFTER role,
  ADD COLUMN jersey_name VARCHAR(12) DEFAULT NULL COMMENT 'Overrides the profile jersey name for this team' AFTER position,
  ADD COLUMN jersey_number TINYINT UNSIGNED DEFAULT NULL COMMENT 'Overrides the profile jersey number for this team' AFTER jersey_name,
  ADD COLUMN added_by INT DEFAULT NULL AFTER jersey_number,
  ADD KEY idx_team_status (team_id, status),
  ADD CONSTRAINT fk_tm_added_by FOREIGN KEY (added_by) REFERENCES app_users (id) ON DELETE SET NULL;

-- Two players in a squad may wear the same number.
ALTER TABLE tournament_entry_players DROP INDEX uq_entry_jersey;

-- Teams are found by code; keep the area searchable for later discovery.
ALTER TABLE teams ADD KEY idx_captain_sport (captain_user_id, sport);
