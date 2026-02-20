-- Monitro: API call tracking table
-- Migration: 002_api_calls
-- (Included in 001 initial schema — this file is kept for reference)

USE monitro;

-- Tracks per-interval connection rates for outbound API/HTTP calls
-- grouped by process to surface heavy callers.
-- Already created in 001_initial_schema.sql

-- Add index to speed up "top callers" query
ALTER TABLE api_calls
  ADD INDEX idx_dest (dest_host, dest_port, collected_at);
