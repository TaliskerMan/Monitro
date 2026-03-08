#!/bin/bash
set -e

# Configuration
APP_NAME="monitro"
TEAM_ID="YOUR_TEAM_ID"
DISTRIBUTION_CERT="Apple Distribution: YOUR NAME ($TEAM_ID)"
INSTALLER_CERT="3rd Party Mac Developer Installer: YOUR NAME ($TEAM_ID)"

echo "Building Flutter macOS app in release mode..."
flutter build macos --release

APP_BUNDLE="build/macos/Build/Products/Release/$APP_NAME.app"

echo "Deep signing libraries..."
# Sign all dylib and so files with the inherit entitlements
find "$APP_BUNDLE" -type f \( -name "*.dylib" -o -name "*.so" \) -exec codesign --force --verify --verbose --sign "$DISTRIBUTION_CERT" --entitlements macos/Runner/Release.entitlements --options runtime {} \;

echo "Signing the main app bundle..."
codesign --force --verify --verbose --sign "$DISTRIBUTION_CERT" --entitlements macos/Runner/Release.entitlements --options runtime "$APP_BUNDLE"

echo "Creating the installer package..."
productbuild \
  --component "$APP_BUNDLE" /Applications \
  --sign "$INSTALLER_CERT" \
  "$APP_NAME.pkg"

echo "Done! You can verify the signature with: pkgutil --check-signature $APP_NAME.pkg"
