#!/bin/bash
set -e
# ── Auto-increment version ──────────────────────────────────────────
# Read current version from pubspec.yaml (the single source of truth)
echo "Incrementing linux build..."
chmod +x scripts/increment_build.sh
VERSION=$(./scripts/increment_build.sh linux)
BUILD_NAME="${VERSION%+*}"
BUILD_NUMBER="${VERSION#*+}"

ARCH=$(dpkg --print-architecture)
DEBFULLNAME="Chuck Talk"
DEBEMAIL="chuck@nordheim.online"
PACKAGE_NAME="monitro_${VERSION}_${ARCH}"

# Fix clang++ linker issue on some arm64/Linux environments
if [ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [ -d "/usr/include/c++/13" ]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

UNAME_M=$(uname -m)
if [ "$UNAME_M" = "x86_64" ]; then
    FLUTTER_ARCH="x64"
elif [ "$UNAME_M" = "aarch64" ]; then
    FLUTTER_ARCH="arm64"
else
    FLUTTER_ARCH="$UNAME_M"
fi

BUILD_DIR="build/linux/deb/${PACKAGE_NAME}"

# Build flutter
echo "Building Flutter Desktop for Linux..."
flutter build linux --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

# Build backend
cd backend
dart pub get
dart compile exe bin/monitro_collector.dart -o monitro_collector
cd ..

echo "==> Generating SBOM via Syft..."
SYFT_BIN="syft"
if ! command -v syft &> /dev/null; then
    if [ -f "${HOME}/.local/bin/syft" ]; then
        SYFT_BIN="${HOME}/.local/bin/syft"
    elif [ -f "./syft" ]; then
        SYFT_BIN="./syft"
    fi
fi
if command -v "${SYFT_BIN}" &> /dev/null; then
    mkdir -p Audit
    "${SYFT_BIN}" dir:. \
        --exclude ./venv \
        --exclude ./android \
        --exclude ./ios \
        --exclude ./macos \
        --exclude ./windows \
        --exclude ./build \
        --exclude ./packaging_output \
        --exclude ./dist \
        --exclude ./plan \
        --exclude ./.dart_tool \
        -o cyclonedx-json > Audit/SBOM-Linux.json
    cp Audit/SBOM-Linux.json Audit/SBOM-Linux
    cp Audit/SBOM-Linux.json Audit/sbom.json
fi

# Prepare DEB structure
mkdir -p "${BUILD_DIR}/DEBIAN"
mkdir -p "${BUILD_DIR}/usr/bin"
mkdir -p "${BUILD_DIR}/usr/share/applications"
mkdir -p "${BUILD_DIR}/usr/share/pixmaps"
mkdir -p "${BUILD_DIR}/opt/monitro/backend"

# Control file
cat <<EOF > "${BUILD_DIR}/DEBIAN/control"
Package: monitro
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: mariadb-server
Maintainer: Chuck Talk <chuck@nordheim.online>
Description: Cross-platform local system observability platform
EOF

# Copy binaries
cp -r build/linux/${FLUTTER_ARCH}/release/bundle/* "${BUILD_DIR}/opt/monitro/"
cp backend/monitro_collector "${BUILD_DIR}/opt/monitro/backend/"
cp -r db "${BUILD_DIR}/opt/monitro/"

# Install icon into hicolor theme (required for appgrid visibility)
for SIZE in 48 64 128 256 512; do
  mkdir -p "${BUILD_DIR}/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"
  cp assets/images/monitro_icon.png "${BUILD_DIR}/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps/monitro.png"
done

# Also install a copy to pixmaps as a fallback
mkdir -p "${BUILD_DIR}/usr/share/pixmaps"
cp assets/images/monitro_icon.png "${BUILD_DIR}/usr/share/pixmaps/monitro.png"

# Copy config file
mkdir -p "${BUILD_DIR}/opt/monitro/config"
cp config/monitro.example.yaml "${BUILD_DIR}/opt/monitro/config/monitro.example.yaml"

# Copy certs directory scripts (DO NOT copy actual certificates to prevent mismatch on upgrades)
mkdir -p "${BUILD_DIR}/opt/monitro/certs"
if [ -f certs/gen_certs.sh ]; then
  cp certs/gen_certs.sh "${BUILD_DIR}/opt/monitro/certs/"
  chmod +x "${BUILD_DIR}/opt/monitro/certs/gen_certs.sh"
fi

# Copy database setup script and migrations
cp scripts/monitro-db-setup.sh "${BUILD_DIR}/opt/monitro/backend/monitro-db-setup.sh"
chmod +x "${BUILD_DIR}/opt/monitro/backend/monitro-db-setup.sh"
mkdir -p "${BUILD_DIR}/opt/monitro/db/migrations"
cp db/migrations/*.sql "${BUILD_DIR}/opt/monitro/db/migrations/"

# Postinst (to setup systemd service for collector)
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/postinst"
#!/bin/bash

# Create monitro.yaml from example if it doesn't already exist (first install)
if [ ! -f /opt/monitro/config/monitro.yaml ]; then
  cp /opt/monitro/config/monitro.example.yaml /opt/monitro/config/monitro.yaml
  echo "Created default /opt/monitro/config/monitro.yaml from example."
fi

# Run first-run database setup (idempotent — skips if already done)
if [ -x /opt/monitro/backend/monitro-db-setup.sh ]; then
  /opt/monitro/backend/monitro-db-setup.sh || echo "WARNING: Database setup encountered an issue. Check /var/log/monitro-collector.log"
fi

# Generate local SSL certificates if missing
if [ ! -f /opt/monitro/certs/server.key ]; then
  echo "Generating local SSL certificates for Monitro..."
  if [ -x /opt/monitro/certs/gen_certs.sh ]; then
    /opt/monitro/certs/gen_certs.sh
    # Trust the CA locally
    cp /opt/monitro/certs/ca.crt /usr/local/share/ca-certificates/monitro-ca.crt 2>/dev/null || true
    update-ca-certificates &>/dev/null || true
  else
    echo "WARNING: /opt/monitro/certs/gen_certs.sh is missing or not executable."
  fi
fi

cat <<SVC > /etc/systemd/system/monitro-collector.service
[Unit]
Description=Monitro Collector Daemon
After=network.target mariadb.service

[Service]
WorkingDirectory=/opt/monitro
ExecStart=/opt/monitro/backend/monitro_collector --config /opt/monitro/config/monitro.yaml
Restart=on-failure
RestartSec=5
User=root
StandardOutput=append:/var/log/monitro-collector.log
StandardError=append:/var/log/monitro-collector.log

[Install]
WantedBy=multi-user.target
SVC

# Create logrotate config to keep the log file manageable
cat <<LOGROTATE > /etc/logrotate.d/monitro-collector
/var/log/monitro-collector.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
LOGROTATE
systemctl daemon-reload
systemctl enable monitro-collector.service
systemctl restart monitro-collector.service

# Refresh icon cache so the icon appears in the appgrid
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database /usr/share/applications || true
fi
EOF
chmod 755 "${BUILD_DIR}/DEBIAN/postinst"

# Prerm (to clean up)
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/prerm"
#!/bin/bash
systemctl stop monitro-collector.service || true
systemctl disable monitro-collector.service || true
rm -f /etc/systemd/system/monitro-collector.service
systemctl daemon-reload
EOF
chmod 755 "${BUILD_DIR}/DEBIAN/prerm"

# Create symlink & desktop entry
mkdir -p "${BUILD_DIR}/usr/bin"
cat <<'EOF' > "${BUILD_DIR}/usr/bin/monitro"
#!/bin/bash
exec /opt/monitro/monitro "$@"
EOF
chmod +x "${BUILD_DIR}/usr/bin/monitro"

cat <<EOF > "${BUILD_DIR}/usr/share/applications/online.nordheim.monitro.desktop"
[Desktop Entry]
Name=Monitro
Comment=Local System Observability Platform
Exec=/opt/monitro/monitro
Icon=monitro
Type=Application
Categories=System;Monitor;
Keywords=system;monitor;observability;metrics;
StartupWMClass=online.nordheim.monitro
EOF

dpkg-deb --build "${BUILD_DIR}"
echo "Created build/linux/deb/${PACKAGE_NAME}.deb"

# ── Signing and Hashing ──────────────────────────────────────────────
echo "Signing and Hashing artifacts..."
cd build/linux/deb/

# Generate SHA512 checksum
sha512sum "${PACKAGE_NAME}.deb" > "${PACKAGE_NAME}.deb.sha512"

# Check if key exists in keyring, else skip signing for CI/Test
if gpg --list-keys "${DEBEMAIL}" &> /dev/null; then
  # Create detached signature
  gpg --armor --detach-sign --local-user "${DEBEMAIL}" --output "${PACKAGE_NAME}.deb.asc" "${PACKAGE_NAME}.deb"
  
  # Export public key
  gpg --armor --export "${DEBEMAIL}" > chuck_pubkey.asc
else
  echo "GPG Key for ${DEBEMAIL} not found. Skipping signing."
fi

# Copy to NOBuilds directory
echo "Copying to NOBuilds directory..."
DATE_STR=$(date +%m-%d-%Y)
NOBUILDS_DIR="${HOME}/NOBuilds/Monitro-${DATE_STR}-${VERSION}"
mkdir -p "${NOBUILDS_DIR}"

# Generate source code archive
echo "Generating source tarball..."
tar --exclude=build --exclude=.dart_tool --exclude=.git -czf "${NOBUILDS_DIR}/monitro_source.tar.gz" -C "../../.." .

# Copy packages and signatures
cp "${PACKAGE_NAME}.deb" "${NOBUILDS_DIR}/"
cp "${PACKAGE_NAME}.deb.asc" "${NOBUILDS_DIR}/" || true
cp "${PACKAGE_NAME}.deb.sha512" "${NOBUILDS_DIR}/" || true
cp "chuck_pubkey.asc" "${NOBUILDS_DIR}/" || true

# Copy license, readme, and sbom
cp ../../../LICENSE "${NOBUILDS_DIR}/"
cp ../../../README.md "${NOBUILDS_DIR}/"
cp ../../../Audit/SBOM-Linux.json "${NOBUILDS_DIR}/" || true
cp ../../../Audit/SBOM-Linux "${NOBUILDS_DIR}/" || true
cp ../../../Audit/sbom.json "${NOBUILDS_DIR}/" || true

echo "Release artifacts built successfully in build/linux/deb/"
ls -la
cd ../../..
