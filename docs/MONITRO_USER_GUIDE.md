# Monitro - Comprehensive User Guide

Welcome to **Monitro**! Monitro is an advanced, cross-platform local system observability platform designed to give you deep insights into the operational health of your workstation.

---

## 🚀 1. What is Monitro?

**Monitro** is a modern, high-performance local system monitor inspired by traditional tools like Monitorix, but built natively for the modern desktop using Flutter and a lightning-fast Dart backend. 

It is proudly part of the Nordheim Online portfolio of applications. The architecture is decoupled into two layers to ensure maximum efficiency and security:
1. **The Backend Collector:** A native daemon that silently gathers system telemetry.
2. **The UI Dashboard:** A rich, responsive Flutter application that visualizes the data over a secure HTTPS (4096-bit locally-signed RSA SSL) connection.
3. **The Storage Layer:** All metrics are securely stored locally in a MariaDB database.

---

## 📊 2. What is Monitro Used For?

Monitro is designed for workstation administrators, developers, and power users who need to know exactly what their hardware and network are doing in real time. It is used to monitor, audit, and diagnose:

* **CPU & Memory:** View per-core utilization, user/system breakdown, and track RAM/Swap usage over time.
* **Storage I/O:** Monitor disk read/write rates and track available filesystem capacity across all your mounts.
* **Network & Security Auditing:** Track inbound and outbound interface traffic. Actively view live TCP/UDP connections and listening ports to quickly identify rogue services or potential DDoS patterns.
* **Process Tracing:** Instantly see which applications are consuming the most CPU/Memory, and identify rogue processes making excessive outbound API or HTTP requests.

---

## 💾 3. Installation & Configuration Guide

Monitro requires the setup of both its database (MariaDB) and its backend collector before the UI can render your data.

### Prerequisites (All Platforms)
* **MariaDB 10.6+** (Required for storing telemetry data locally).

### Option A: Linux Installation (Debian/Ubuntu)

1. **Install Dependencies:**
   Install the MariaDB database server natively using your package manager.
   ```bash
   sudo apt update
   sudo apt install mariadb-server
   sudo systemctl enable --now mariadb
   ```
2. **Setup the Database Schema:**
   *(Assuming you have downloaded the Monitro source repository or `.deb` package contents)*
   Log into MySQL as root to initialize the required tables:
   ```bash
   sudo mysql -u root < db/migrations/001_initial_schema.sql
   ```
3. **Install the Monitro App:**
   Download the latest `.deb` package from the official releases and install it.
   ```bash
   sudo dpkg -i monitro_*.deb
   ```
   *Note: This installation automatically generates your unique 4096-bit SSL certificates for securely connecting the GUI to the local daemon!*
4. **Configure the Collector:**
   Edit your YAML configuration file to match the MariaDB database credentials you created:
   ```bash
   sudo nano /opt/monitro/config/monitro.yaml
   ```
5. **Start the Backend:**
   Start the collector in the background so it can begin gathering telemetry:
   ```bash
   /opt/monitro/backend/monitro_collector --config /opt/monitro/config/monitro.yaml &
   ```
6. **Launch the UI:** Open your Application grid and search for **Monitro**.

### Option B: macOS Installation

Monitro is fully compatible with macOS and strictly adheres to the Mac App Store Sandbox requirements.

1. **Install Dependencies:**
   Use Homebrew to install and start the database.
   ```bash
   brew install mariadb
   brew services start mariadb
   ```
2. **Install the Application:**
   Download the latest Monitro `.dmg` release and drag the **Monitro** app icon directly into your **Applications** folder.
3. **Configure & Launch:**
   Launch Monitro from your Applications folder. The macOS application is built to dynamically handle its internal sandbox network entitlements to communicate directly with your local MariaDB instance securely.

---

## 📝 4. Gathering Logs and Application Information

Effective troubleshooting relies on logging. If you experience an issue where the UI dashboard is empty or failing to connect, you should gather the following logs to understand what the application is doing.

### Viewing In-App Alerts
Monitro includes a built-in **Alert Log** directly within the graphical interface. 
* Navigate to the **Alerts** tab inside the Monitro UI. 
* This area will display all threshold breach events (e.g., CPU spikes, disk full warnings) complete with accurate timestamps. 

### Gathering Backend Collector Logs
Because the backend collector operates as a headless daemon, its logs are critical when diagnosing "Cannot connect to Monitro backend" errors.
* **If running manually (Linux/macOS source):** When you execute `/opt/monitro/backend/monitro_collector ...`, the daemon will output connection statuses, SSL verification errors (e.g., permission denied on `server.key`), and MariaDB SQL connection failures directly to your active terminal standard output (`stdout`). 
* **Pro-Tip for Support:** To properly capture these logs for review, redirect the output to a file when starting the service:
  ```bash
  /opt/monitro/backend/monitro_collector --config /opt/monitro/config/monitro.yaml > ~/monitro_backend_debug.log 2>&1 &
  ```
  You can then view the log at any time using standard tools like `cat ~/monitro_backend_debug.log`.

### Common Configuration Log Errors
* If the log reports `"Address already in use (errno = 98) on port 8443"`, a zombie instance of the collector is already running. You must kill the old process (`killall -9 monitro_collector`).
* If the log reports `"Permission Denied (errno = 13) on server.key"`, your user does not have permission to read the SSL certificates. Ensure you own the directory (`sudo chown -R $USER:$USER /opt/monitro/certs/`).

---
*Monitro - Part of the Nordheim Online Portfolio.*
