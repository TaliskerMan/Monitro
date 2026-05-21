#!/usr/bin/env bash
# Monitro Release Builder for macOS
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Auto-increment version/build number
python3 "/Users/charlestalk/AntiGravity/workflow-tools/increment_build.py" "${SCRIPT_DIR:-.}"

cd "${SCRIPT_DIR}"

echo "==> Auto-incrementing build number..."
current_version=$(grep '^version: ' pubspec.yaml | awk '{print $2}' | tr -d '\r')
if [[ "$current_version" == *"+"* ]]; then
    base_version=$(echo "$current_version" | cut -d'+' -f1)
    build_num=$(echo "$current_version" | cut -d'+' -f2)
    new_build_num=$((build_num + 1))
else
    base_version="$current_version"
    new_build_num=1
fi
FULL_VERSION="${base_version}+${new_build_num}"

# Update the pubspec pipeline
sed -i '' "s/^version: .*/version: $FULL_VERSION/" pubspec.yaml
echo "    Upgraded Monitro to Version $FULL_VERSION"

PKG_NAME="monitro"
FLUTTER="flutter"
ARTIFACTS="${SCRIPT_DIR}/packaging/macos_build/artifacts"
BUILD_DIR="${SCRIPT_DIR}/build/macos/Build/Products/Release"
STAGING_DIR="${SCRIPT_DIR}/packaging/macos_build/staging"

echo "==> Monitro macOS Release Builder v${FULL_VERSION}"
mkdir -p "${ARTIFACTS}"
mkdir -p "${STAGING_DIR}"

echo "==> Building Flutter macOS release..."
"${FLUTTER}" clean
"${FLUTTER}" build macos --release

echo "==> Preparing App Bundle..."
rm -rf "${STAGING_DIR}/Monitro.app"
# Xcode generates lowercase "monitro.app" natively
cp -r "${BUILD_DIR}/monitro.app" "${STAGING_DIR}/Monitro.app" || cp -r "${BUILD_DIR}/Monitro.app" "${STAGING_DIR}/Monitro.app"

echo "==> Creating DMG..."
DMG_FILE="${ARTIFACTS}/${PKG_NAME}_${FULL_VERSION}_macos.dmg"
rm -f "${DMG_FILE}"

if command -v hdiutil > /dev/null 2>&1; then
    # Create the standard macOS Applications folder shortcut 
    # to allow the user to drag the app to install it
    ln -sf /Applications "${STAGING_DIR}/Applications"

    if ! command -v create-dmg &> /dev/null; then
    echo "create-dmg not found. Attempting to install via Homebrew..."
    brew install create-dmg
fi

create-dmg \
  --volname "Monitro" \
  --volicon "${STAGING_DIR}/Monitro.app/Contents/Resources/AppIcon.icns" \
  --background "/Users/charlestalk/AntiGravity/workflow-tools/macos/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 120 \
  --icon "Monitro.app" 150 190 \
  --hide-extension "Monitro.app" \
  --app-drop-link 450 185 \
  "${DMG_FILE}" \
  "${STAGING_DIR}"/ || true

if [ ! -f "${DMG_FILE}" ]; then
    echo "Fallback to hdiutil"
    hdiutil create -volname "Monitro" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_FILE}" > /dev/null
fi
else
    echo "    WARNING: hdiutil not found - skipping DMG creation"
    ZIP_FILE="${ARTIFACTS}/${PKG_NAME}_${FULL_VERSION}_macos.zip"
    cd "${STAGING_DIR}"
    zip -r "${ZIP_FILE}" "Monitro.app"
    cd "${SCRIPT_DIR}"
fi

