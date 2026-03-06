# Monitro macOS Setup Guide

Welcome to Monitro for macOS! This guide provides all the necessary instructions to fulfill the requirements, configure the application, and troubleshoot any issues.

## 1. System Requirements & Dependencies

Before running Monitro, ensure your macOS system has the following dependencies:

- **macOS Version**: macOS 11.0 (Big Sur) or later.
- **MariaDB Server**: Monitro uses a local MariaDB database to persist your metrics securely.
  
To install MariaDB via Homebrew:

```bash
brew install mariadb
brew services start mariadb
```

*(If you do not have Homebrew, install it from brew.sh)*

## 2. Installation Setup

1. **Mount the DMG**: Double-click the downloaded `Monitro_1.2.3+X_macOS.dmg` file.
2. **Install**: Drag the `Monitro` app icon into the `Applications` folder alias provided in the DMG window.
3. **Launch**: Open Launchpad or your Applications folder and click `Monitro`.
   - *Note*: If Gatekeeper blocks the app because it is an unsigned test release, right-click (or Control-click) `Monitro` in Applications, select **Open**, and then confirm by clicking **Open** again.

## 3. Configuration

Upon its first launch, Monitro will require you to initialize its database and security keys.

1. **Setup Wizard**: The application will present a Setup Screen. Enter your local MariaDB credentials (usually `root` or your system username, and password if applicable).
2. **Auto-Configuration**: Monitro will automatically generate the 4096-bit local SSL certificates and build the configuration file at `config/monitro.yaml`.
3. **Collector Daemon**: The backend data collector process (`monitro_collector`) will seamlessly start in the background and begin logging vital system observability metrics.

## 4. Troubleshooting

**Issue**: *"Monitro cannot connect to the database / The UI shows no data."*

- **Solution**: Open Terminal and run `brew services restart mariadb`. Ensure the credentials you entered during setup are correct.

**Issue**: *"The backend collector process isn't running."*

- **Solution**: You can view the hidden backend logs using Terminal.

  ```bash
  cat /Applications/Monitro.app/Contents/Resources/backend/out.txt
  ```

**Issue**: *"I need to reset my configuration."*

- **Solution**: Uninstall the app by dragging it to the Trash. To clear stored preferences, remove the local application support cache:

  ```bash
  rm -rf "~/Library/Containers/online.nordheim.monitro"
  ```
