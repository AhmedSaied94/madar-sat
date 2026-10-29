// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rights_holder_carriage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RightsHolderCarriage {

 Access get access; Beam? get beam; List<RightsHolderFrequency> get frequencies; int get id; List<SatelliteRef> get satellites;
/// Create a copy of RightsHolderCarriage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RightsHolderCarriageCopyWith<RightsHolderCarriage> get copyWith => _$RightsHolderCarriageCopyWithImpl<RightsHolderCarriage>(this as RightsHolderCarriage, _$identity);

  /// Serializes this RightsHolderCarriage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RightsHolderCarriage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RightsHolderCarriage&&(identical(other.access, _this.access) || other.access == _this.access)&&(identical(other.beam, _this.beam) || other.beam == _this.beam)&&const DeepCollectionEquality().equals(other.frequencies, _this.frequencies)&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.satellites, _this.satellites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RightsHolderCarriage;
  return Object.hash(runtimeType,_this.access,_this.beam,const DeepCollectionEquality().hash(_this.frequencies),_this.id,const DeepCollectionEquality().hash(_this.satellites));
}

@override
String toString() {
  final _this = this as RightsHolderCarriage;
  return 'RightsHolderCarriage(access: ${_this.access}, beam: ${_this.beam}, frequencies: ${_this.frequencies}, id: ${_this.id}, satellites: ${_this.satellites})';
}


}

/// @nodoc
abstract mixin class $RightsHolderCarriageCopyWith<$Res>  {
  factory $RightsHolderCarriageCopyWith(RightsHolderCarriage value, $Res Function(RightsHolderCarriage) _then) = _$RightsHolderCarriageCopyWithImpl;
@useResult
$Res call({
 Access access, Beam? beam, List<RightsHolderFrequency> frequencies, int id, List<SatelliteRef> satellites
});




}
/// @nodoc
class _$RightsHolderCarriageCopyWithImpl<$Res>
    implements $RightsHolderCarriageCopyWith<$Res> {
  _$RightsHolderCarriageCopyWithImpl(this._self, this._then);

  final RightsHolderCarriage _self;
  final $Res Function(RightsHolderCarriage) _then;

/// Create a copy of RightsHolderCarriage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? access = null,Object? beam = freezed,Object? frequencies = null,Object? id = null,Object? satellites = null,}) {
  return _then(RightsHolderCarriage(
access: null == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access,beam: freezed == beam ? _self.beam : beam // ignore: cast_nullable_to_non_nullable
as Beam?,frequencies: null == frequencies ? _self.frequencies : frequencies // ignore: cast_nullable_to_non_nullable
as List<RightsHolderFrequency>,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,satellites: null == satellites ? _self.satellites : satellites // ignore: cast_nullable_to_non_nullable
as List<SatelliteRef>,
  ));
}

}


/// Adds pattern-matching-related methods to [RightsHolderCarriage].
extension RightsHolderCarriagePatterns on RightsHolderCarriage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RightsHolderCarriage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RightsHolderCarriage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RightsHolderCarriage value)  $default,){
final _that = this;
switch (_that) {
case _RightsHolderCarriage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RightsHolderCarriage value)?  $default,){
final _that = this;
switch (_that) {
case _RightsHolderCarriage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Access access,  Beam? beam,  List<RightsHolderFrequency> frequencies,  int id,  List<SatelliteRef> satellites)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RightsHolderCarriage() when $default != null:
return $default(_that.access,_that.beam,_that.frequencies,_that.id,_that.satellites);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Access access,  Beam? beam,  List<RightsHolderFrequency> frequencies,  int id,  List<SatelliteRef> satellites)  $default,) {final _that = this;
switch (_that) {
case _RightsHolderCarriage():
return $default(_that.access,_that.beam,_that.frequencies,_that.id,_that.satellites);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Access access,  Beam? beam,  List<RightsHolderFrequency> frequencies,  int id,  List<SatelliteRef> satellites)?  $default,) {final _that = this;
switch (_that) {
case _RightsHolderCarriage() when $default != null:
return $default(_that.access,_that.beam,_that.frequencies,_that.id,_that.satellites);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RightsHolderCarriage implements RightsHolderCarriage {
  const _RightsHolderCarriage({required this.access, required this.beam, required  List<RightsHolderFrequency> frequencies, required this.id, required  List<SatelliteRef> satellites}): _frequencies = frequencies,_satellites = satellites;
  factory _RightsHolderCarriage.fromJson(Map<String, dynamic> json) => _$RightsHolderCarriageFromJson(json);

@override final  Access access;
@override final  Beam? beam;
 final  List<RightsHolderFrequency> _frequencies;
@override List<RightsHolderFrequency> get frequencies {
  if (_frequencies is EqualUnmodifiableListView) return _frequencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_frequencies);
}

@override final  int id;
 final  List<SatelliteRef> _satellites;
@override List<SatelliteRef> get satellites {
  if (_satellites is EqualUnmodifiableListView) return _satellites;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_satellites);
}


/// Create a copy of RightsHolderCarriage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RightsHolderCarriageCopyWith<_RightsHolderCarriage> get copyWith => __$RightsHolderCarriageCopyWithImpl<_RightsHolderCarriage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RightsHolderCarriageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RightsHolderCarriage&&(identical(other.access, access) || other.access == access)&&(identical(other.beam, beam) || other.beam == beam)&&const DeepCollectionEquality().equals(other.frequencies, _frequencies)&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.satellites, _satellites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,access,beam,const DeepCollectionEquality().hash(_frequencies),id,const DeepCollectionEquality().hash(_satellites));
}

@override
String toString() {
    return 'RightsHolderCarriage(access: $access, beam: $beam, frequencies: $frequencies, id: $id, satellites: $satellites)';
}


}

/// @nodoc
abstract mixin class _$RightsHolderCarriageCopyWith<$Res> implements $RightsHolderCarriageCopyWith<$Res> {
  factory _$RightsHolderCarriageCopyWith(_RightsHolderCarriage value, $Res Function(_RightsHolderCarriage) _then) = __$RightsHolderCarriageCopyWithImpl;
@override @useResult
$Res call({
 Access access, Beam? beam, List<RightsHolderFrequency> frequencies, int id, List<SatelliteRef> satellites
});




}
/// @nodoc
class __$RightsHolderCarriageCopyWithImpl<$Res>
    implements _$RightsHolderCarriageCopyWith<$Res> {
  __$RightsHolderCarriageCopyWithImpl(this._self, this._then);

  final _RightsHolderCarriage _self;
  final $Res Function(_RightsHolderCarriage) _then;

/// Create a copy of RightsHolderCarriage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? access = null,Object? beam = freezed,Object? frequencies = null,Object? id = null,Object? satellites = null,}) {
  return _then(_RightsHolderCarriage(
access: null == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access,beam: freezed == beam ? _self.beam : beam // ignore: cast_nullable_to_non_nullable
as Beam?,frequencies: null == frequencies ? _self._frequencies : frequencies // ignore: cast_nullable_to_non_nullable
as List<RightsHolderFrequency>,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,satellites: null == satellites ? _self._satellites : satellites // ignore: cast_nullable_to_non_nullable
as List<SatelliteRef>,
  ));
}


}

// dart format on
