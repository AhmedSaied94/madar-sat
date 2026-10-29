// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlatformGroup _$PlatformGroupFromJson(Map<String, dynamic> json) =>
    _PlatformGroup(
      items: (json['items'] as List<dynamic>)
          .map((e) => PlatformEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      region: json['region'] as String,
    );

Map<String, dynamic> _$PlatformGroupToJson(_PlatformGroup instance) =>
    <String, dynamic>{'items': instance.items, 'region': instance.region};
