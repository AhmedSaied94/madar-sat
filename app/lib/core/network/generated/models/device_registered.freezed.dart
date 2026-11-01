// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_registered.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRegistered {

@JsonKey(name: 'device_id') int get deviceId;@JsonKey(name: 'device_token') String get deviceToken;
/// Create a copy of DeviceRegistered
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRegisteredCopyWith<DeviceRegistered> get copyWith => _$DeviceRegisteredCopyWithImpl<DeviceRegistered>(this as DeviceRegistered, _$identity);

  /// Serializes this DeviceRegistered to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRegistered;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRegistered&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.deviceToken, _this.deviceToken) || other.deviceToken == _this.deviceToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRegistered;
  return Object.hash(runtimeType,_this.deviceId,_this.deviceToken);
}

@override
String toString() {
  final _this = this as DeviceRegistered;
  return 'DeviceRegistered(deviceId: ${_this.deviceId}, deviceToken: ${_this.deviceToken})';
}


}

/// @nodoc
abstract mixin class $DeviceRegisteredCopyWith<$Res>  {
  factory $DeviceRegisteredCopyWith(DeviceRegistered value, $Res Function(DeviceRegistered) _then) = _$DeviceRegisteredCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'device_id') int deviceId,@JsonKey(name: 'device_token') String deviceToken
});




}
/// @nodoc
class _$DeviceRegisteredCopyWithImpl<$Res>
    implements $DeviceRegisteredCopyWith<$Res> {
  _$DeviceRegisteredCopyWithImpl(this._self, this._then);

  final DeviceRegistered _self;
  final $Res Function(DeviceRegistered) _then;

/// Create a copy of DeviceRegistered
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = null,Object? deviceToken = null,}) {
  return _then(DeviceRegistered(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as int,deviceToken: null == deviceToken ? _self.deviceToken : deviceToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRegistered].
extension DeviceRegisteredPatterns on DeviceRegistered {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRegistered value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRegistered() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRegistered value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRegistered():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRegistered value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRegistered() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'device_id')  int deviceId, @JsonKey(name: 'device_token')  String deviceToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRegistered() when $default != null:
return $default(_that.deviceId,_that.deviceToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'device_id')  int deviceId, @JsonKey(name: 'device_token')  String deviceToken)  $default,) {final _that = this;
switch (_that) {
case _DeviceRegistered():
return $default(_that.deviceId,_that.deviceToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'device_id')  int deviceId, @JsonKey(name: 'device_token')  String deviceToken)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRegistered() when $default != null:
return $default(_that.deviceId,_that.deviceToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRegistered implements DeviceRegistered {
  const _DeviceRegistered({@JsonKey(name: 'device_id') required this.deviceId, @JsonKey(name: 'device_token') required this.deviceToken});
  factory _DeviceRegistered.fromJson(Map<String, dynamic> json) => _$DeviceRegisteredFromJson(json);

@override@JsonKey(name: 'device_id') final  int deviceId;
@override@JsonKey(name: 'device_token') final  String deviceToken;

/// Create a copy of DeviceRegistered
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRegisteredCopyWith<_DeviceRegistered> get copyWith => __$DeviceRegisteredCopyWithImpl<_DeviceRegistered>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRegisteredToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRegistered&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.deviceToken, deviceToken) || other.deviceToken == deviceToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,deviceId,deviceToken);
}

@override
String toString() {
    return 'DeviceRegistered(deviceId: $deviceId, deviceToken: $deviceToken)';
}


}

/// @nodoc
abstract mixin class _$DeviceRegisteredCopyWith<$Res> implements $DeviceRegisteredCopyWith<$Res> {
  factory _$DeviceRegisteredCopyWith(_DeviceRegistered value, $Res Function(_DeviceRegistered) _then) = __$DeviceRegisteredCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'device_id') int deviceId,@JsonKey(name: 'device_token') String deviceToken
});




}
/// @nodoc
class __$DeviceRegisteredCopyWithImpl<$Res>
    implements _$DeviceRegisteredCopyWith<$Res> {
  __$DeviceRegisteredCopyWithImpl(this._self, this._then);

  final _DeviceRegistered _self;
  final $Res Function(_DeviceRegistered) _then;

/// Create a copy of DeviceRegistered
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = null,Object? deviceToken = null,}) {
  return _then(_DeviceRegistered(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as int,deviceToken: null == deviceToken ? _self.deviceToken : deviceToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
