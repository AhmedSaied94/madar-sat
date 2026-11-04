// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frequency_change.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FrequencyChange {

@JsonKey(name: 'detected_at') DateTime get detectedAt;/// The name has been replaced because it contains a keyword. Original name: `new`.
@JsonKey(name: 'new') FrequencyChangeTuning get newValue; FrequencyChangeTuning get old;
/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrequencyChangeCopyWith<FrequencyChange> get copyWith => _$FrequencyChangeCopyWithImpl<FrequencyChange>(this as FrequencyChange, _$identity);

  /// Serializes this FrequencyChange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FrequencyChange;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrequencyChange&&(identical(other.detectedAt, _this.detectedAt) || other.detectedAt == _this.detectedAt)&&(identical(other.newValue, _this.newValue) || other.newValue == _this.newValue)&&(identical(other.old, _this.old) || other.old == _this.old));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FrequencyChange;
  return Object.hash(runtimeType,_this.detectedAt,_this.newValue,_this.old);
}

@override
String toString() {
  final _this = this as FrequencyChange;
  return 'FrequencyChange(detectedAt: ${_this.detectedAt}, newValue: ${_this.newValue}, old: ${_this.old})';
}


}

/// @nodoc
abstract mixin class $FrequencyChangeCopyWith<$Res>  {
  factory $FrequencyChangeCopyWith(FrequencyChange value, $Res Function(FrequencyChange) _then) = _$FrequencyChangeCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'detected_at') DateTime detectedAt,@JsonKey(name: 'new') FrequencyChangeTuning newValue, FrequencyChangeTuning old
});


$FrequencyChangeTuningCopyWith<$Res> get newValue;$FrequencyChangeTuningCopyWith<$Res> get old;

}
/// @nodoc
class _$FrequencyChangeCopyWithImpl<$Res>
    implements $FrequencyChangeCopyWith<$Res> {
  _$FrequencyChangeCopyWithImpl(this._self, this._then);

  final FrequencyChange _self;
  final $Res Function(FrequencyChange) _then;

/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? detectedAt = null,Object? newValue = null,Object? old = null,}) {
  return _then(FrequencyChange(
detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,newValue: null == newValue ? _self.newValue : newValue // ignore: cast_nullable_to_non_nullable
as FrequencyChangeTuning,old: null == old ? _self.old : old // ignore: cast_nullable_to_non_nullable
as FrequencyChangeTuning,
  ));
}
/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyChangeTuningCopyWith<$Res> get newValue {
  
  return $FrequencyChangeTuningCopyWith<$Res>(_self.newValue, (value) {
    return _then(_self.copyWith(newValue: value));
  });
}/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyChangeTuningCopyWith<$Res> get old {
  
  return $FrequencyChangeTuningCopyWith<$Res>(_self.old, (value) {
    return _then(_self.copyWith(old: value));
  });
}
}


/// Adds pattern-matching-related methods to [FrequencyChange].
extension FrequencyChangePatterns on FrequencyChange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrequencyChange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrequencyChange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrequencyChange value)  $default,){
final _that = this;
switch (_that) {
case _FrequencyChange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrequencyChange value)?  $default,){
final _that = this;
switch (_that) {
case _FrequencyChange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'detected_at')  DateTime detectedAt, @JsonKey(name: 'new')  FrequencyChangeTuning newValue,  FrequencyChangeTuning old)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrequencyChange() when $default != null:
return $default(_that.detectedAt,_that.newValue,_that.old);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'detected_at')  DateTime detectedAt, @JsonKey(name: 'new')  FrequencyChangeTuning newValue,  FrequencyChangeTuning old)  $default,) {final _that = this;
switch (_that) {
case _FrequencyChange():
return $default(_that.detectedAt,_that.newValue,_that.old);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'detected_at')  DateTime detectedAt, @JsonKey(name: 'new')  FrequencyChangeTuning newValue,  FrequencyChangeTuning old)?  $default,) {final _that = this;
switch (_that) {
case _FrequencyChange() when $default != null:
return $default(_that.detectedAt,_that.newValue,_that.old);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FrequencyChange implements FrequencyChange {
  const _FrequencyChange({@JsonKey(name: 'detected_at') required this.detectedAt, @JsonKey(name: 'new') required this.newValue, required this.old});
  factory _FrequencyChange.fromJson(Map<String, dynamic> json) => _$FrequencyChangeFromJson(json);

@override@JsonKey(name: 'detected_at') final  DateTime detectedAt;
/// The name has been replaced because it contains a keyword. Original name: `new`.
@override@JsonKey(name: 'new') final  FrequencyChangeTuning newValue;
@override final  FrequencyChangeTuning old;

/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrequencyChangeCopyWith<_FrequencyChange> get copyWith => __$FrequencyChangeCopyWithImpl<_FrequencyChange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FrequencyChangeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrequencyChange&&(identical(other.detectedAt, detectedAt) || other.detectedAt == detectedAt)&&(identical(other.newValue, newValue) || other.newValue == newValue)&&(identical(other.old, old) || other.old == old));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,detectedAt,newValue,old);
}

@override
String toString() {
    return 'FrequencyChange(detectedAt: $detectedAt, newValue: $newValue, old: $old)';
}


}

/// @nodoc
abstract mixin class _$FrequencyChangeCopyWith<$Res> implements $FrequencyChangeCopyWith<$Res> {
  factory _$FrequencyChangeCopyWith(_FrequencyChange value, $Res Function(_FrequencyChange) _then) = __$FrequencyChangeCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'detected_at') DateTime detectedAt,@JsonKey(name: 'new') FrequencyChangeTuning newValue, FrequencyChangeTuning old
});


@override $FrequencyChangeTuningCopyWith<$Res> get newValue;@override $FrequencyChangeTuningCopyWith<$Res> get old;

}
/// @nodoc
class __$FrequencyChangeCopyWithImpl<$Res>
    implements _$FrequencyChangeCopyWith<$Res> {
  __$FrequencyChangeCopyWithImpl(this._self, this._then);

  final _FrequencyChange _self;
  final $Res Function(_FrequencyChange) _then;

/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? detectedAt = null,Object? newValue = null,Object? old = null,}) {
  return _then(_FrequencyChange(
detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,newValue: null == newValue ? _self.newValue : newValue // ignore: cast_nullable_to_non_nullable
as FrequencyChangeTuning,old: null == old ? _self.old : old // ignore: cast_nullable_to_non_nullable
as FrequencyChangeTuning,
  ));
}

/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyChangeTuningCopyWith<$Res> get newValue {
  
  return $FrequencyChangeTuningCopyWith<$Res>(_self.newValue, (value) {
    return _then(_self.copyWith(newValue: value));
  });
}/// Create a copy of FrequencyChange
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyChangeTuningCopyWith<$Res> get old {
  
  return $FrequencyChangeTuningCopyWith<$Res>(_self.old, (value) {
    return _then(_self.copyWith(old: value));
  });
}
}

// dart format on
