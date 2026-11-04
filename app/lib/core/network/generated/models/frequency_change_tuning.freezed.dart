// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frequency_change_tuning.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FrequencyChangeTuning {

@JsonKey(name: 'frequency_mhz') int get frequencyMhz; Polarization get polarization;@JsonKey(name: 'symbol_rate') int get symbolRate;
/// Create a copy of FrequencyChangeTuning
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrequencyChangeTuningCopyWith<FrequencyChangeTuning> get copyWith => _$FrequencyChangeTuningCopyWithImpl<FrequencyChangeTuning>(this as FrequencyChangeTuning, _$identity);

  /// Serializes this FrequencyChangeTuning to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FrequencyChangeTuning;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrequencyChangeTuning&&(identical(other.frequencyMhz, _this.frequencyMhz) || other.frequencyMhz == _this.frequencyMhz)&&(identical(other.polarization, _this.polarization) || other.polarization == _this.polarization)&&(identical(other.symbolRate, _this.symbolRate) || other.symbolRate == _this.symbolRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FrequencyChangeTuning;
  return Object.hash(runtimeType,_this.frequencyMhz,_this.polarization,_this.symbolRate);
}

@override
String toString() {
  final _this = this as FrequencyChangeTuning;
  return 'FrequencyChangeTuning(frequencyMhz: ${_this.frequencyMhz}, polarization: ${_this.polarization}, symbolRate: ${_this.symbolRate})';
}


}

/// @nodoc
abstract mixin class $FrequencyChangeTuningCopyWith<$Res>  {
  factory $FrequencyChangeTuningCopyWith(FrequencyChangeTuning value, $Res Function(FrequencyChangeTuning) _then) = _$FrequencyChangeTuningCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'frequency_mhz') int frequencyMhz, Polarization polarization,@JsonKey(name: 'symbol_rate') int symbolRate
});




}
/// @nodoc
class _$FrequencyChangeTuningCopyWithImpl<$Res>
    implements $FrequencyChangeTuningCopyWith<$Res> {
  _$FrequencyChangeTuningCopyWithImpl(this._self, this._then);

  final FrequencyChangeTuning _self;
  final $Res Function(FrequencyChangeTuning) _then;

/// Create a copy of FrequencyChangeTuning
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? frequencyMhz = null,Object? polarization = null,Object? symbolRate = null,}) {
  return _then(FrequencyChangeTuning(
frequencyMhz: null == frequencyMhz ? _self.frequencyMhz : frequencyMhz // ignore: cast_nullable_to_non_nullable
as int,polarization: null == polarization ? _self.polarization : polarization // ignore: cast_nullable_to_non_nullable
as Polarization,symbolRate: null == symbolRate ? _self.symbolRate : symbolRate // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FrequencyChangeTuning].
extension FrequencyChangeTuningPatterns on FrequencyChangeTuning {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrequencyChangeTuning value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrequencyChangeTuning() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrequencyChangeTuning value)  $default,){
final _that = this;
switch (_that) {
case _FrequencyChangeTuning():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrequencyChangeTuning value)?  $default,){
final _that = this;
switch (_that) {
case _FrequencyChangeTuning() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'frequency_mhz')  int frequencyMhz,  Polarization polarization, @JsonKey(name: 'symbol_rate')  int symbolRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrequencyChangeTuning() when $default != null:
return $default(_that.frequencyMhz,_that.polarization,_that.symbolRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'frequency_mhz')  int frequencyMhz,  Polarization polarization, @JsonKey(name: 'symbol_rate')  int symbolRate)  $default,) {final _that = this;
switch (_that) {
case _FrequencyChangeTuning():
return $default(_that.frequencyMhz,_that.polarization,_that.symbolRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'frequency_mhz')  int frequencyMhz,  Polarization polarization, @JsonKey(name: 'symbol_rate')  int symbolRate)?  $default,) {final _that = this;
switch (_that) {
case _FrequencyChangeTuning() when $default != null:
return $default(_that.frequencyMhz,_that.polarization,_that.symbolRate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FrequencyChangeTuning implements FrequencyChangeTuning {
  const _FrequencyChangeTuning({@JsonKey(name: 'frequency_mhz') required this.frequencyMhz, required this.polarization, @JsonKey(name: 'symbol_rate') required this.symbolRate});
  factory _FrequencyChangeTuning.fromJson(Map<String, dynamic> json) => _$FrequencyChangeTuningFromJson(json);

@override@JsonKey(name: 'frequency_mhz') final  int frequencyMhz;
@override final  Polarization polarization;
@override@JsonKey(name: 'symbol_rate') final  int symbolRate;

/// Create a copy of FrequencyChangeTuning
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrequencyChangeTuningCopyWith<_FrequencyChangeTuning> get copyWith => __$FrequencyChangeTuningCopyWithImpl<_FrequencyChangeTuning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FrequencyChangeTuningToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrequencyChangeTuning&&(identical(other.frequencyMhz, frequencyMhz) || other.frequencyMhz == frequencyMhz)&&(identical(other.polarization, polarization) || other.polarization == polarization)&&(identical(other.symbolRate, symbolRate) || other.symbolRate == symbolRate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,frequencyMhz,polarization,symbolRate);
}

@override
String toString() {
    return 'FrequencyChangeTuning(frequencyMhz: $frequencyMhz, polarization: $polarization, symbolRate: $symbolRate)';
}


}

/// @nodoc
abstract mixin class _$FrequencyChangeTuningCopyWith<$Res> implements $FrequencyChangeTuningCopyWith<$Res> {
  factory _$FrequencyChangeTuningCopyWith(_FrequencyChangeTuning value, $Res Function(_FrequencyChangeTuning) _then) = __$FrequencyChangeTuningCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'frequency_mhz') int frequencyMhz, Polarization polarization,@JsonKey(name: 'symbol_rate') int symbolRate
});




}
/// @nodoc
class __$FrequencyChangeTuningCopyWithImpl<$Res>
    implements _$FrequencyChangeTuningCopyWith<$Res> {
  __$FrequencyChangeTuningCopyWithImpl(this._self, this._then);

  final _FrequencyChangeTuning _self;
  final $Res Function(_FrequencyChangeTuning) _then;

/// Create a copy of FrequencyChangeTuning
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? frequencyMhz = null,Object? polarization = null,Object? symbolRate = null,}) {
  return _then(_FrequencyChangeTuning(
frequencyMhz: null == frequencyMhz ? _self.frequencyMhz : frequencyMhz // ignore: cast_nullable_to_non_nullable
as int,polarization: null == polarization ? _self.polarization : polarization // ignore: cast_nullable_to_non_nullable
as Polarization,symbolRate: null == symbolRate ? _self.symbolRate : symbolRate // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
