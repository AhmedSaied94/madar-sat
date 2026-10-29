// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum Period {
  @JsonValue('1H')
  value1h('1H'),
  @JsonValue('2H')
  value2h('2H'),
  @JsonValue('ET1')
  et1('ET1'),
  @JsonValue('ET2')
  et2('ET2'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const Period(this.json);

  factory Period.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<Period> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
