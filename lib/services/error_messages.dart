// Pure, testable mapping from raw backend errors to actionable UI messages.

/// Translate a raw backend error string (e.g. 'HTTP 403', a socket exception)
/// into an actionable, human-readable message for the dashboard banner.
String friendlyBackendError(String raw) {
  if (raw.contains('403')) {
    return 'Backend returned 403 — API key mismatch. The running collector was '
        'likely started with a different (or no) api_key. Restart the collector '
        "so it uses the app's key.";
  }
  if (raw.contains('500')) {
    return 'Backend returned 500 — the collector errored (check its log; '
        'possibly a database/migration failure).';
  }
  if (raw.contains('Connection refused') || raw.contains('SocketException')) {
    return 'Cannot reach the collector on 127.0.0.1:8443 — it may not be running. '
        'Check the Service Control screen.';
  }
  return 'Backend error: $raw';
}
