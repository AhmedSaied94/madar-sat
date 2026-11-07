// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveState {

 bool get estimated;@JsonKey(name: 'match_id') int get matchId; String? get minute; Period? get period; Score? get score; Status get status;@JsonKey(name: 'status_label') String? get statusLabel;@JsonKey(name: 'status_updated_at') DateTime? get statusUpdatedAt;@JsonKey(name: 'event_count') int get eventCount;
/// Create a copy of LiveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveStateCopyWith<LiveState> get copyWith => _$LiveStateCopyWithImpl<LiveState>(this as LiveState, _$identity);

  /// Serializes this LiveState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveState&&(identical(other.estimated, _this.estimated) || other.estimated == _this.estimated)&&(identical(other.matchId, _this.matchId) || other.matchId == _this.matchId)&&(identical(other.minute, _this.minute) || other.minute == _this.minute)&&(identical(other.period, _this.period) || other.period == _this.period)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.statusLabel, _this.statusLabel) || other.statusLabel == _this.statusLabel)&&(identical(other.statusUpdatedAt, _this.statusUpdatedAt) || other.statusUpdatedAt == _this.statusUpdatedAt)&&(identical(other.eventCount, _this.eventCount) || other.eventCount == _this.eventCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveState;
  return Object.hash(runtimeType,_this.estimated,_this.matchId,_this.minute,_this.period,_this.score,_this.status,_this.statusLabel,_this.statusUpdatedAt,_this.eventCount);
}

@override
String toString() {
  final _this = this as LiveState;
  return 'LiveState(estimated: ${_this.estimated}, matchId: ${_this.matchId}, minute: ${_this.minute}, period: ${_this.period}, score: ${_this.score}, status: ${_this.status}, statusLabel: ${_this.statusLabel}, statusUpdatedAt: ${_this.statusUpdatedAt}, eventCount: ${_this.eventCount})';
}


}

