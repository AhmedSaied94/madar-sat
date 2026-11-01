// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum NotificationPrefLeadMin {
  @JsonValue(5)
  value5(5),
  @JsonValue(15)
  value15(15),
  @JsonValue(30)
  value30(30),
  @JsonValue(60)
  value60(60),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const NotificationPrefLeadMin(this.json);

  factory NotificationPrefLeadMin.fromJson(int json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final int? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<NotificationPrefLeadMin> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
