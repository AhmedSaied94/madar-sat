// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_ref.dart';
import 'rights_holder_carriage.dart';

part 'rights_holder_detail.freezed.dart';
part 'rights_holder_detail.g.dart';

@Freezed()
abstract class RightsHolderDetail with _$RightsHolderDetail {
  const factory RightsHolderDetail({
    required List<RightsHolderCarriage> carriages,
    required List<NamedRef> competitions,
    required int id,
    required String? logo,
    required String name,
    @JsonKey(name: 'sort_order')
    required int? sortOrder,
  }) = _RightsHolderDetail;
  
  factory RightsHolderDetail.fromJson(Map<String, Object?> json) => _$RightsHolderDetailFromJson(json);
}