echo "==> macOS Signing"
# Authenticate automatically since script runs natively in user's terminal
SIGNING_IDENTITY="Developer ID Application: Charles Talk (89B5GL8WMK)"

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "    Found Developer Identity: $SIGNING_IDENTITY"
    
    echo "    Re-structuring dynamically generated Flutter frameworks to comply with Apple's symlink codesign standards..."
    for framework in "${STAGING_DIR}/Monitro.app/Contents/Frameworks/"*.framework; do
        if [ -d "$framework" ]; then
            binary_name=$(basename "$framework" .framework)
            if [ -f "$framework/$binary_name" ] && [ ! -L "$framework/$binary_name" ]; then
                echo "      -> Fixing $binary_name framework tree"
                mkdir -p "$framework/Versions/A"
                mv "$framework/$binary_name" "$framework/Versions/A/"
                
                if [ -d "$framework/Resources" ] && [ ! -L "$framework/Resources" ]; then
                    if [ -d "$framework/Versions/A/Resources" ]; then
                        cp -R "$framework/Resources/"* "$framework/Versions/A/Resources/" 2>/dev/null || true
                        rm -rf "$framework/Resources"
                    else
                        mv "$framework/Resources" "$framework/Versions/A/" 2>/dev/null || true
                    fi
                fi
                
                rm -rf "$framework/Versions/Current" "$framework/Resources" "$framework/$binary_name"
                ln -sf "A" "$framework/Versions/Current"
                ln -sf "Versions/Current/Resources" "$framework/Resources"
                ln -sf "Versions/Current/$binary_name" "$framework/$binary_name"
            fi
        fi
    done
    
    echo "    Cleaning xattr and DS_Store properties to prevent ambiguous bundle format errors..."
    xattr -cr "${STAGING_DIR}/Monitro.app" || true
    find "${STAGING_DIR}/Monitro.app" -name ".DS_Store" -delete
    
    echo "    Applying deep code signature to Monitro.app..."
    codesign --deep --force --options runtime --timestamp --entitlements "${SCRIPT_DIR}/macos/Runner/Release.entitlements" -s "$SIGNING_IDENTITY" "${STAGING_DIR}/Monitro.app"
    
    echo "    Re-packaging newly signed DMG..."
    rm -f "${DMG_FILE}"
    if ! command -v create-dmg &> /dev/null; then
    echo "create-dmg not found. Attempting to install via Homebrew..."
    brew install create-dmg
fi

create-dmg \
  --volname "Monitro" \
  --volicon "${STAGING_DIR}/Monitro.app/Contents/Resources/AppIcon.icns" \
  --background "/Users/charlestalk/AntiGravity/workflow-tools/macos/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 120 \
  --icon "Monitro.app" 150 190 \
  --hide-extension "Monitro.app" \
  --app-drop-link 450 185 \
  "${DMG_FILE}" \
  "${STAGING_DIR}"/ || true

if [ ! -f "${DMG_FILE}" ]; then
    echo "Fallback to hdiutil"
    hdiutil create -volname "Monitro" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_FILE}" > /dev/null
fi
    
    echo "==> Apple Notarization"
    echo "    Submitting ${DMG_FILE} to Apple for Notarization..."
        echo "    Applying code signature to DMG wrapper..."
    codesign --sign "$SIGNING_IDENTITY" "${DMG_FILE}"

    if xcrun notarytool submit "${DMG_FILE}" --keychain-profile "AC_PASSWORD" --wait; then
        xcrun stapler staple "${DMG_FILE}"

                DMG_BASENAME=$(basename "${DMG_FILE}" .dmg)

                APP_NAME_EXTRACTED=$(echo "$DMG_BASENAME" | cut -d'_' -f1)

                VERSION_EXTRACTED=$(echo "$DMG_BASENAME" | cut -d'_' -f2)

                DATE_STR=$(date +%-m-%-d-%Y)

                LEMON_DIR="/Users/charlestalk/AntiGravity/LemonSqueezy/${APP_NAME_EXTRACTED}${DATE_STR}${VERSION_EXTRACTED}"

                mkdir -p "${LEMON_DIR}"

                cp "${DMG_FILE}" "${LEMON_DIR}/"

                echo "    Copied notarized DMG to LemonSqueezy: ${LEMON_DIR}"
        echo "    Notarization and Stapling complete!"
    else
        echo "    Error: Apple Notarization failed."
        exit 1
    fi
else
    echo "    WARNING: Could not find a valid 'Developer ID Application' certificate in your keychain."
    echo "    The app will remain ad-hoc signed."
fi

echo ""
echo "==================================="
echo "  Build complete! Version: $FULL_VERSION"
echo "==================================="
