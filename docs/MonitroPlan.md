# Monitro Plan: Application Strategy

## 1. Product Objective

Distribute Monitro as a self-contained, high-performance system observability platform targeting macOS and Linux ecosystems.

## 2. Platform Architecture

Monitro operates using three core components:

- **Frontend Layer**: A lightweight UI written in Flutter, providing a robust interactive experience.
- **Backend Service**: A standalone local service daemon written in Dart. It collects telemetry, system events, and metrics.
- **Data Layer**: MariaDB serves as the highly-performant, persistent storage environment.

## 3. Mono-Repository Paradigm

A principal objective is maintaining code unity. We will utilize **a single repository for both macOS and Linux**. The application will adapt to OS specifications at compilation and packaging time, minimizing code drift between versions.

## 4. Environment Delivery Model

The primary constraint is MariaDB, an external database service needing system installation. Each OS handles native background services differently, which sets our packaging requirements:

- **Linux Philosophy**: *System-Managed.* Utilize `.deb` (Debian Packages) where dependencies like `mariadb-server` are explicitly passed to the host OS package manager (`apt`). Linux resolves side-loaded application prerequisites securely and natively.
- **macOS Philosophy**: *Application-Managed.* Utilize standard Apple Disk Image (`.dmg`) formats. Since macOS drag-and-drop mechanics cannot natively pull, install, and instantiate an external database runtime organically, the Monitro Application itself acts as the runtime bootstrap. Upon launch, it asserts system requirements and provides a one-click onboarding screen to orchestrate MariaDB's installation via Homebrew.
