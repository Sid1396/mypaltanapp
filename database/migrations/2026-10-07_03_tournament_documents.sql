USE mypaltan_db;

-- Organizer uploads (flyer, rules, schedule, other). Visible to anyone who can see the tournament.
CREATE TABLE tournament_documents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tournament_id INT NOT NULL,
  doc_type ENUM('FLYER','RULES','SCHEDULE','OTHER') NOT NULL,
  title VARCHAR(100) NOT NULL,
  file_key VARCHAR(255) NOT NULL,
  mime_type ENUM('application/pdf','image/jpeg','image/png') NOT NULL,
  size_bytes INT NOT NULL,
  sort_order TINYINT NOT NULL DEFAULT 0,
  uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_t (tournament_id),
  CONSTRAINT chk_td_size CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  CONSTRAINT fk_td_t FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
