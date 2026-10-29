// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'access.dart';
import 'beam.dart';
import 'category.dart';
import 'commentator_ref.dart';
import 'frequency.dart';
import 'kind.dart';
import 'satellite_ref.dart';

part 'carriage_entry.freezed.dart';
part 'carriage_entry.g.dart';

@Freezed()
abstract class CarriageEntry with _$CarriageEntry {
  const factory CarriageEntry({
    required Access? access,
    required Beam? beam,
    required Category? category,
    required List<CommentatorRef> commentators,
    required String? country,
    @JsonKey(name: 'display_name')
    required String? displayName,
    required Frequency? frequency,
    @JsonKey(name: 'frequency_changed_at')
    required DateTime? frequencyChangedAt,
    @JsonKey(name: 'frequency_note')
    required String? frequencyNote,
    required int id,
    required Kind kind,
    required String? logo,
    required String name,
    required String? package,
    required String? provider,
    required SatelliteRef? satellite,
  }) = _CarriageEntry;
  
  factory CarriageEntry.fromJson(Map<String, Object?> json) => _$CarriageEntryFromJson(json);
}
