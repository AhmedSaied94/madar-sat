// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'score.freezed.dart';
part 'score.g.dart';

@Freezed()
abstract class Score with _$Score {
  const factory Score({
    required int away,
    @JsonKey(name: 'away_pen')
    required int? awayPen,
    required int home,
    @JsonKey(name: 'home_pen')
    required int? homePen,
  }) = _Score;
  
  factory Score.fromJson(Map<String, Object?> json) => _$ScoreFromJson(json);
}
