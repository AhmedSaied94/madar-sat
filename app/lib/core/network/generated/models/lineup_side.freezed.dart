// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lineup_side.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineupSide {

 String? get formation; List<LineupPlayer> get players;
/// Create a copy of LineupSide
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineupSideCopyWith<LineupSide> get copyWith => _$LineupSideCopyWithImpl<LineupSide>(this as LineupSide, _$identity);

  /// Serializes this LineupSide to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LineupSide;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineupSide&&(identical(other.formation, _this.formation) || other.formation == _this.formation)&&const DeepCollectionEquality().equals(other.players, _this.players));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LineupSide;
  return Object.hash(runtimeType,_this.formation,const DeepCollectionEquality().hash(_this.players));
}

@override
String toString() {
  final _this = this as LineupSide;
  return 'LineupSide(formation: ${_this.formation}, players: ${_this.players})';
}


}

/// @nodoc
abstract mixin class $LineupSideCopyWith<$Res>  {
  factory $LineupSideCopyWith(LineupSide value, $Res Function(LineupSide) _then) = _$LineupSideCopyWithImpl;
@useResult
$Res call({
 String? formation, List<LineupPlayer> players
});




}
/// @nodoc
class _$LineupSideCopyWithImpl<$Res>
    implements $LineupSideCopyWith<$Res> {
  _$LineupSideCopyWithImpl(this._self, this._then);

  final LineupSide _self;
  final $Res Function(LineupSide) _then;

/// Create a copy of LineupSide
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? formation = freezed,Object? players = null,}) {
  return _then(LineupSide(
formation: freezed == formation ? _self.formation : formation // ignore: cast_nullable_to_non_nullable
as String?,players: null == players ? _self.players : players // ignore: cast_nullable_to_non_nullable
as List<LineupPlayer>,
  ));
}

}


/// Adds pattern-matching-related methods to [LineupSide].
extension LineupSidePatterns on LineupSide {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineupSide value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineupSide() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineupSide value)  $default,){
final _that = this;
switch (_that) {
case _LineupSide():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineupSide value)?  $default,){
final _that = this;
switch (_that) {
case _LineupSide() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? formation,  List<LineupPlayer> players)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineupSide() when $default != null:
return $default(_that.formation,_that.players);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? formation,  List<LineupPlayer> players)  $default,) {final _that = this;
switch (_that) {
case _LineupSide():
return $default(_that.formation,_that.players);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? formation,  List<LineupPlayer> players)?  $default,) {final _that = this;
switch (_that) {
case _LineupSide() when $default != null:
return $default(_that.formation,_that.players);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineupSide implements LineupSide {
  const _LineupSide({required this.formation, required  List<LineupPlayer> players}): _players = players;
  factory _LineupSide.fromJson(Map<String, dynamic> json) => _$LineupSideFromJson(json);

@override final  String? formation;
 final  List<LineupPlayer> _players;
@override List<LineupPlayer> get players {
  if (_players is EqualUnmodifiableListView) return _players;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_players);
}


/// Create a copy of LineupSide
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineupSideCopyWith<_LineupSide> get copyWith => __$LineupSideCopyWithImpl<_LineupSide>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineupSideToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineupSide&&(identical(other.formation, formation) || other.formation == formation)&&const DeepCollectionEquality().equals(other.players, _players));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,formation,const DeepCollectionEquality().hash(_players));
}

@override
String toString() {
    return 'LineupSide(formation: $formation, players: $players)';
}


}

/// @nodoc
abstract mixin class _$LineupSideCopyWith<$Res> implements $LineupSideCopyWith<$Res> {
  factory _$LineupSideCopyWith(_LineupSide value, $Res Function(_LineupSide) _then) = __$LineupSideCopyWithImpl;
@override @useResult
$Res call({
 String? formation, List<LineupPlayer> players
});




}
/// @nodoc
class __$LineupSideCopyWithImpl<$Res>
    implements _$LineupSideCopyWith<$Res> {
  __$LineupSideCopyWithImpl(this._self, this._then);

  final _LineupSide _self;
  final $Res Function(_LineupSide) _then;

/// Create a copy of LineupSide
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? formation = freezed,Object? players = null,}) {
  return _then(_LineupSide(
formation: freezed == formation ? _self.formation : formation // ignore: cast_nullable_to_non_nullable
as String?,players: null == players ? _self._players : players // ignore: cast_nullable_to_non_nullable
as List<LineupPlayer>,
  ));
}


}

// dart format on