/// @nodoc
abstract mixin class $LiveStateCopyWith<$Res>  {
  factory $LiveStateCopyWith(LiveState value, $Res Function(LiveState) _then) = _$LiveStateCopyWithImpl;
@useResult
$Res call({
 bool estimated,@JsonKey(name: 'match_id') int matchId, String? minute, Period? period, Score? score, Status status,@JsonKey(name: 'status_label') String? statusLabel,@JsonKey(name: 'status_updated_at') DateTime? statusUpdatedAt,@JsonKey(name: 'event_count') int eventCount
});


$ScoreCopyWith<$Res>? get score;

}
/// @nodoc
class _$LiveStateCopyWithImpl<$Res>
    implements $LiveStateCopyWith<$Res> {
  _$LiveStateCopyWithImpl(this._self, this._then);

  final LiveState _self;
  final $Res Function(LiveState) _then;

/// Create a copy of LiveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? estimated = null,Object? matchId = null,Object? minute = freezed,Object? period = freezed,Object? score = freezed,Object? status = null,Object? statusLabel = freezed,Object? statusUpdatedAt = freezed,Object? eventCount = null,}) {
  return _then(LiveState(
estimated: null == estimated ? _self.estimated : estimated // ignore: cast_nullable_to_non_nullable
as bool,matchId: null == matchId ? _self.matchId : matchId // ignore: cast_nullable_to_non_nullable
as int,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String?,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as Period?,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as Score?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as Status,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,statusUpdatedAt: freezed == statusUpdatedAt ? _self.statusUpdatedAt : statusUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of LiveState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScoreCopyWith<$Res>? get score {
    if (_self.score == null) {
    return null;
  }

  return $ScoreCopyWith<$Res>(_self.score!, (value) {
    return _then(_self.copyWith(score: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveState].
extension LiveStatePatterns on LiveState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveState value)  $default,){
final _that = this;
switch (_that) {
case _LiveState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveState value)?  $default,){
final _that = this;
switch (_that) {
case _LiveState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool estimated, @JsonKey(name: 'match_id')  int matchId,  String? minute,  Period? period,  Score? score,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'status_updated_at')  DateTime? statusUpdatedAt, @JsonKey(name: 'event_count')  int eventCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveState() when $default != null:
return $default(_that.estimated,_that.matchId,_that.minute,_that.period,_that.score,_that.status,_that.statusLabel,_that.statusUpdatedAt,_that.eventCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool estimated, @JsonKey(name: 'match_id')  int matchId,  String? minute,  Period? period,  Score? score,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'status_updated_at')  DateTime? statusUpdatedAt, @JsonKey(name: 'event_count')  int eventCount)  $default,) {final _that = this;
switch (_that) {
case _LiveState():
return $default(_that.estimated,_that.matchId,_that.minute,_that.period,_that.score,_that.status,_that.statusLabel,_that.statusUpdatedAt,_that.eventCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool estimated, @JsonKey(name: 'match_id')  int matchId,  String? minute,  Period? period,  Score? score,  Status status, @JsonKey(name: 'status_label')  String? statusLabel, @JsonKey(name: 'status_updated_at')  DateTime? statusUpdatedAt, @JsonKey(name: 'event_count')  int eventCount)?  $default,) {final _that = this;
switch (_that) {
case _LiveState() when $default != null:
return $default(_that.estimated,_that.matchId,_that.minute,_that.period,_that.score,_that.status,_that.statusLabel,_that.statusUpdatedAt,_that.eventCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveState implements LiveState {
  const _LiveState({required this.estimated, @JsonKey(name: 'match_id') required this.matchId, required this.minute, required this.period, required this.score, required this.status, @JsonKey(name: 'status_label') required this.statusLabel, @JsonKey(name: 'status_updated_at') required this.statusUpdatedAt, @JsonKey(name: 'event_count') this.eventCount = 0});
  factory _LiveState.fromJson(Map<String, dynamic> json) => _$LiveStateFromJson(json);

@override final  bool estimated;
@override@JsonKey(name: 'match_id') final  int matchId;
@override final  String? minute;
@override final  Period? period;
@override final  Score? score;
@override final  Status status;
@override@JsonKey(name: 'status_label') final  String? statusLabel;
@override@JsonKey(name: 'status_updated_at') final  DateTime? statusUpdatedAt;
@override@JsonKey(name: 'event_count') final  int eventCount;

/// Create a copy of LiveState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveStateCopyWith<_LiveState> get copyWith => __$LiveStateCopyWithImpl<_LiveState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveState&&(identical(other.estimated, estimated) || other.estimated == estimated)&&(identical(other.matchId, matchId) || other.matchId == matchId)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.period, period) || other.period == period)&&(identical(other.score, score) || other.score == score)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&(identical(other.statusUpdatedAt, statusUpdatedAt) || other.statusUpdatedAt == statusUpdatedAt)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,estimated,matchId,minute,period,score,status,statusLabel,statusUpdatedAt,eventCount);
}

@override
String toString() {
    return 'LiveState(estimated: $estimated, matchId: $matchId, minute: $minute, period: $period, score: $score, status: $status, statusLabel: $statusLabel, statusUpdatedAt: $statusUpdatedAt, eventCount: $eventCount)';
}


}

/// @nodoc
abstract mixin class _$LiveStateCopyWith<$Res> implements $LiveStateCopyWith<$Res> {
  factory _$LiveStateCopyWith(_LiveState value, $Res Function(_LiveState) _then) = __$LiveStateCopyWithImpl;
@override @useResult
$Res call({
 bool estimated,@JsonKey(name: 'match_id') int matchId, String? minute, Period? period, Score? score, Status status,@JsonKey(name: 'status_label') String? statusLabel,@JsonKey(name: 'status_updated_at') DateTime? statusUpdatedAt,@JsonKey(name: 'event_count') int eventCount
});


@override $ScoreCopyWith<$Res>? get score;

}
/// @nodoc
class __$LiveStateCopyWithImpl<$Res>
    implements _$LiveStateCopyWith<$Res> {
  __$LiveStateCopyWithImpl(this._self, this._then);

  final _LiveState _self;
  final $Res Function(_LiveState) _then;

/// Create a copy of LiveState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? estimated = null,Object? matchId = null,Object? minute = freezed,Object? period = freezed,Object? score = freezed,Object? status = null,Object? statusLabel = freezed,Object? statusUpdatedAt = freezed,Object? eventCount = null,}) {
  return _then(_LiveState(
estimated: null == estimated ? _self.estimated : estimated // ignore: cast_nullable_to_non_nullable
as bool,matchId: null == matchId ? _self.matchId : matchId // ignore: cast_nullable_to_non_nullable
as int,minute: freezed == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String?,period: freezed == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as Period?,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as Score?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as Status,statusLabel: freezed == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String?,statusUpdatedAt: freezed == statusUpdatedAt ? _self.statusUpdatedAt : statusUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of LiveState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScoreCopyWith<$Res>? get score {
    if (_self.score == null) {
    return null;
  }

  return $ScoreCopyWith<$Res>(_self.score!, (value) {
    return _then(_self.copyWith(score: value));
  });
}
}

// dart format on
