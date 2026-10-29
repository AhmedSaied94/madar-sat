// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_competition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListCompetition _$EnvelopeListCompetitionFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListCompetition(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => Competition.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListCompetitionToJson(
  _EnvelopeListCompetition instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
