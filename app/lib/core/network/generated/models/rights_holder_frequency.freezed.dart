// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rights_holder_frequency.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RightsHolderFrequency {

@JsonKey(name: 'is_primary') bool get isPrimary; int get mhz; Polarization get pol; int get sr;
/// Create a copy of RightsHolderFrequency
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RightsHolderFrequencyCopyWith<RightsHolderFrequency> get copyWith => _$RightsHolderFrequencyCopyWithImpl<RightsHolderFrequency>(this as RightsHolderFrequency, _$identity);

  /// Serializes this RightsHolderFrequency to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RightsHolderFrequency;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RightsHolderFrequency&&(identical(other.isPrimary, _this.isPrimary) || other.isPrimary == _this.isPrimary)&&(identical(other.mhz, _this.mhz) || other.mhz == _this.mhz)&&(identical(other.pol, _this.pol) || other.pol == _this.pol)&&(identical(other.sr, _this.sr) || other.sr == _this.sr));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RightsHolderFrequency;
  return Object.hash(runtimeType,_this.isPrimary,_this.mhz,_this.pol,_this.sr);
}

@override
String toString() {
  final _this = this as RightsHolderFrequency;
  return 'RightsHolderFrequency(isPrimary: ${_this.isPrimary}, mhz: ${_this.mhz}, pol: ${_this.pol}, sr: ${_this.sr})';
}


}

/// @nodoc
abstract mixin class $RightsHolderFrequencyCopyWith<$Res>  {
  factory $RightsHolderFrequencyCopyWith(RightsHolderFrequency value, $Res Function(RightsHolderFrequency) _then) = _$RightsHolderFrequencyCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'is_primary') bool isPrimary, int mhz, Polarization pol, int sr
});




}
/// @nodoc
class _$RightsHolderFrequencyCopyWithImpl<$Res>
    implements $RightsHolderFrequencyCopyWith<$Res> {
  _$RightsHolderFrequencyCopyWithImpl(this._self, this._then);

  final RightsHolderFrequency _self;
  final $Res Function(RightsHolderFrequency) _then;

/// Create a copy of RightsHolderFrequency
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isPrimary = null,Object? mhz = null,Object? pol = null,Object? sr = null,}) {
  return _then(RightsHolderFrequency(
isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,mhz: null == mhz ? _self.mhz : mhz // ignore: cast_nullable_to_non_nullable
as int,pol: null == pol ? _self.pol : pol // ignore: cast_nullable_to_non_nullable
as Polarization,sr: null == sr ? _self.sr : sr // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RightsHolderFrequency].
extension RightsHolderFrequencyPatterns on RightsHolderFrequency {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RightsHolderFrequency value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RightsHolderFrequency() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RightsHolderFrequency value)  $default,){
final _that = this;
switch (_that) {
case _RightsHolderFrequency():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RightsHolderFrequency value)?  $default,){
final _that = this;
switch (_that) {
case _RightsHolderFrequency() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_primary')  bool isPrimary,  int mhz,  Polarization pol,  int sr)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RightsHolderFrequency() when $default != null:
return $default(_that.isPrimary,_that.mhz,_that.pol,_that.sr);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_primary')  bool isPrimary,  int mhz,  Polarization pol,  int sr)  $default,) {final _that = this;
switch (_that) {
case _RightsHolderFrequency():
return $default(_that.isPrimary,_that.mhz,_that.pol,_that.sr);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'is_primary')  bool isPrimary,  int mhz,  Polarization pol,  int sr)?  $default,) {final _that = this;
switch (_that) {
case _RightsHolderFrequency() when $default != null:
return $default(_that.isPrimary,_that.mhz,_that.pol,_that.sr);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RightsHolderFrequency implements RightsHolderFrequency {
  const _RightsHolderFrequency({@JsonKey(name: 'is_primary') required this.isPrimary, required this.mhz, required this.pol, required this.sr});
  factory _RightsHolderFrequency.fromJson(Map<String, dynamic> json) => _$RightsHolderFrequencyFromJson(json);

@override@JsonKey(name: 'is_primary') final  bool isPrimary;
@override final  int mhz;
@override final  Polarization pol;
@override final  int sr;

/// Create a copy of RightsHolderFrequency
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RightsHolderFrequencyCopyWith<_RightsHolderFrequency> get copyWith => __$RightsHolderFrequencyCopyWithImpl<_RightsHolderFrequency>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RightsHolderFrequencyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RightsHolderFrequency&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.mhz, mhz) || other.mhz == mhz)&&(identical(other.pol, pol) || other.pol == pol)&&(identical(other.sr, sr) || other.sr == sr));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isPrimary,mhz,pol,sr);
}

@override
String toString() {
    return 'RightsHolderFrequency(isPrimary: $isPrimary, mhz: $mhz, pol: $pol, sr: $sr)';
}


}

/// @nodoc
abstract mixin class _$RightsHolderFrequencyCopyWith<$Res> implements $RightsHolderFrequencyCopyWith<$Res> {
  factory _$RightsHolderFrequencyCopyWith(_RightsHolderFrequency value, $Res Function(_RightsHolderFrequency) _then) = __$RightsHolderFrequencyCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'is_primary') bool isPrimary, int mhz, Polarization pol, int sr
});




}
/// @nodoc
class __$RightsHolderFrequencyCopyWithImpl<$Res>
    implements _$RightsHolderFrequencyCopyWith<$Res> {
  __$RightsHolderFrequencyCopyWithImpl(this._self, this._then);

  final _RightsHolderFrequency _self;
  final $Res Function(_RightsHolderFrequency) _then;

/// Create a copy of RightsHolderFrequency
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isPrimary = null,Object? mhz = null,Object? pol = null,Object? sr = null,}) {
  return _then(_RightsHolderFrequency(
isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,mhz: null == mhz ? _self.mhz : mhz // ignore: cast_nullable_to_non_nullable
as int,pol: null == pol ? _self.pol : pol // ignore: cast_nullable_to_non_nullable
as Polarization,sr: null == sr ? _self.sr : sr // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
