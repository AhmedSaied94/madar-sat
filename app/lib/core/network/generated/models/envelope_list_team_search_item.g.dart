// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_team_search_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListTeamSearchItem _$EnvelopeListTeamSearchItemFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListTeamSearchItem(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => TeamSearchItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListTeamSearchItemToJson(
  _EnvelopeListTeamSearchItem instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
