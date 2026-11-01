// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_pref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationPref _$NotificationPrefFromJson(Map<String, dynamic> json) =>
    _NotificationPref(
      onValue: json['on'] as bool? ?? true,
      leadMin: json['lead_min'] == null
          ? null
          : NotificationPrefLeadMin.fromJson((json['lead_min'] as num).toInt()),
    );

Map<String, dynamic> _$NotificationPrefToJson(_NotificationPref instance) =>
    <String, dynamic>{
      'on': instance.onValue,
      'lead_min': _$NotificationPrefLeadMinEnumMap[instance.leadMin],
    };

const _$NotificationPrefLeadMinEnumMap = {
  NotificationPrefLeadMin.value5: 5,
  NotificationPrefLeadMin.value15: 15,
  NotificationPrefLeadMin.value30: 30,
  NotificationPrefLeadMin.value60: 60,
  NotificationPrefLeadMin.$unknown: r'$unknown',
};
