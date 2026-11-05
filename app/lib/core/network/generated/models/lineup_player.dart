// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'lineup_player.freezed.dart';
part 'lineup_player.g.dart';

@Freezed()
abstract class LineupPlayer with _$LineupPlayer {
  const factory LineupPlayer({
    @JsonKey(name: 'is_starter')
    required bool isStarter,
    required String name,
    required int? number,
    required String? position,
  }) = _LineupPlayer;
  
  factory LineupPlayer.fromJson(Map<String, Object?> json) => _$LineupPlayerFromJson(json);
}
