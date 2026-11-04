// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'lineup_player.dart';

part 'lineup_side.freezed.dart';
part 'lineup_side.g.dart';

@Freezed()
abstract class LineupSide with _$LineupSide {
  const factory LineupSide({
    required String? formation,
    required List<LineupPlayer> players,
  }) = _LineupSide;
  
  factory LineupSide.fromJson(Map<String, Object?> json) => _$LineupSideFromJson(json);
}
