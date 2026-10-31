import 'package:madar_sat/core/links/url_opener.dart';

/// A [UrlOpener] that records what was opened instead of leaving the app.
class FakeUrlOpener implements UrlOpener {
  final List<Uri> opened = [];

  /// What [open] answers: false is a link no app on the device could open.
  bool succeeds = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}
