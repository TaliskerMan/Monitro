#!/bin/bash
# Monitro First-Run Database Setup
# Creates the monitro database and user in MariaDB, generates a secure password,
# and writes the credentials into /opt/monitro/config/monitro.yaml.
#
# This script is idempotent — it will skip setup if the database already exists.

set -e

CONFIG_FILE="/opt/monitro/config/monitro.yaml"
MARKER_FILE="/opt/monitro/.db_initialized"
LOG_FILE="/var/log/monitro-collector.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB-SETUP: $1" | tee -a "$LOG_FILE"
}

# Skip if already initialized
if [ -f "$MARKER_FILE" ]; then
  log "Database already initialized (marker found). Skipping setup."
  exit 0
fi

# Check if MariaDB is running
if ! systemctl is-active --quiet mariadb; then
  log "WARNING: MariaDB is not running. Attempting to start it..."
  systemctl start mariadb || {
    log "ERROR: Could not start MariaDB. Please install and start MariaDB first."
    log "  Run: sudo apt install mariadb-server && sudo systemctl start mariadb"
    exit 1
  }
fi

# Generate a secure random password
DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
DB_NAME="monitro"
DB_USER="monitro_user"

log "Creating database '$DB_NAME' and user '$DB_USER'..."

# Create database and user (idempotent — uses IF NOT EXISTS)
# Note: this script runs as root during dpkg postinst, so unix socket auth works
mysql <<EOF 2>>"$LOG_FILE"
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
DROP USER IF EXISTS '${DB_USER}'@'localhost';
DROP USER IF EXISTS '${DB_USER}'@'127.0.0.1';
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

if [ $? -ne 0 ]; then
  log "ERROR: Failed to create database or user. Check MariaDB root access."
  log "  You may need to run: sudo mariadb-secure-installation"
  exit 1
fi

log "Database and user created successfully."

# Update the config file with the generated credentials
if [ -f "$CONFIG_FILE" ]; then
  # Use sed to replace the password line
  sed -i "s|^  password:.*|  password: \"${DB_PASSWORD}\"|" "$CONFIG_FILE"
  sed -i "s|^  name:.*|  name: ${DB_NAME}|" "$CONFIG_FILE"
  sed -i "s|^  user:.*|  user: ${DB_USER}|" "$CONFIG_FILE"
  log "Updated $CONFIG_FILE with database credentials."
else
  log "WARNING: Config file not found at $CONFIG_FILE"
fi

# Create the marker so we don't re-run on upgrades
touch "$MARKER_FILE"
log "First-run database setup complete."
