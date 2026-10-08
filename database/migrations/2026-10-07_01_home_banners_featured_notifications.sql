USE mypaltan_db;

CREATE TABLE featured_tournaments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(40) NOT NULL,
  name VARCHAR(100) NOT NULL,
  sport ENUM('CRICKET','FOOTBALL','BADMINTON','PICKLEBALL') NOT NULL,
  logo_url VARCHAR(500) NULL,
  start_date DATE NULL,
  area VARCHAR(100) NULL,
  city VARCHAR(50) NOT NULL DEFAULT 'Mumbai',
  tags JSON NULL,
  status ENUM('COMING_SOON','REGISTRATION_OPEN','REGISTRATION_CLOSED','LIVE','COMPLETED') NOT NULL DEFAULT 'COMING_SOON',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_slug (slug),
  KEY idx_active_order (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE home_banners (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(80) NOT NULL,
  subtitle VARCHAR(160) NULL,
  badge VARCHAR(30) NULL,
  image_url VARCHAR(500) NULL,
  theme ENUM('ORANGE','DARK') NOT NULL DEFAULT 'ORANGE',
  cta_label VARCHAR(30) NULL,
  link_type ENUM('NONE','TOURNAMENT','URL') NOT NULL DEFAULT 'NONE',
  link_value VARCHAR(255) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  starts_at DATETIME NULL,
  ends_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_active_order (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  type VARCHAR(30) NOT NULL,
  title VARCHAR(120) NOT NULL,
  body VARCHAR(300) NULL,
  data JSON NULL,
  read_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user_created (user_id, created_at),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO featured_tournaments (slug, name, sport, logo_url, start_date, area, tags, status, sort_order) VALUES
 ('sai-siddhi-premier-league', 'Sai Siddhi Premier League', 'CRICKET', 'https://mypaltan.com/leagues/sspl.jpg', '2027-01-10', 'Charkop, Kandivali', JSON_ARRAY('Cricket league'), 'COMING_SOON', 1),
 ('gc-premier-league-s5', 'GC Premier League', 'CRICKET', 'https://mypaltan.com/leagues/gc.jpg', '2027-02-07', 'Gorai, Kandivali', JSON_ARRAY('Season 5'), 'COMING_SOON', 2),
 ('rada-radi-premiere-league-5', 'Rada Radi Premiere League', 'CRICKET', 'https://mypaltan.com/leagues/rpl.jpg', NULL, 'Charkop, Kandivali', JSON_ARRAY('Season 5.0', 'Warriors assemble'), 'COMING_SOON', 3),
 ('blue-ocean-premier-league', 'Blue Ocean Premier League', 'CRICKET', 'https://mypaltan.com/leagues/bopl.jpg', NULL, 'Gorai, Kandivali', JSON_ARRAY('Cricket league'), 'COMING_SOON', 4);

INSERT INTO home_banners (title, subtitle, badge, image_url, theme, cta_label, link_type, link_value, sort_order) VALUES
 ('Sai Siddhi Premier League', 'Charkop, Kandivali · Starts 10 Jan', 'Upcoming', 'https://mypaltan.com/leagues/sspl.jpg', 'DARK', 'View', 'TOURNAMENT', 'sai-siddhi-premier-league', 1),
 ('Every match counts', 'Tournaments, live scores and stats. Free for everyone, no ads.', 'MyPaltan', NULL, 'ORANGE', NULL, 'NONE', NULL, 2),
 ('GC Premier League · Season 5', 'Gorai, Kandivali · Starts 7 Feb', 'Upcoming', 'https://mypaltan.com/leagues/gc.jpg', 'DARK', 'View', 'TOURNAMENT', 'gc-premier-league-s5', 3);

SELECT id, slug, name, start_date, status FROM featured_tournaments ORDER BY sort_order;
SELECT id, title, theme, link_type FROM home_banners ORDER BY sort_order;

-- Applied afterwards: logos moved to the private B2 bucket (league_logos/<slug>.jpg)
ALTER TABLE featured_tournaments ADD COLUMN logo_key VARCHAR(255) NULL AFTER logo_url;
ALTER TABLE home_banners ADD COLUMN image_key VARCHAR(255) NULL AFTER image_url;
UPDATE featured_tournaments SET logo_key = CONCAT('league_logos/', slug, '.jpg'), logo_url = NULL;
UPDATE home_banners b JOIN featured_tournaments t ON t.slug = b.link_value SET b.image_key = t.logo_key, b.image_url = NULL WHERE b.link_type = 'TOURNAMENT';
