// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commentator_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommentatorRef _$CommentatorRefFromJson(Map<String, dynamic> json) =>
    _CommentatorRef(
      audio: json['audio'] as String?,
      id: (json['id'] as num).toInt(),
      image: json['image'] as String?,
      name: json['name'] as String,
    );

Map<String, dynamic> _$CommentatorRefToJson(_CommentatorRef instance) =>
    <String, dynamic>{
      'audio': ?instance.audio,
      'id': instance.id,
      'image': ?instance.image,
      'name': instance.name,
    };
