// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frequency.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Frequency {

 int get mhz; Polarization get pol; int get sr;
/// Create a copy of Frequency
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrequencyCopyWith<Frequency> get copyWith => _$FrequencyCopyWithImpl<Frequency>(this as Frequency, _$identity);

  /// Serializes this Frequency to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Frequency;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Frequency&&(identical(other.mhz, _this.mhz) || other.mhz == _this.mhz)&&(identical(other.pol, _this.pol) || other.pol == _this.pol)&&(identical(other.sr, _this.sr) || other.sr == _this.sr));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Frequency;
  return Object.hash(runtimeType,_this.mhz,_this.pol,_this.sr);
}

@override
String toString() {
  final _this = this as Frequency;
  return 'Frequency(mhz: ${_this.mhz}, pol: ${_this.pol}, sr: ${_this.sr})';
}


}

/// @nodoc
abstract mixin class $FrequencyCopyWith<$Res>  {
  factory $FrequencyCopyWith(Frequency value, $Res Function(Frequency) _then) = _$FrequencyCopyWithImpl;
@useResult
$Res call({
 int mhz, Polarization pol, int sr
});




}
/// @nodoc
class _$FrequencyCopyWithImpl<$Res>
    implements $FrequencyCopyWith<$Res> {
  _$FrequencyCopyWithImpl(this._self, this._then);

  final Frequency _self;
  final $Res Function(Frequency) _then;

/// Create a copy of Frequency
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mhz = null,Object? pol = null,Object? sr = null,}) {
  return _then(Frequency(
mhz: null == mhz ? _self.mhz : mhz // ignore: cast_nullable_to_non_nullable
as int,pol: null == pol ? _self.pol : pol // ignore: cast_nullable_to_non_nullable
as Polarization,sr: null == sr ? _self.sr : sr // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Frequency].
extension FrequencyPatterns on Frequency {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Frequency value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Frequency() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Frequency value)  $default,){
final _that = this;
switch (_that) {
case _Frequency():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Frequency value)?  $default,){
final _that = this;
switch (_that) {
case _Frequency() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int mhz,  Polarization pol,  int sr)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Frequency() when $default != null:
return $default(_that.mhz,_that.pol,_that.sr);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int mhz,  Polarization pol,  int sr)  $default,) {final _that = this;
switch (_that) {
case _Frequency():
return $default(_that.mhz,_that.pol,_that.sr);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int mhz,  Polarization pol,  int sr)?  $default,) {final _that = this;
switch (_that) {
case _Frequency() when $default != null:
return $default(_that.mhz,_that.pol,_that.sr);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Frequency implements Frequency {
  const _Frequency({required this.mhz, required this.pol, required this.sr});
  factory _Frequency.fromJson(Map<String, dynamic> json) => _$FrequencyFromJson(json);

@override final  int mhz;
@override final  Polarization pol;
@override final  int sr;

/// Create a copy of Frequency
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrequencyCopyWith<_Frequency> get copyWith => __$FrequencyCopyWithImpl<_Frequency>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FrequencyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Frequency&&(identical(other.mhz, mhz) || other.mhz == mhz)&&(identical(other.pol, pol) || other.pol == pol)&&(identical(other.sr, sr) || other.sr == sr));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mhz,pol,sr);
}

@override
String toString() {
    return 'Frequency(mhz: $mhz, pol: $pol, sr: $sr)';
}


}

/// @nodoc
abstract mixin class _$FrequencyCopyWith<$Res> implements $FrequencyCopyWith<$Res> {
  factory _$FrequencyCopyWith(_Frequency value, $Res Function(_Frequency) _then) = __$FrequencyCopyWithImpl;
@override @useResult
$Res call({
 int mhz, Polarization pol, int sr
});




}
/// @nodoc
class __$FrequencyCopyWithImpl<$Res>
    implements _$FrequencyCopyWith<$Res> {
  __$FrequencyCopyWithImpl(this._self, this._then);

  final _Frequency _self;
  final $Res Function(_Frequency) _then;

/// Create a copy of Frequency
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mhz = null,Object? pol = null,Object? sr = null,}) {
  return _then(_Frequency(
mhz: null == mhz ? _self.mhz : mhz // ignore: cast_nullable_to_non_nullable
as int,pol: null == pol ? _self.pol : pol // ignore: cast_nullable_to_non_nullable
as Polarization,sr: null == sr ? _self.sr : sr // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
