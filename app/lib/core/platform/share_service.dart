import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'share_service.g.dart';

/// The OS share sheet, behind an interface so a test never opens one (S16 «شارك التطبيق»).
abstract interface class ShareService {
  /// True when something took the share; false when the sheet was dismissed or refused.
  Future<bool> share({required String text, String? subject});
}

class PlatformShareService implements ShareService {
  const PlatformShareService();

  @override
  Future<bool> share({required String text, String? subject}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } on Object {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
ShareService shareService(Ref ref) => const PlatformShareService();
