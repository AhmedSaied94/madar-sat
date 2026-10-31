import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device clock. Screens read "now" through this so a test can pin it and so the age
/// shown by `StaleHint` and the date strip do not depend on when the test runs.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
