# Monitro Future Improvements & Features Track

## UI Enhancements
- [ ] **Dedicated Connections Interface:** Separate the "Network Connections" page into two distinct, dedicated views: one exclusively for active/outbound connections and another exclusively for inbound/listening ports. Currently, splitting them on the same screen via tabs causes the initial view to be empty/misleading if the data isn't active on that generic page.
- [ ] **Dash-to-Dock Icon Loading:** Investigate edge cases where the `.desktop` file Icon attribute doesn't natively map to the system icon theme, causing the app icon to appear missing on certain GNOME distributions.

## Architecture & Lifecycle Integrations
- [ ] **Collector Daemon Controls:** Add an interactive overlay or settings page inside the Flutter GUI to manually Start, Stop, and Restart the `monitro_collector` background daemon. 
- [ ] **Automatic Daemon Lifecycle:** Refactor the Flutter Application to organically spawn the daemon process upon launch, and cleanly terminate it upon exit. Currently, the GUI and collector are decoupled, forcing users to manually manage the collector lifecycle via CLI or rely on orphaned background instances that hold port locks (e.g., `8443`).
- [ ] **Collector Status Indication:** Add a dynamic health indicator to the UI header that visually communicates whether the collector is successfully running and communicating over `loopback`.

## Security & Performance Analysis
- [ ] **API Security Qualifications:** Review and qualify all API methods to ensure endpoints utilize secure protocols, proper authentication handshakes, and strict method validations (addressing lack of secure methods where applicable).
- [ ] **Resource Profiling:** Identify and optimize API calls which are particularly expensive in terms of CPU utilization, high uncompressed data transfer, or which execute 'unbounded' queries that may pose availability or security risks.
