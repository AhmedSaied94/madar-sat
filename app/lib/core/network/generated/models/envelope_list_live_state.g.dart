// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_live_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListLiveState _$EnvelopeListLiveStateFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListLiveState(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => LiveState.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListLiveStateToJson(
  _EnvelopeListLiveState instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
