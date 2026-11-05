import 'package:madar_sat/core/platform/share_service.dart';

/// The OS share sheet, recorded instead of opened (S16, S6's share action).
class FakeShareService implements ShareService {
  final List<String> shared = [];
  bool succeeds = true;

  @override
  Future<bool> share({required String text, String? subject}) async {
    shared.add(text);
    return succeeds;
  }
}
