// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatchEvent {

 String get minute; String? get player; MatchEventSide get side; MatchEventType get type;
/// Create a copy of MatchEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchEventCopyWith<MatchEvent> get copyWith => _$MatchEventCopyWithImpl<MatchEvent>(this as MatchEvent, _$identity);

  /// Serializes this MatchEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MatchEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchEvent&&(identical(other.minute, _this.minute) || other.minute == _this.minute)&&(identical(other.player, _this.player) || other.player == _this.player)&&(identical(other.side, _this.side) || other.side == _this.side)&&(identical(other.type, _this.type) || other.type == _this.type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MatchEvent;
  return Object.hash(runtimeType,_this.minute,_this.player,_this.side,_this.type);
}

@override
String toString() {
  final _this = this as MatchEvent;
  return 'MatchEvent(minute: ${_this.minute}, player: ${_this.player}, side: ${_this.side}, type: ${_this.type})';
}


}

/// @nodoc
abstract mixin class $MatchEventCopyWith<$Res>  {
  factory $MatchEventCopyWith(MatchEvent value, $Res Function(MatchEvent) _then) = _$MatchEventCopyWithImpl;
@useResult
$Res call({
 String minute, String? player, MatchEventSide side, MatchEventType type
});




}
/// @nodoc
class _$MatchEventCopyWithImpl<$Res>
    implements $MatchEventCopyWith<$Res> {
  _$MatchEventCopyWithImpl(this._self, this._then);

  final MatchEvent _self;
  final $Res Function(MatchEvent) _then;

/// Create a copy of MatchEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minute = null,Object? player = freezed,Object? side = null,Object? type = null,}) {
  return _then(MatchEvent(
minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String,player: freezed == player ? _self.player : player // ignore: cast_nullable_to_non_nullable
as String?,side: null == side ? _self.side : side // ignore: cast_nullable_to_non_nullable
as MatchEventSide,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MatchEventType,
  ));
}

}


/// Adds pattern-matching-related methods to [MatchEvent].
extension MatchEventPatterns on MatchEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchEvent value)  $default,){
final _that = this;
switch (_that) {
case _MatchEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchEvent value)?  $default,){
final _that = this;
switch (_that) {
case _MatchEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String minute,  String? player,  MatchEventSide side,  MatchEventType type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchEvent() when $default != null:
return $default(_that.minute,_that.player,_that.side,_that.type);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String minute,  String? player,  MatchEventSide side,  MatchEventType type)  $default,) {final _that = this;
switch (_that) {
case _MatchEvent():
return $default(_that.minute,_that.player,_that.side,_that.type);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String minute,  String? player,  MatchEventSide side,  MatchEventType type)?  $default,) {final _that = this;
switch (_that) {
case _MatchEvent() when $default != null:
return $default(_that.minute,_that.player,_that.side,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchEvent implements MatchEvent {
  const _MatchEvent({required this.minute, required this.player, required this.side, required this.type});
  factory _MatchEvent.fromJson(Map<String, dynamic> json) => _$MatchEventFromJson(json);

@override final  String minute;
@override final  String? player;
@override final  MatchEventSide side;
@override final  MatchEventType type;

/// Create a copy of MatchEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchEventCopyWith<_MatchEvent> get copyWith => __$MatchEventCopyWithImpl<_MatchEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchEvent&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.player, player) || other.player == player)&&(identical(other.side, side) || other.side == side)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,minute,player,side,type);
}

@override
String toString() {
    return 'MatchEvent(minute: $minute, player: $player, side: $side, type: $type)';
}


}

/// @nodoc
abstract mixin class _$MatchEventCopyWith<$Res> implements $MatchEventCopyWith<$Res> {
  factory _$MatchEventCopyWith(_MatchEvent value, $Res Function(_MatchEvent) _then) = __$MatchEventCopyWithImpl;
@override @useResult
$Res call({
 String minute, String? player, MatchEventSide side, MatchEventType type
});




}
/// @nodoc
class __$MatchEventCopyWithImpl<$Res>
    implements _$MatchEventCopyWith<$Res> {
  __$MatchEventCopyWithImpl(this._self, this._then);

  final _MatchEvent _self;
  final $Res Function(_MatchEvent) _then;

/// Create a copy of MatchEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minute = null,Object? player = freezed,Object? side = null,Object? type = null,}) {
  return _then(_MatchEvent(
minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as String,player: freezed == player ? _self.player : player // ignore: cast_nullable_to_non_nullable
as String?,side: null == side ? _self.side : side // ignore: cast_nullable_to_non_nullable
as MatchEventSide,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MatchEventType,
  ));
}


}

// dart format on
