-- Inventory D1 Schema
-- Run: wrangler d1 execute inventory-db --file=schema.sql

CREATE TABLE IF NOT EXISTS products (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  sku          TEXT,
  barcode      TEXT,
  category     TEXT,
  unit         TEXT DEFAULT 'db',
  min_stock    REAL DEFAULT 0,
  current_stock REAL DEFAULT 0,
  price        REAL DEFAULT 0,
  location     TEXT,
  note         TEXT,
  created_at   TEXT,
  updated_at   TEXT,
  deleted      INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS transactions (
  id            TEXT PRIMARY KEY,
  product_id    TEXT NOT NULL,
  product_name  TEXT,
  type          TEXT NOT NULL,
  quantity      REAL NOT NULL,
  note          TEXT,
  delivery_note TEXT,
  timestamp     TEXT NOT NULL,
  user          TEXT,
  stock_before  REAL DEFAULT 0,
  stock_after   REAL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_transactions_product ON transactions(product_id);
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp);
CREATE INDEX IF NOT EXISTS idx_products_updated ON products(updated_at);
