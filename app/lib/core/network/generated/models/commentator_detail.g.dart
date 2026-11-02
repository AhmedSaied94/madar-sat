// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commentator_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommentatorDetail _$CommentatorDetailFromJson(Map<String, dynamic> json) =>
    _CommentatorDetail(
      audio: json['audio'] as String?,
      id: (json['id'] as num).toInt(),
      image: json['image'] as String?,
      name: json['name'] as String,
      upcoming: (json['upcoming'] as List<dynamic>)
          .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CommentatorDetailToJson(_CommentatorDetail instance) =>
    <String, dynamic>{
      'audio': ?instance.audio,
      'id': instance.id,
      'image': ?instance.image,
      'name': instance.name,
      'upcoming': instance.upcoming,
    };
