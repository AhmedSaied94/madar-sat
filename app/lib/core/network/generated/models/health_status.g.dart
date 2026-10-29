// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthStatus _$HealthStatusFromJson(Map<String, dynamic> json) =>
    _HealthStatus(db: json['db'] as String, redis: json['redis'] as String);

Map<String, dynamic> _$HealthStatusToJson(_HealthStatus instance) =>
    <String, dynamic>{'db': instance.db, 'redis': instance.redis};
