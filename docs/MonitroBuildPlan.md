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

### Process Sequence

1. **Compilation**:
   - `flutter build macos` for the native macOS User Interface.
   - `dart compile exe bin/server.dart` for the background data collection daemon target to macOS architecture.
2. **Bundle Engineering**:
   - Embed the backend daemon executable into the frontend's `.app` wrapper inside `/Contents/Resources`.
3. **Image Packaging (`.dmg`)**:
   - Wrap the `.app` using a tool like `create-dmg`, providing the standard `Applications/` folder shortcut.

### The Lifecycle Flow (Handling MariaDB)

Since the DMG cannot require OS-level installations dynamically:

1. User installs the DMG and drops it into Applications.
2. User double-clicks Monitro.
3. The Flutter application checks if `mariadb` is globally accessible and running.
4. **Onboarding Intervention**: If MariaDB is missing, the Flutter app brings up a dependency resolution dialogue outlining missing dependencies.
5. **Auto-Scripting**: The UI executes a bash payload to:
   - Check/install `Homebrew`.
   - Run `brew install mariadb` and `brew services start mariadb`.
6. Once MariaDB is connected, the app seeds standard database schemas, starts the background data daemon via `Process.start` (or prompts execution of a background `LaunchAgent`), and enters normal Dashboard mode.
