// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frequency_change.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FrequencyChange _$FrequencyChangeFromJson(Map<String, dynamic> json) =>
    _FrequencyChange(
      detectedAt: DateTime.parse(json['detected_at'] as String),
      newValue: FrequencyChangeTuning.fromJson(
        json['new'] as Map<String, dynamic>,
      ),
      old: FrequencyChangeTuning.fromJson(json['old'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FrequencyChangeToJson(_FrequencyChange instance) =>
    <String, dynamic>{
      'detected_at': instance.detectedAt.toIso8601String(),
      'new': instance.newValue,
      'old': instance.old,
    };
