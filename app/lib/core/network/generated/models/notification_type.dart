// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

/// The seven types of SD §6.8; unknown types are refused (research R4).
@JsonEnum()
enum NotificationType {
  @JsonValue('kickoff_reminder')
  kickoffReminder('kickoff_reminder'),
  @JsonValue('goal')
  goal('goal'),
  @JsonValue('final_score')
  finalScore('final_score'),
  @JsonValue('match_started')
  matchStarted('match_started'),
  @JsonValue('channels_updated')
  channelsUpdated('channels_updated'),
  @JsonValue('frequency_changed')
  frequencyChanged('frequency_changed'),
  @JsonValue('announcement')
  announcement('announcement'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const NotificationType(this.json);

  factory NotificationType.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<NotificationType> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
