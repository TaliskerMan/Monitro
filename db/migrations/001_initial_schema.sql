-- Monitro Database Schema
-- Migration: 001_initial_schema
-- Run: mysql -u root < db/migrations/001_initial_schema.sql

CREATE DATABASE IF NOT EXISTS monitro
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE monitro;

-- -----------------------------------------------------------------------
-- System metrics (CPU, memory, load, disk, network — numeric time series)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS metrics (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  collected_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  metric_name   VARCHAR(64)  NOT NULL COMMENT 'e.g. cpu.user, mem.used, net.eth0.rx_bytes',
  value         DOUBLE       NOT NULL,
  label         VARCHAR(128)          COMMENT 'e.g. device name, mount point, interface',
  host          VARCHAR(256)          COMMENT 'hostname (for future multi-host support)',
  INDEX idx_name_time  (metric_name, collected_at),
  INDEX idx_time       (collected_at)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

-- -----------------------------------------------------------------------
-- Process snapshots
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS processes (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  collected_at  DATETIME(3)  NOT NULL,
  pid           INT UNSIGNED NOT NULL,
  ppid          INT UNSIGNED,
  name          VARCHAR(256),
  username      VARCHAR(128),
  cpu_pct       DOUBLE,
  mem_pct       DOUBLE,
  mem_rss_kb    BIGINT,
  state         VARCHAR(16),
  num_threads   INT,
  cmdline       TEXT,
  INDEX idx_time       (collected_at),
  INDEX idx_pid        (pid, collected_at)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

-- -----------------------------------------------------------------------
-- Network connections (netstat snapshot)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS connections (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  collected_at  DATETIME(3)  NOT NULL,
  protocol      VARCHAR(8)   NOT NULL COMMENT 'tcp, udp, tcp6, udp6',
  local_addr    VARCHAR(64),
  local_port    INT UNSIGNED,
  remote_addr   VARCHAR(64),
  remote_port   INT UNSIGNED,
  state         VARCHAR(32)           COMMENT 'ESTABLISHED, LISTEN, TIME_WAIT, etc.',
  pid           INT UNSIGNED,
  process_name  VARCHAR(256),
  INDEX idx_time       (collected_at),
  INDEX idx_port       (local_port, collected_at),
  INDEX idx_state      (state, collected_at)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

-- -----------------------------------------------------------------------
-- User sessions
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_sessions (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  collected_at  DATETIME(3)  NOT NULL,
  username      VARCHAR(128) NOT NULL,
  tty           VARCHAR(64),
  from_host     VARCHAR(256),
  login_time    DATETIME,
  idle_time     VARCHAR(32),
  cpu_time      VARCHAR(32),
  current_cmd   VARCHAR(512),
  INDEX idx_time       (collected_at),
  INDEX idx_user       (username, collected_at)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------
-- Outbound API / HTTP call tracking (per-process)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_calls (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  collected_at  DATETIME(3)  NOT NULL,
  pid           INT UNSIGNED,
  process_name  VARCHAR(256),
  username      VARCHAR(128),
  dest_host     VARCHAR(256),
  dest_port     INT UNSIGNED,
  protocol      VARCHAR(8),
  call_count    INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Connections opened in this interval',
  INDEX idx_time       (collected_at),
  INDEX idx_process    (process_name, collected_at)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

-- -----------------------------------------------------------------------
-- Alert events
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alert_events (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  triggered_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  metric_name   VARCHAR(64)  NOT NULL,
  value         DOUBLE,
  threshold     DOUBLE,
  severity      ENUM('info', 'warning', 'critical') NOT NULL DEFAULT 'warning',
  message       TEXT,
  acknowledged  BOOLEAN NOT NULL DEFAULT FALSE,
  INDEX idx_time       (triggered_at),
  INDEX idx_metric     (metric_name, triggered_at)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------
-- Configuration key-value store (runtime settings)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS config (
  key_name      VARCHAR(128) PRIMARY KEY,
  value         TEXT,
  description   VARCHAR(512),
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Insert default config values
INSERT IGNORE INTO config (key_name, value, description) VALUES
  ('collection_interval_seconds', '5',  'How often the collector polls system metrics'),
  ('retention_days',              '30', 'Days of metric history to retain'),
  ('alert_email',                 '',   'Email address for alert notifications (optional)'),
  ('version',                     '1',  'Schema version');
