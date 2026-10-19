-- Partner-league forms: the owner can change the payment QR, UPI ID and payee name from the admin portal.
-- No row means the website shows its built-in payment details.
CREATE TABLE event_payment_settings (
  event_slug  VARCHAR(30)  NOT NULL PRIMARY KEY,
  upi_id      VARCHAR(100) NOT NULL,
  upi_name    VARCHAR(60)  NOT NULL,
  qr_key      VARCHAR(255) NOT NULL,
  updated_by  INT UNSIGNED NULL,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
