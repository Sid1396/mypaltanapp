USE mypaltan_db;
DROP PROCEDURE IF EXISTS sp_save_tournament;
DELIMITER $$

-- Creates (p_code not found) or updates a tournament owned by p_phone from one JSON document,
-- replacing rules, grounds, UPI details and documents in a single transaction.
-- Once a team is approved (i.e. has paid), sport, dates, format and fees are frozen and
-- max_teams cannot drop below the number of approved teams.
-- p_data is validated by the n8n workflow before it gets here.
CREATE PROCEDURE sp_save_tournament(IN p_phone CHAR(10), IN p_code CHAR(6), IN p_data JSON)
BEGIN
  DECLARE v_user INT;
  DECLARE v_tid INT;
  DECLARE v_owner INT;
  DECLARE v_status VARCHAR(30);
  DECLARE v_approved INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  SELECT id INTO v_user FROM app_users WHERE phone = p_phone;
  IF v_user IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USER_NOT_FOUND'; END IF;
  IF (SELECT COUNT(*) FROM JSON_TABLE(p_data, '$.sponsors[*]' COLUMNS (t TINYINT PATH '$.is_title')) AS x WHERE x.t = 1) > 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ONE_TITLE_SPONSOR';
  END IF;

  START TRANSACTION;
  SELECT id, organizer_user_id, status INTO v_tid, v_owner, v_status FROM tournaments WHERE code = p_code FOR UPDATE;

  IF v_tid IS NULL THEN
    INSERT INTO tournaments (code, organizer_user_id, sport, name, description, logo_key, banner_key, category, city, area,
      start_date, end_date, match_days, match_timing, format, group_count, qualify_per_group, max_teams, squad_min, squad_max,
      entry_fee, jersey_fee, prize_type, prize_details, food_provided, meals, jersey_provided, jersey_print,
      registration_deadline, checklist_deadline)
    VALUES (p_code, v_user,
      p_data->>'$.sport', p_data->>'$.name', NULLIF(p_data->>'$.description', 'null'), p_data->>'$.logo_key',
      NULLIF(p_data->>'$.banner_key', 'null'), p_data->>'$.category', p_data->>'$.city', p_data->>'$.area',
      p_data->>'$.start_date', p_data->>'$.end_date', p_data->>'$.match_days', p_data->>'$.match_timing', p_data->>'$.format',
      NULLIF(p_data->>'$.group_count', 'null'), NULLIF(p_data->>'$.qualify_per_group', 'null'),
      p_data->>'$.max_teams', p_data->>'$.squad_min', p_data->>'$.squad_max',
      p_data->>'$.entry_fee', p_data->>'$.jersey_fee', p_data->>'$.prize_type', NULLIF(p_data->>'$.prize_details', 'null'),
      p_data->>'$.food_provided', NULLIF(p_data->>'$.meals', ''), p_data->>'$.jersey_provided', NULLIF(p_data->>'$.jersey_print', 'null'),
      p_data->>'$.registration_deadline', NULLIF(p_data->>'$.checklist_deadline', 'null'));
    SET v_tid = LAST_INSERT_ID();
  ELSE
    IF v_owner <> v_user THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NOT_OWNER'; END IF;
    IF v_status NOT IN ('DRAFT', 'REGISTRATION_OPEN') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LOCKED'; END IF;
    SELECT COUNT(*) INTO v_approved FROM tournament_entries WHERE tournament_id = v_tid AND status = 'APPROVED';
    IF v_approved > 0 AND EXISTS (
         SELECT 1 FROM tournaments t WHERE t.id = v_tid AND NOT (
               t.sport = p_data->>'$.sport'
           AND t.format = p_data->>'$.format'
           AND t.start_date = CAST(p_data->>'$.start_date' AS DATE)
           AND t.end_date = CAST(p_data->>'$.end_date' AS DATE)
           AND t.entry_fee = CAST(p_data->>'$.entry_fee' AS UNSIGNED)
           AND t.jersey_fee = CAST(p_data->>'$.jersey_fee' AS UNSIGNED)
           AND t.group_count <=> CAST(NULLIF(p_data->>'$.group_count', 'null') AS UNSIGNED)
           AND t.qualify_per_group <=> CAST(NULLIF(p_data->>'$.qualify_per_group', 'null') AS UNSIGNED))) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'TEAMS_APPROVED';
    END IF;
    IF CAST(p_data->>'$.max_teams' AS UNSIGNED) < v_approved THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MAX_TEAMS_TOO_LOW'; END IF;
    UPDATE tournaments SET
      sport = p_data->>'$.sport', name = p_data->>'$.name', description = NULLIF(p_data->>'$.description', 'null'),
      logo_key = p_data->>'$.logo_key', banner_key = NULLIF(p_data->>'$.banner_key', 'null'), category = p_data->>'$.category',
      city = p_data->>'$.city', area = p_data->>'$.area', start_date = p_data->>'$.start_date', end_date = p_data->>'$.end_date',
      match_days = p_data->>'$.match_days', match_timing = p_data->>'$.match_timing', format = p_data->>'$.format',
      group_count = NULLIF(p_data->>'$.group_count', 'null'), qualify_per_group = NULLIF(p_data->>'$.qualify_per_group', 'null'),
      max_teams = p_data->>'$.max_teams', squad_min = p_data->>'$.squad_min', squad_max = p_data->>'$.squad_max',
      entry_fee = p_data->>'$.entry_fee', jersey_fee = p_data->>'$.jersey_fee', prize_type = p_data->>'$.prize_type',
      prize_details = NULLIF(p_data->>'$.prize_details', 'null'), food_provided = p_data->>'$.food_provided',
      meals = NULLIF(p_data->>'$.meals', ''), jersey_provided = p_data->>'$.jersey_provided',
      jersey_print = NULLIF(p_data->>'$.jersey_print', 'null'), registration_deadline = p_data->>'$.registration_deadline',
      checklist_deadline = NULLIF(p_data->>'$.checklist_deadline', 'null')
    WHERE id = v_tid;
  END IF;

  REPLACE INTO tournament_rules (tournament_id, match_rules, points)
  VALUES (v_tid, JSON_EXTRACT(p_data, '$.match_rules'), JSON_EXTRACT(p_data, '$.points'));

  DELETE FROM tournament_grounds WHERE tournament_id = v_tid;
  INSERT INTO tournament_grounds (tournament_id, name)
  SELECT v_tid, g.name FROM JSON_TABLE(p_data, '$.grounds[*]' COLUMNS (name VARCHAR(100) PATH '$')) AS g;

  IF JSON_TYPE(JSON_EXTRACT(p_data, '$.payment')) = 'OBJECT' THEN
    REPLACE INTO tournament_payment_details (tournament_id, upi_id, upi_name, qr_key, accept_cash, note)
    VALUES (v_tid, p_data->>'$.payment.upi_id', p_data->>'$.payment.upi_name', NULLIF(p_data->>'$.payment.qr_key', 'null'),
            p_data->>'$.payment.accept_cash', NULLIF(p_data->>'$.payment.note', 'null'));
  ELSE
    DELETE FROM tournament_payment_details WHERE tournament_id = v_tid;
  END IF;

  DELETE FROM tournament_documents WHERE tournament_id = v_tid;
  INSERT INTO tournament_documents (tournament_id, doc_type, title, file_key, mime_type, size_bytes, sort_order)
  SELECT v_tid, d.doc_type, d.title, d.file_key, d.mime_type, d.size_bytes, d.ord
    FROM JSON_TABLE(p_data, '$.documents[*]' COLUMNS (
      ord FOR ORDINALITY,
      doc_type VARCHAR(10) PATH '$.doc_type',
      title VARCHAR(100) PATH '$.title',
      file_key VARCHAR(255) PATH '$.file_key',
      mime_type VARCHAR(30) PATH '$.mime_type',
      size_bytes INT PATH '$.size_bytes')) AS d;

  -- Sponsors: replaced as a list. Existing rows are matched by id so their view/tap stats survive edits.
  DELETE FROM tournament_sponsors
   WHERE tournament_id = v_tid
     AND id NOT IN (SELECT x.sid FROM JSON_TABLE(p_data, '$.sponsors[*]' COLUMNS (sid INT PATH '$.id')) AS x WHERE x.sid IS NOT NULL);
  UPDATE tournament_sponsors s
    JOIN JSON_TABLE(p_data, '$.sponsors[*]' COLUMNS (
           ord FOR ORDINALITY, sid INT PATH '$.id', name VARCHAR(80) PATH '$.name', label VARCHAR(40) PATH '$.label',
           is_title TINYINT PATH '$.is_title', logo_key VARCHAR(255) PATH '$.logo_key', banner_key VARCHAR(255) PATH '$.banner_key',
           link_url VARCHAR(255) PATH '$.link_url', tagline VARCHAR(80) PATH '$.tagline')) AS j ON j.sid = s.id
     SET s.name = j.name, s.label = j.label, s.is_title = j.is_title, s.logo_key = j.logo_key, s.banner_key = j.banner_key,
         s.link_url = j.link_url, s.tagline = j.tagline, s.sort_order = j.ord
   WHERE s.tournament_id = v_tid;
  INSERT INTO tournament_sponsors (tournament_id, name, label, is_title, logo_key, banner_key, link_url, tagline, sort_order)
  SELECT v_tid, j.name, j.label, j.is_title, j.logo_key, j.banner_key, j.link_url, j.tagline, j.ord
    FROM JSON_TABLE(p_data, '$.sponsors[*]' COLUMNS (
           ord FOR ORDINALITY, sid INT PATH '$.id', name VARCHAR(80) PATH '$.name', label VARCHAR(40) PATH '$.label',
           is_title TINYINT PATH '$.is_title', logo_key VARCHAR(255) PATH '$.logo_key', banner_key VARCHAR(255) PATH '$.banner_key',
           link_url VARCHAR(255) PATH '$.link_url', tagline VARCHAR(80) PATH '$.tagline')) AS j
   WHERE j.sid IS NULL;

  COMMIT;
END$$
DELIMITER ;

GRANT EXECUTE ON PROCEDURE mypaltan_db.sp_save_tournament TO 'mypaltan_app'@'%';
