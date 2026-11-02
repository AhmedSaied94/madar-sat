// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_competition_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeCompetitionDetail _$EnvelopeCompetitionDetailFromJson(
  Map<String, dynamic> json,
) => _EnvelopeCompetitionDetail(
  data: json['data'] == null
      ? null
      : CompetitionDetail.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeCompetitionDetailToJson(
  _EnvelopeCompetitionDetail instance,
) => <String, dynamic>{
  'data': ?instance.data,
  'error': ?instance.error,
  'meta': ?instance.meta,
  'success': instance.success,
};
