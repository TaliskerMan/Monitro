// Single source of truth for the backend/collector version.
//
// This value is kept in sync with the frontend `pubspec.yaml` (the canonical
// version, which the About screen reads via package_info). The release build
// script regenerates this file from the frontend pubspec so the API `/health`
// response, the daemon, and the desktop app can never report different
// versions again. Do not edit by hand for a release — bump the frontend
// pubspec and let the build script propagate it.
const String monitroVersion = '1.2.14';
