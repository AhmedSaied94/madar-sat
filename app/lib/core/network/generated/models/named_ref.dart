// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'named_ref.freezed.dart';
part 'named_ref.g.dart';

/// A minimal named entity reference: ``{id, name, logo}``.
@Freezed()
abstract class NamedRef with _$NamedRef {
  const factory NamedRef({
    required int id,
    required String? logo,
    required String name,
  }) = _NamedRef;
  
  factory NamedRef.fromJson(Map<String, Object?> json) => _$NamedRefFromJson(json);
}
