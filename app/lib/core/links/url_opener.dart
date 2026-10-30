import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app (the reception video). The one place feature code reaches
/// `url_launcher`, so a test answers without leaving the app.
abstract interface class UrlOpener {
  /// True when something took the link, false when nothing on the device could open it.
  Future<bool> open(Uri url);
}

class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri url) async {
    // https-only holds here too, not only in the callers that checked the address first.
    if (httpsUri(url.toString()) == null) return false;
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing on the device could take it (no browser, a refused launch).
      return false;
    }
  }
}

final urlOpenerProvider = Provider<UrlOpener>((ref) => const UrlLauncherOpener());

const int _maxAddressLength = 2048;

/// An editorial link as an address the app will open: absolute and `https`, else null.
///
/// The address is data from the admin, so anything else (cleartext, a `javascript:` or
/// `intent:` scheme, a relative path, text that is not a link) is treated as no link
/// rather than opened. Userinfo (`https://trusted.com@evil.com`), a port outside 1-65535 and
/// an address over 2048 characters are refused too.
Uri? httpsUri(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.length > _maxAddressLength) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return null;
  }
  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return null;
  return uri;
}
