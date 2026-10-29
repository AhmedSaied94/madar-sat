// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validation_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ValidationError _$ValidationErrorFromJson(Map<String, dynamic> json) =>
    _ValidationError(
      loc: json['loc'] as List<dynamic>,
      msg: json['msg'] as String,
      type: json['type'] as String,
      ctx: json['ctx'],
      input: json['input'],
    );

Map<String, dynamic> _$ValidationErrorToJson(_ValidationError instance) =>
    <String, dynamic>{
      'loc': instance.loc,
      'msg': instance.msg,
      'type': instance.type,
      'ctx': instance.ctx,
      'input': instance.input,
    };
