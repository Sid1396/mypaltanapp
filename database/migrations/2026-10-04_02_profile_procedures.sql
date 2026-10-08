USE mypaltan_db;
DROP PROCEDURE IF EXISTS sp_refresh_profile_complete;
DROP PROCEDURE IF EXISTS sp_save_profile;
DROP PROCEDURE IF EXISTS sp_set_photo;
DELIMITER $$

-- Marks a profile complete only when every required piece (incl. photo and at least one sport) is present
CREATE PROCEDURE sp_refresh_profile_complete(IN p_user_id INT)
BEGIN
  UPDATE app_users u
     SET u.profile_complete = (u.name IS NOT NULL AND u.birthdate IS NOT NULL AND u.gender IS NOT NULL
                               AND u.jersey_name IS NOT NULL AND u.jersey_number IS NOT NULL AND u.jersey_size IS NOT NULL
                               AND u.photo_key IS NOT NULL
                               AND EXISTS (SELECT 1 FROM app_user_sports s WHERE s.user_id = u.id))
   WHERE u.id = p_user_id;
END$$

-- Saves profile fields and (optionally) the full sports list in one transaction.
-- NULL parameters leave the existing value unchanged, so the same procedure serves signup and later edits.
CREATE PROCEDURE sp_save_profile(
  IN p_phone CHAR(10), IN p_name VARCHAR(50), IN p_birthdate DATE, IN p_gender VARCHAR(12),
  IN p_jersey_name VARCHAR(12), IN p_jersey_number INT, IN p_jersey_size VARCHAR(4), IN p_sports JSON)
BEGIN
  DECLARE v_user INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  INSERT INTO app_users (phone) VALUES (p_phone) ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id);
  SET v_user = LAST_INSERT_ID();

  UPDATE app_users
     SET name          = COALESCE(p_name, name),
         birthdate     = COALESCE(p_birthdate, birthdate),
         gender        = COALESCE(p_gender, gender),
         jersey_name   = COALESCE(p_jersey_name, jersey_name),
         jersey_number = COALESCE(p_jersey_number, jersey_number),
         jersey_size   = COALESCE(p_jersey_size, jersey_size)
   WHERE id = v_user;

  IF p_sports IS NOT NULL THEN
    DELETE FROM app_user_sports WHERE user_id = v_user;
    INSERT INTO app_user_sports (user_id, sport, role, batting_hand, bowling_style, `rank`)
    SELECT v_user, j.sport, j.role, j.batting_hand, j.bowling_style, j.ord
      FROM JSON_TABLE(p_sports, '$[*]' COLUMNS (
             ord FOR ORDINALITY,
             sport VARCHAR(12) PATH '$.sport',
             role VARCHAR(20) PATH '$.role',
             batting_hand VARCHAR(5) PATH '$.batting_hand',
             bowling_style VARCHAR(5) PATH '$.bowling_style')) AS j;
  END IF;

  CALL sp_refresh_profile_complete(v_user);
  COMMIT;
END$$

-- Stores the uploaded photo's storage key and re-checks completeness
CREATE PROCEDURE sp_set_photo(IN p_phone CHAR(10), IN p_photo_key VARCHAR(255))
BEGIN
  DECLARE v_user INT;
  SELECT id INTO v_user FROM app_users WHERE phone = p_phone;
  IF v_user IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USER_NOT_FOUND';
  END IF;
  UPDATE app_users SET photo_key = p_photo_key WHERE id = v_user;
  CALL sp_refresh_profile_complete(v_user);
END$$
DELIMITER ;

GRANT EXECUTE ON PROCEDURE mypaltan_db.sp_save_profile TO 'mypaltan_app'@'%';
GRANT EXECUTE ON PROCEDURE mypaltan_db.sp_set_photo TO 'mypaltan_app'@'%';
