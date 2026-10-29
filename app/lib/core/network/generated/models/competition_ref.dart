// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'competition_ref.freezed.dart';
part 'competition_ref.g.dart';

@Freezed()
abstract class CompetitionRef with _$CompetitionRef {
  const factory CompetitionRef({
    required int? id,
    required String? logo,
    required String name,
    required int? priority,
    required String? stage,
  }) = _CompetitionRef;
  
  factory CompetitionRef.fromJson(Map<String, Object?> json) => _$CompetitionRefFromJson(json);
}
