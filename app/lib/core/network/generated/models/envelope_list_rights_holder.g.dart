// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_rights_holder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListRightsHolder _$EnvelopeListRightsHolderFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListRightsHolder(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => RightsHolder.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListRightsHolderToJson(
  _EnvelopeListRightsHolder instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
