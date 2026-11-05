// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lineup_player.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineupPlayer {

@JsonKey(name: 'is_starter') bool get isStarter; String get name; int? get number; String? get position;
/// Create a copy of LineupPlayer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineupPlayerCopyWith<LineupPlayer> get copyWith => _$LineupPlayerCopyWithImpl<LineupPlayer>(this as LineupPlayer, _$identity);

  /// Serializes this LineupPlayer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LineupPlayer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineupPlayer&&(identical(other.isStarter, _this.isStarter) || other.isStarter == _this.isStarter)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.position, _this.position) || other.position == _this.position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LineupPlayer;
  return Object.hash(runtimeType,_this.isStarter,_this.name,_this.number,_this.position);
}

@override
String toString() {
  final _this = this as LineupPlayer;
  return 'LineupPlayer(isStarter: ${_this.isStarter}, name: ${_this.name}, number: ${_this.number}, position: ${_this.position})';
}


}

/// @nodoc
abstract mixin class $LineupPlayerCopyWith<$Res>  {
  factory $LineupPlayerCopyWith(LineupPlayer value, $Res Function(LineupPlayer) _then) = _$LineupPlayerCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'is_starter') bool isStarter, String name, int? number, String? position
});




}
/// @nodoc
class _$LineupPlayerCopyWithImpl<$Res>
    implements $LineupPlayerCopyWith<$Res> {
  _$LineupPlayerCopyWithImpl(this._self, this._then);

  final LineupPlayer _self;
  final $Res Function(LineupPlayer) _then;

/// Create a copy of LineupPlayer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isStarter = null,Object? name = null,Object? number = freezed,Object? position = freezed,}) {
  return _then(LineupPlayer(
isStarter: null == isStarter ? _self.isStarter : isStarter // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LineupPlayer].
extension LineupPlayerPatterns on LineupPlayer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineupPlayer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineupPlayer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineupPlayer value)  $default,){
final _that = this;
switch (_that) {
case _LineupPlayer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineupPlayer value)?  $default,){
final _that = this;
switch (_that) {
case _LineupPlayer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_starter')  bool isStarter,  String name,  int? number,  String? position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineupPlayer() when $default != null:
return $default(_that.isStarter,_that.name,_that.number,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_starter')  bool isStarter,  String name,  int? number,  String? position)  $default,) {final _that = this;
switch (_that) {
case _LineupPlayer():
return $default(_that.isStarter,_that.name,_that.number,_that.position);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'is_starter')  bool isStarter,  String name,  int? number,  String? position)?  $default,) {final _that = this;
switch (_that) {
case _LineupPlayer() when $default != null:
return $default(_that.isStarter,_that.name,_that.number,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineupPlayer implements LineupPlayer {
  const _LineupPlayer({@JsonKey(name: 'is_starter') required this.isStarter, required this.name, required this.number, required this.position});
  factory _LineupPlayer.fromJson(Map<String, dynamic> json) => _$LineupPlayerFromJson(json);

@override@JsonKey(name: 'is_starter') final  bool isStarter;
@override final  String name;
@override final  int? number;
@override final  String? position;

/// Create a copy of LineupPlayer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineupPlayerCopyWith<_LineupPlayer> get copyWith => __$LineupPlayerCopyWithImpl<_LineupPlayer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineupPlayerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineupPlayer&&(identical(other.isStarter, isStarter) || other.isStarter == isStarter)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isStarter,name,number,position);
}

@override
String toString() {
    return 'LineupPlayer(isStarter: $isStarter, name: $name, number: $number, position: $position)';
}


}

/// @nodoc
abstract mixin class _$LineupPlayerCopyWith<$Res> implements $LineupPlayerCopyWith<$Res> {
  factory _$LineupPlayerCopyWith(_LineupPlayer value, $Res Function(_LineupPlayer) _then) = __$LineupPlayerCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'is_starter') bool isStarter, String name, int? number, String? position
});




}
/// @nodoc
class __$LineupPlayerCopyWithImpl<$Res>
    implements _$LineupPlayerCopyWith<$Res> {
  __$LineupPlayerCopyWithImpl(this._self, this._then);

  final _LineupPlayer _self;
  final $Res Function(_LineupPlayer) _then;

/// Create a copy of LineupPlayer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isStarter = null,Object? name = null,Object? number = freezed,Object? position = freezed,}) {
  return _then(_LineupPlayer(
isStarter: null == isStarter ? _self.isStarter : isStarter // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
