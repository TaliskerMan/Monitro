# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.13] - 2026-06-10

### Added
- **macOS Signing & Notarization Pipeline:** Automated `build_macos.sh` release compilation, cleaning extended attributes, restructuring Flutter frameworks, deep signing with Developer ID keys, Apple Notarization (`notarytool` / `stapler`), and auto-staging to LemonSqueezy folders.
- **Linux Packaging Pipeline:** Automated `package_linux.sh` compilation of the native Dart collector daemon, icon scaling, SSL certificate triggers (`gen_certs.sh`), database config generation, systemd collector daemon registration, logrotate configuration, and detached GPG signing via `chuck@nordheim.online`.
- **Structured Error Logging:** Integrated structured error tracking in codebase using `dart:developer` `log()`.
- **Expanded Code Documentation:** Added comprehensive telemetry module descriptions (`///`).

### Changed
- **License Metadata:** Clarified licensing definitions inside the About screen.
