/// A native build cannot reload its own code: the forced-update screen opens the store
/// instead (research R29).
Future<bool> reloadPage() async => false;
