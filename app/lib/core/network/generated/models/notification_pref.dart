// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'notification_pref_lead_min.dart';

part 'notification_pref.freezed.dart';
part 'notification_pref.g.dart';

@Freezed()
abstract class NotificationPref with _$NotificationPref {
  const factory NotificationPref({
    /// The name has been replaced because it contains a keyword. Original name: `on`.
    @JsonKey(name: 'on')
    @Default(true)
    bool onValue,
    @JsonKey(name: 'lead_min')
    NotificationPrefLeadMin? leadMin,
  }) = _NotificationPref;
  
  factory NotificationPref.fromJson(Map<String, Object?> json) => _$NotificationPrefFromJson(json);
}
