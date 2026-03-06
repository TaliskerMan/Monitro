-- Monitro Database Schema Migration
-- Migration: 002_create_alert_events
-- Run: mariadb_service.dart runs this automatically

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
