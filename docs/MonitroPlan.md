# Monitro Plan: Application Strategy

## 1. Product Objective

Distribute Monitro as a self-contained, high-performance system observability platform targeting macOS, Linux, and Windows ecosystems.

## 2. Platform Architecture

Monitro operates using three core components:

- **Frontend Layer**: A lightweight UI written in Flutter, providing a robust interactive experience.
- **Backend Service**: A standalone local service daemon written in Dart. It collects telemetry, system events, and metrics.
- **Data Layer**: MariaDB serves as the highly-performant, persistent storage environment.

## 3. Mono-Repository Paradigm

A principal objective is maintaining code unity. We will utilize **a single repository for macOS, Linux, and Windows**. The application will adapt to OS specifications at compilation and packaging time, minimizing code drift between versions.

## 4. Environment Delivery Model

The primary constraint is MariaDB, an external database service needing system installation. Each OS handles native background services differently, which sets our packaging requirements:

- **Linux Philosophy**: *System-Managed.* Utilize `.deb` (Debian Packages) where dependencies like `mariadb-server` are explicitly passed to the host OS package manager (`apt`). Linux resolves side-loaded application prerequisites securely and natively.
- **macOS & Windows Philosophy**: *Application-Managed.* Utilize standard Apple Disk Image (`.dmg`) formats and Windows Executables (`.exe` via InnoSetup). Since macOS and Windows mechanics cannot natively pull, install, and instantiate an external database runtime organically without significant friction, the Monitro Application itself acts as the runtime bootstrap. Upon launch, it asserts system requirements and provides a **Setup UI** to capture MariaDB credentials. It dynamically authors a backend configuration and spins up the background daemon seamlessly using system-level process management mechanisms.

## 5. Planned Features & UI Enhancements

- **Collector Service Management UI**: Implement interactive buttons within the application interface to explicitly "**Start Collector Service**" (running it in the background) and "**Stop Collector Service**" (terminating the running daemon process). This provides the user with granular, manual control over the backend daemon lifecycle directly from the UI.
- **Tablet / XP-PEN Optimizations**: Work on layout, scaling, and interactive elements to ensure the UI is fully functional and aesthetically pleasing when used with pen tablets like the XP-PEN. This includes adjusting hit targets, hover states, and drag interactions to be stylus-friendly.
