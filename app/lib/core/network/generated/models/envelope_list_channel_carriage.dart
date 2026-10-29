// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'channel_carriage.dart';
import 'error_body.dart';

part 'envelope_list_channel_carriage.freezed.dart';
part 'envelope_list_channel_carriage.g.dart';

@Freezed()
abstract class EnvelopeListChannelCarriage with _$EnvelopeListChannelCarriage {
  const factory EnvelopeListChannelCarriage({
    required List<ChannelCarriage>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListChannelCarriage;
  
  factory EnvelopeListChannelCarriage.fromJson(Map<String, Object?> json) => _$EnvelopeListChannelCarriageFromJson(json);
}
