#!/bin/bash
set -e
VERSION="1.0.0"

# Require create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "create-dmg could not be found. Please install it with 'brew install create-dmg'"
    exit 1
fi

echo "Incrementing build number..."
chmod +x scripts/increment_build.sh
VERSION=$(./scripts/increment_build.sh macos)
echo "Building version: $VERSION"

BUILD_NAME="${VERSION%+*}"
BUILD_NUMBER="${VERSION#*+}"

echo "Building Flutter UI for macOS..."
flutter build macos --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

echo "Building backend..."
cd backend
dart pub get
dart compile exe bin/monitro_collector.dart -o monitro_collector
cd ..

APP_BUNDLE="build/macos/Build/Products/Release/monitro.app"

echo "Signing backend with sandbox inherit entitlements..."
codesign --force --entitlements macos/Runner/Backend.entitlements --sign - backend/monitro_collector

# Embed the collector inside the app bundle's MacOS directory (required by Sandbox)
cp backend/monitro_collector "${APP_BUNDLE}/Contents/MacOS/monitro_collector"

# Embed SSL certificates inside the app bundle
mkdir -p "${APP_BUNDLE}/Contents/Resources/certs"
cp certs/* "${APP_BUNDLE}/Contents/Resources/certs/"

# Ensure embedded certs have read permissions
chmod 644 "${APP_BUNDLE}/Contents/Resources/certs"/*

# Ad-hoc sign the app bundle to repair its seal after injecting assets
echo "Re-signing modified application bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# Make DMG
DMG_NAME="Monitro_${VERSION}_macOS.dmg"
rm -f "$DMG_NAME"
create-dmg \
  --volname "Monitro Installer" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "monitro.app" 150 190 \
  --hide-extension "monitro.app" \
  --app-drop-link 450 190 \
  "$DMG_NAME" \
  "$APP_BUNDLE"

echo "Created $DMG_NAME"
