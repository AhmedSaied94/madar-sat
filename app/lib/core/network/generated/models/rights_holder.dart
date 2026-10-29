// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'rights_holder.freezed.dart';
part 'rights_holder.g.dart';

@Freezed()
abstract class RightsHolder with _$RightsHolder {
  const factory RightsHolder({
    required int id,
    required String? logo,
    required String name,
    @JsonKey(name: 'sort_order')
    required int? sortOrder,
  }) = _RightsHolder;
  
  factory RightsHolder.fromJson(Map<String, Object?> json) => _$RightsHolderFromJson(json);
}
