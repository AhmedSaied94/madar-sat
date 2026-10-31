import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// The device clock. Screens read "now" through this so a test can pin it and so the age
/// shown by `StaleHint` and the date strip do not depend on when the test runs.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
