// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'sport.dart';

part 'competition.freezed.dart';
part 'competition.g.dart';

@Freezed()
abstract class Competition with _$Competition {
  const factory Competition({
    required int id,
    required String? logo,
    required String name,
    required int? priority,
    required Sport sport,
  }) = _Competition;
  
  factory Competition.fromJson(Map<String, Object?> json) => _$CompetitionFromJson(json);
}
