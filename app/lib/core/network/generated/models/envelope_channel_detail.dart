// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'channel_detail.dart';
import 'error_body.dart';

part 'envelope_channel_detail.freezed.dart';
part 'envelope_channel_detail.g.dart';

@Freezed()
abstract class EnvelopeChannelDetail with _$EnvelopeChannelDetail {
  const factory EnvelopeChannelDetail({
    required ChannelDetail? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeChannelDetail;
  
  factory EnvelopeChannelDetail.fromJson(Map<String, Object?> json) => _$EnvelopeChannelDetailFromJson(json);
}
