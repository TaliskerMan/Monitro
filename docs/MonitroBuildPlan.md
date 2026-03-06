# Monitro Build Plan: Continuous Assembly Strategy

## The Linux Strategy (Debian `.deb`)

Rely on standard Linux structures. Package dependencies will be solved globally by `apt`.

### Process Sequence

1. **Compilation**:
   - `flutter build linux` for the User Interface.
   - `dart compile exe bin/server.dart` for the background data collection daemon.
2. **FS Layout**:
   - `/opt/monitro/`: Binaries, Flutter `.so` shared objects, UI assets.
   - `/usr/bin/monitro`: Pointer link to UI executable.
3. **Service Daemons**:
   - Supply `monitro-collector.service` configuring `systemd` to keep the backend collecting data independently of the UI state.
4. **Debian Control File (`DEBIAN/control`)**:
   - Critically include: `Depends: mariadb-server` guarantees the database is present before Monitro installs.
5. **Packager**: Use `dpkg-deb --build` or equivalent builder to construct the delivery file.

---

## The macOS Strategy (Disk Image `.dmg`)

Follow the standard application bundle conventions with a guided runtime initialization workflow.

### macOS Process Sequence

1. **Compilation**:
   - `flutter build macos` for the native macOS User Interface.
   - `dart compile exe bin/monitro_collector.dart` for the background data collection daemon target to macOS architecture.
2. **Bundle Engineering**:
   - Embed the backend daemon executable into the frontend's `.app` wrapper inside `/Contents/Resources/backend`.
   - Embed SSL `/certs` into `/Contents/Resources/certs`.
3. **Image Packaging (`.dmg`)**:
   - Wrap the `.app` using a tool like `create-dmg`, providing the standard `Applications/` folder shortcut.

### macOS Lifecycle Flow (Handling MariaDB)

Since the DMG cannot require OS-level installations dynamically:

1. User installs the DMG and drops it into Applications.
2. User double-clicks Monitro.
3. The Flutter application checks its local `SharedPreferences` for an existing database configuration.
4. **Setup UI (First Run)**: If no configuration exists, the app opens to the `/setup` screen, prompting the user for MariaDB credentials (host, port, user, etc.).
5. **Dynamic Configuration & Auto-Start**:
   - Uses `ConfigGenerator` service to build a `/config/monitro.yaml` using the credentials and paths to the embedded SSL certificates.
   - Uses `BackendService` using `dart:io` `Process.start` to seamlessly spin up the backend collector daemon in the background.

---

## The Windows Strategy (Executable Installer `.exe`)

Follow the standard application bundle conventions utilizing InnoSetup.

### Windows Process Sequence

1. **Compilation**:
   - `flutter build windows --release` for the native Windows User Interface.
   - `dart compile exe bin/monitro_collector.dart` for the background data collection daemon target to Windows architecture.
2. **Image Packaging (`.exe`)**:
   - Wrap the built assets utilizing `InnoSetup` via `monitro.iss`.
   - Recursively copy the `/build/windows/x64/runner/Release/*` frontend assets.
   - Copy `monitro_collector.exe` into `{app}/backend`.
   - Copy SSL certificates into `{app}/certs`.

### Windows Lifecycle Flow (Handling MariaDB)

The lifecycle mirrors the macOS strategy completely.

1. Application is launched from the Start Menu (`monitro.exe`).
2. Flutter determines if local `SharedPreferences` configuration is present.
3. If absent, user is presented with the Setup UI wizard to input MariaDB credentials.
4. Dynamic settings are generated and `BackendService` auto-starts the `{app}/backend/monitro_collector.exe` process.

---

## Version Management (Auto-Increment)

To cleanly distinguish releases and trigger updates automatically, Monitro employs an auto-incrementing build system baked directly into the OS-native packaging scripts.

### Process

1. Before any `flutter build` is invoked, the respective compilation script (`package_macos.sh`, `package_linux.sh`, `package_windows.ps1`) executes a native shell script (`increment_build.sh` or `increment_build.ps1`).
2. The native script parses `pubspec.yaml`, locks onto the `version:` key (e.g., `1.0.0+4`), increments the integer build number, and overwrites the file (e.g., `1.0.0+5`).
3. Using native Bash/PowerShell bypasses the Dart VM entirely, preventing sandbox interference or Xcode License Agreement blocks on headless CI/CD systems during version bumps.
4. The packaging scripts then dynamically read the new `VERSION` variable straight from the file using `grep` or `Select-String` to correctly append the version to the final installer output (e.g., `Monitro_1.0.0+5_macOS.dmg`).
