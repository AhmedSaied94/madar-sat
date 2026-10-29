// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_ref.freezed.dart';
part 'team_ref.g.dart';

@Freezed()
abstract class TeamRef with _$TeamRef {
  const factory TeamRef({
    required int? id,
    required String? logo,
    required String name,
  }) = _TeamRef;
  
  factory TeamRef.fromJson(Map<String, Object?> json) => _$TeamRefFromJson(json);
}
