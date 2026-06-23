# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.14] - 2026-06-23

### Fixed
- **"No data everywhere" is now visible, not silent (P0-1).** A 403/500 from the
  collector previously overwrote the metrics with an error map and rendered every
  card blank/zero. The dashboard now shows a prominent error banner (a 403 is
  explained as an API-key mismatch), keeps the last good metrics, and has an
  always-visible collector status indicator (live / error / connecting).
- **Installed collector path (P0-1).** `BackendService` now resolves the
  collector binary under installed layouts (`/opt/monitro`, `/usr/lib/monitro`,
  exe-relative), not just `Directory.current/backend`.
- **One version, everywhere (P0-2).** The frontend `pubspec` is the single
  source of truth; the build script propagates it to the backend `pubspec` and
  the `/health` response (was hardcoded `0.1.0`). About/health/daemon now agree.
- **Migration runner hardened (P0-3).** Renumbered the duplicate `002` migration
  to `003`; added a `schema_migrations` ledger so each file runs exactly once;
  a failed migration is now fatal (was a swallowed warning).

### Security
- **Local API hardened (P1-4).** The API refuses to start without an `api_key`;
  removed the permissive `Access-Control-Allow-Origin: *` (the desktop app needs
  no CORS), closing the path for any local web origin to read telemetry or call
  `DELETE /processes`. The client now pins the local CA when available instead of
  trusting any localhost certificate.
- **Graceful process termination (P1-5).** `DELETE /processes/<pid>` sends
  SIGTERM and only escalates to SIGKILL if the process survives; refuses PIDs ≤ 1.

### Changed
- **Removed the broken HTTP fallback (P1-6)** in `isBackendHealthy` (an http://
  request to the TLS port could never succeed and it permanently rewrote the
  base URL).
- **macOS per-core CPU is labelled "aggregate (not per-core)"** since it is the
  aggregate value repeated (P2-9).
- Portable `build_macos.sh` (no hardcoded author paths); audit scope note added.

### Added
- **Tests (P2-10):** UI contract test (collector snapshot keys ⊇ keys the UI
  reads — catches "no data" regressions), backend auth-decision test, and an
  error-message mapping test.

## [1.2.13] - 2026-06-10

### Added
- **macOS Signing & Notarization Pipeline:** Automated `build_macos.sh` release compilation, cleaning extended attributes, restructuring Flutter frameworks, deep signing with Developer ID keys, Apple Notarization (`notarytool` / `stapler`), and auto-staging to LemonSqueezy folders.
- **Linux Packaging Pipeline:** Automated `package_linux.sh` compilation of the native Dart collector daemon, icon scaling, SSL certificate triggers (`gen_certs.sh`), database config generation, systemd collector daemon registration, logrotate configuration, and detached GPG signing via `chuck@nordheim.online`.
- **Structured Error Logging:** Integrated structured error tracking in codebase using `dart:developer` `log()`.
- **Expanded Code Documentation:** Added comprehensive telemetry module descriptions (`///`).

### Changed
- **License Metadata:** Clarified licensing definitions inside the About screen.
