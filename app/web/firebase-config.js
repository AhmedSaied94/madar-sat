/*
 * The public Firebase web identifiers (research R25, R26): an API key, an app id, the
 * messaging sender id and the project id. They identify the project to Google's servers and
 * are safe in a public bundle; the private service-account key never leaves the VPS.
 *
 * The empty object below keeps a local `flutter run -d chrome` working without a Firebase
 * project: the worker registers and does nothing. The release write it with
 * `./tool/write_firebase_config.sh env/prod.json` before `flutter build web`.
 */
self.MADAR_FIREBASE_CONFIG = {};
