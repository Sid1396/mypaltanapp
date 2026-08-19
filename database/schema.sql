-- =============================================================
-- MyPaltan Database Schema
-- Engine  : MySQL 8.0+
-- Created : 2026-05-27
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- OTP sessions (short-lived, cleaned up after verify)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE otp_sessions (
    id         INT          NOT NULL AUTO_INCREMENT,
    phone      VARCHAR(10)  NOT NULL,
    otp_hash   VARCHAR(255) NOT NULL,        -- store hashed, never plain text
    expires_at DATETIME     NOT NULL,
    attempts   TINYINT      NOT NULL DEFAULT 0,
    verified   TINYINT(1)   NOT NULL DEFAULT 0,
    created_at DATETIME     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id),
    INDEX idx_phone   (phone),
    INDEX idx_expires (expires_at)
);

-- ─────────────────────────────────────────────────────────────
-- Users
-- ─────────────────────────────────────────────────────────────
CREATE TABLE app_users (
    id          INT           NOT NULL AUTO_INCREMENT,
    phone       VARCHAR(10)   NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    birthdate   DATE          NOT NULL,
    age         TINYINT       NOT NULL,      -- stored for fast age-range queries
    gender      VARCHAR(30)   NOT NULL,
    pincode     VARCHAR(6)    NOT NULL,
    city        VARCHAR(100)  NOT NULL,
    state       VARCHAR(100)  NOT NULL,
    area        VARCHAR(100)  NOT NULL,
    skill_level ENUM('BEGINNER', 'INTERMEDIATE', 'ADVANCED') NOT NULL DEFAULT 'BEGINNER',
    photo_url   VARCHAR(500)  NULL,
    is_active   TINYINT(1)    NOT NULL DEFAULT 1,
    created_at  DATETIME      NOT NULL DEFAULT NOW(),
    updated_at  DATETIME      NOT NULL DEFAULT NOW() ON UPDATE NOW(),

    PRIMARY KEY (id),
    UNIQUE INDEX idx_phone   (phone),
    INDEX        idx_city    (city),
    INDEX        idx_pincode (pincode),
    INDEX        idx_skill   (skill_level)
);

-- ─────────────────────────────────────────────────────────────
-- User sports (ordered 1–4, rank 1 = primary sport)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE app_user_sports (
    id      INT         NOT NULL AUTO_INCREMENT,
    user_id INT         NOT NULL,
    sport   VARCHAR(50) NOT NULL,
    `rank`  TINYINT     NOT NULL,            -- 1 = primary sport, up to 4

    PRIMARY KEY (id),
    UNIQUE INDEX idx_user_rank  (user_id, `rank`),
    UNIQUE INDEX idx_user_sport (user_id, sport),
    INDEX        idx_sport      (sport),

    CONSTRAINT fk_app_user_sports_user
        FOREIGN KEY (user_id) REFERENCES app_users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
