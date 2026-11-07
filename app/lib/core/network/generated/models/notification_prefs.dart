// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'notification_pref.dart';

part 'notification_prefs.freezed.dart';
part 'notification_prefs.g.dart';

@Freezed()
abstract class NotificationPrefs with _$NotificationPrefs {
  const factory NotificationPrefs({
    Map<String, NotificationPref>? types,
    @Default(true)
    bool enabled,
  }) = _NotificationPrefs;
  
  factory NotificationPrefs.fromJson(Map<String, Object?> json) => _$NotificationPrefsFromJson(json);
}
