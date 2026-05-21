#!/bin/bash
set -e

# Auto-increment version/build number
python3 "/Users/charlestalk/AntiGravity/workflow-tools/increment_build.py" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# ==============================================================================
# Monitro - Mac App Store (MAS) Build Pipeline
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
APP_NAME="monitro"
TEAM_ID="YOUR_TEAM_ID"
BUNDLE_ID="com.servicerocket.monitro"

# MAS Requires specific Distribution Certificates
DISTRIBUTION_CERT="Apple Distribution: YOUR NAME ($TEAM_ID)"
INSTALLER_CERT="3rd Party Mac Developer Installer: YOUR NAME ($TEAM_ID)"

# Paths
APP_BUNDLE="build/macos/Build/Products/Release/$APP_NAME.app"
ENTITLEMENTS="macos/Runner/Release.mas.entitlements"
INHERIT_ENTITLEMENTS="macos/Runner/Release.mas.inherit.entitlements"
PROVISIONING_PROFILE="embedded.provisionprofile"

echo "========================================"
echo " Preparing Monitro for Mac App Store    "
echo "========================================"

if [ ! -f "$PROVISIONING_PROFILE" ]; then
    echo "[!] ERROR: Mac App Store Provisioning Profile not found!"
    echo "    Please download the profile from the Apple Developer Portal,"
    echo "    rename it to '$PROVISIONING_PROFILE', and place it in the project root."
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Versioning
# ------------------------------------------------------------------------------
echo "Incrementing build number..."
VERSION_STR=$(./scripts/increment_build.sh macos)
BUILD_NAME=$(echo "$VERSION_STR" | cut -d'+' -f1)
BUILD_NUM=$(echo "$VERSION_STR" | cut -d'+' -f2)
echo "Building version: $BUILD_NAME+$BUILD_NUM"

# ------------------------------------------------------------------------------
# 2. Compilation
# ------------------------------------------------------------------------------
echo "Building Flutter macOS app in release mode..."
flutter build macos --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUM"

echo "Compiling background collector..."
dart compile exe backend/bin/monitro_collector.dart -o backend/monitro_collector

# ------------------------------------------------------------------------------
# 3. Bundle Assembly
# ------------------------------------------------------------------------------
echo "Injecting backend collector into App Bundle..."
# Must go in MacOS/ to satisfy Sandbox rules
cp backend/monitro_collector "$APP_BUNDLE/Contents/MacOS/monitro_collector"

echo "Injecting Provisioning Profile..."
cp "$PROVISIONING_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"

# ------------------------------------------------------------------------------
# 4. Deep Signing
# ------------------------------------------------------------------------------
echo "Deep signing libraries and binaries (Inherit Entitlements)..."
# Find and sign all dynamic libraries and the collector binary
find "$APP_BUNDLE" -type f \( -name "*.dylib" -o -name "*.so" \) -exec codesign --force --verify --verbose --sign "$DISTRIBUTION_CERT" --entitlements "$INHERIT_ENTITLEMENTS" --options runtime {} \;
codesign --force --verify --verbose --sign "$DISTRIBUTION_CERT" --entitlements "$INHERIT_ENTITLEMENTS" --options runtime "$APP_BUNDLE/Contents/MacOS/monitro_collector"

echo "Signing the main app bundle (Master Entitlements)..."
codesign --force --verify --verbose --sign "$DISTRIBUTION_CERT" --entitlements "$ENTITLEMENTS" --options runtime "$APP_BUNDLE"

# ------------------------------------------------------------------------------
# 5. Installer Packaging
# ------------------------------------------------------------------------------
echo "Creating the installer package ($APP_NAME.pkg)..."
productbuild \
  --component "$APP_BUNDLE" /Applications \
  --sign "$INSTALLER_CERT" \
  "${APP_NAME}_${BUILD_NAME}+${BUILD_NUM}_macOS.pkg"

echo "Done! Final Verify:"
echo "pkgutil --check-signature ${APP_NAME}_${BUILD_NAME}+${BUILD_NUM}_macOS.pkg"
echo "You can now upload the .pkg using the Transporter app."
