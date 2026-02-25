# Monitro

**Monitro** is a cross-platform local system observability platform — inspired by [Monitorix](https://www.monitorix.org), built from the ground up with modern technologies. It is proudly part of the **Nordheim Online** portfolio of applications.

| Layer | Technology |
|---|---|
| UI | Flutter (macOS · Linux · Windows desktop) |
| Backend Collector | Dart native daemon |
| Storage | MariaDB (local, versioned schema) |
| Transport | HTTPS — 4096-bit locally-signed RSA SSL |

## What It Monitors

- **CPU** — per-core utilization, user/sys/idle breakdown
- **Memory & Swap** — used / free / cached / buffers
- **Disk I/O** — read/write rates per device
- **Filesystem Usage** — used/available per mount
- **Network Traffic** — per-interface bytes/sec & packets/sec
- **Active Connections** — TCP/UDP state breakdown (netstat)
- **Port Activity** — top listening ports with connection counts
- **Process Monitor** — top CPU/memory consumers (real-time, sortable)
- **User Sessions** — logged-in users, session duration, source host
- **API / HTTP Request Rates** — which processes are making excessive outbound calls
- **Alert Log** — threshold breach events with timestamps

## Requirements

### All Platforms

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, ≥ 3.19)
- [Dart SDK](https://dart.dev/get-dart) (bundled with Flutter)
- [MariaDB](https://mariadb.org/download/) 10.6+

### macOS

```bash
brew install mariadb
brew services start mariadb
```

### Linux

```bash
sudo apt install mariadb-server flutter
```

### Windows

Download MariaDB installer from <https://mariadb.org/download/>

## Quick Start

```bash
# 1. Clone the repo
git clone git@github.com:TaliskerMan/Monitro.git
cd Monitro

# 2. Generate local SSL certificates
chmod +x certs/gen_certs.sh
./certs/gen_certs.sh

# 3. Set up the database
mysql -u root < db/migrations/001_initial_schema.sql

# 4. Configure
cp config/monitro.example.yaml config/monitro.yaml
# Edit config/monitro.yaml: set DB user/password

# 5. Build & run the backend collector
cd backend
dart pub get
dart compile exe bin/monitro_collector.dart -o bin/monitro_collector
./bin/monitro_collector --config ../config/monitro.yaml &

# 6. Run the Flutter UI
cd ..
flutter pub get
flutter run -d macos   # or linux / windows
```

## Project Structure

```
Monitro/
├── lib/                    # Flutter UI source
│   ├── main.dart
│   ├── screens/
│   ├── widgets/
│   ├── models/
│   └── services/
├── backend/                # Dart collector daemon
│   ├── bin/
│   └── lib/
│       ├── collectors/     # Platform-aware metric collectors
│       ├── api/            # REST API routes
│       └── storage/        # MariaDB service
├── db/
│   └── migrations/         # SQL migration scripts
├── certs/                  # SSL cert generation scripts
├── config/                 # YAML configuration
└── docs/                   # Additional documentation
```

## License

This project is licensed under the [MIT License](./LICENSE).

© 2026 Chuck Talk <chuck@nordheim.online>.
Free for Linux workstations. Official compiled binaries for macOS and Windows are available for purchase, supporting the ongoing development of the project.
