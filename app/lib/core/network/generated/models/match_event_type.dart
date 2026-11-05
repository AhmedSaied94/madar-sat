// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum MatchEventType {
  @JsonValue('goal')
  goal('goal'),
  @JsonValue('own_goal')
  ownGoal('own_goal'),
  @JsonValue('penalty')
  penalty('penalty'),
  @JsonValue('missed_penalty')
  missedPenalty('missed_penalty'),
  @JsonValue('red_card')
  redCard('red_card'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const MatchEventType(this.json);

  factory MatchEventType.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<MatchEventType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
