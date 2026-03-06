#!/bin/bash
set -e
VERSION="1.2.6"
ARCH="amd64"
DEBFULLNAME="Chuck Talk"
DEBEMAIL="chuck@nordheim.online"
PACKAGE_NAME="monitro_${VERSION}_${ARCH}"
BUILD_DIR="build/linux/deb/${PACKAGE_NAME}"

# Build flutter
flutter build linux --release

# Build backend
cd backend
dart pub get
dart compile exe bin/monitro_collector.dart -o monitro_collector
cd ..

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
cp -r build/linux/x64/release/bundle/* "${BUILD_DIR}/opt/monitro/"
cp backend/monitro_collector "${BUILD_DIR}/opt/monitro/backend/"
cp data/monitro.png "${BUILD_DIR}/usr/share/pixmaps/"

# Postinst (to setup systemd service for collector)
cat <<'EOF' > "${BUILD_DIR}/DEBIAN/postinst"
#!/bin/bash
cat <<SVC > /etc/systemd/system/monitro-collector.service
[Unit]
Description=Monitro Collector Daemon
After=network.target mariadb.service

[Service]
ExecStart=/opt/monitro/backend/monitro_collector
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable monitro-collector.service
systemctl restart monitro-collector.service
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
Exec=/opt/monitro/monitro
Icon=monitro
Type=Application
Categories=System;Monitor;
EOF

dpkg-deb --build "${BUILD_DIR}"
echo "Created build/linux/deb/${PACKAGE_NAME}.deb"
