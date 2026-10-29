// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'live_state.dart';

part 'envelope_list_live_state.freezed.dart';
part 'envelope_list_live_state.g.dart';

@Freezed()
abstract class EnvelopeListLiveState with _$EnvelopeListLiveState {
  const factory EnvelopeListLiveState({
    required List<LiveState>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListLiveState;
  
  factory EnvelopeListLiveState.fromJson(Map<String, Object?> json) => _$EnvelopeListLiveStateFromJson(json);
}
