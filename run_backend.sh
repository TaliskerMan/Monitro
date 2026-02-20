#!/usr/bin/env bash
# ==============================================================================
# Monitro — Start the backend collector daemon
# Run from the repo root:  ./run_backend.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
CONFIG="${1:-$SCRIPT_DIR/config/monitro.yaml}"

echo "==> Monitro Backend Collector"

# Verify config exists
if [ ! -f "$CONFIG" ]; then
  echo "✗ Config not found: $CONFIG"
  echo "  Run: cp config/monitro.example.yaml config/monitro.yaml"
  echo "  Then edit config/monitro.yaml and set your DB password."
  exit 1
fi

# Ensure backend dependencies are installed
echo "--> Getting backend dependencies..."
cd "$BACKEND_DIR"
dart pub get --quiet

echo "--> Starting collector (config: $CONFIG)..."
exec dart run bin/monitro_collector.dart --config "$CONFIG"
