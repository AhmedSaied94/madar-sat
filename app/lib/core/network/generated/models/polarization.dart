// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum Polarization {
  @JsonValue('H')
  h('H'),
  @JsonValue('V')
  v('V'),
  @JsonValue('L')
  l('L'),
  @JsonValue('R')
  r('R'),
  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const Polarization(this.json);

  factory Polarization.fromJson(String json) => values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();
  /// Returns all defined enum values excluding the $unknown value.
  static List<Polarization> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
