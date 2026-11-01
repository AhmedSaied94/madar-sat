// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_prefs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationPrefs _$NotificationPrefsFromJson(Map<String, dynamic> json) =>
    _NotificationPrefs(
      types: (json['types'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, NotificationPref.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$NotificationPrefsToJson(_NotificationPrefs instance) =>
    <String, dynamic>{'types': instance.types};
