import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../features/notifications/push_route_table.dart';

/// The web worker opens only what the app would (FR-059). It can't import Dart, so its one
/// pattern sits between marker comments, and this runs it over `parsePushRoute`'s table.
void main() {
  final source = File('web/firebase-messaging-sw.js').readAsStringSync();

  RegExp workerPattern() {
    final marked = RegExp(
      r'// push-route-pattern:start\s+const PUSH_ROUTE_PATTERN = /(.+)/;\s+// push-route-pattern:end',
    ).firstMatch(source);
    expect(marked, isNotNull, reason: 'the marked pattern is missing from the worker');
    return RegExp(marked!.group(1)!);
  }

  test('the worker accepts every route the app accepts', () {
    final pattern = workerPattern();
    for (final route in acceptedPushRoutes) {
      expect(pattern.hasMatch(route), isTrue, reason: route);
    }
  });

  test('the worker refuses every route the app refuses', () {
    final pattern = workerPattern();
    for (final route in refusedPushRoutes) {
      expect(pattern.hasMatch(route), isFalse, reason: route);
    }
  });

  test('a tap validates the route and falls back when navigate rejects', () {
    expect(source, contains('PUSH_ROUTE_PATTERN.test('));
    expect(source, contains('.catch('));
    expect(source, contains('clients.openWindow('));
  });
}
