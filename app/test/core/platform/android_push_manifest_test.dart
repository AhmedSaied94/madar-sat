import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `FirebasePushService` waits for `onRegistered`, and on Android FCM fires it only with this
/// flag on. Without it every Android device stays without a push id, and nothing fails: the
/// app runs, the server sees a device with no token, and no notification ever arrives.
void main() {
  test('the Android manifest asks FCM for the installation id the app waits for', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      matches(
        RegExp(
          r'<application[\s\S]*'
          r'android:name="firebase_messaging_installation_id_enabled"\s+'
          r'android:value="true"[\s\S]*</application>',
        ),
      ),
    );
  });
}
