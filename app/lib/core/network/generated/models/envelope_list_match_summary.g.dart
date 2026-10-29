// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_match_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListMatchSummary _$EnvelopeListMatchSummaryFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListMatchSummary(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListMatchSummaryToJson(
  _EnvelopeListMatchSummary instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
