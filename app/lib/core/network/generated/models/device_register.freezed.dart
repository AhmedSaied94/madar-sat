// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_register.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRegister {

@JsonKey(name: 'install_id') String get installId; DeviceRegisterPlatform get platform;
/// Create a copy of DeviceRegister
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRegisterCopyWith<DeviceRegister> get copyWith => _$DeviceRegisterCopyWithImpl<DeviceRegister>(this as DeviceRegister, _$identity);

  /// Serializes this DeviceRegister to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRegister;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRegister&&(identical(other.installId, _this.installId) || other.installId == _this.installId)&&(identical(other.platform, _this.platform) || other.platform == _this.platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRegister;
  return Object.hash(runtimeType,_this.installId,_this.platform);
}

@override
String toString() {
  final _this = this as DeviceRegister;
  return 'DeviceRegister(installId: ${_this.installId}, platform: ${_this.platform})';
}


}

/// @nodoc
abstract mixin class $DeviceRegisterCopyWith<$Res>  {
  factory $DeviceRegisterCopyWith(DeviceRegister value, $Res Function(DeviceRegister) _then) = _$DeviceRegisterCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'install_id') String installId, DeviceRegisterPlatform platform
});




}
/// @nodoc
class _$DeviceRegisterCopyWithImpl<$Res>
    implements $DeviceRegisterCopyWith<$Res> {
  _$DeviceRegisterCopyWithImpl(this._self, this._then);

  final DeviceRegister _self;
  final $Res Function(DeviceRegister) _then;

/// Create a copy of DeviceRegister
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? installId = null,Object? platform = null,}) {
  return _then(DeviceRegister(
installId: null == installId ? _self.installId : installId // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DeviceRegisterPlatform,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRegister].
extension DeviceRegisterPatterns on DeviceRegister {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRegister value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRegister() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRegister value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRegister():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRegister value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRegister() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'install_id')  String installId,  DeviceRegisterPlatform platform)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRegister() when $default != null:
return $default(_that.installId,_that.platform);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'install_id')  String installId,  DeviceRegisterPlatform platform)  $default,) {final _that = this;
switch (_that) {
case _DeviceRegister():
return $default(_that.installId,_that.platform);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'install_id')  String installId,  DeviceRegisterPlatform platform)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRegister() when $default != null:
return $default(_that.installId,_that.platform);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRegister implements DeviceRegister {
  const _DeviceRegister({@JsonKey(name: 'install_id') required this.installId, required this.platform});
  factory _DeviceRegister.fromJson(Map<String, dynamic> json) => _$DeviceRegisterFromJson(json);

@override@JsonKey(name: 'install_id') final  String installId;
@override final  DeviceRegisterPlatform platform;

/// Create a copy of DeviceRegister
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRegisterCopyWith<_DeviceRegister> get copyWith => __$DeviceRegisterCopyWithImpl<_DeviceRegister>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRegisterToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRegister&&(identical(other.installId, installId) || other.installId == installId)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,installId,platform);
}

@override
String toString() {
    return 'DeviceRegister(installId: $installId, platform: $platform)';
}


}

/// @nodoc
abstract mixin class _$DeviceRegisterCopyWith<$Res> implements $DeviceRegisterCopyWith<$Res> {
  factory _$DeviceRegisterCopyWith(_DeviceRegister value, $Res Function(_DeviceRegister) _then) = __$DeviceRegisterCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'install_id') String installId, DeviceRegisterPlatform platform
});




}
/// @nodoc
class __$DeviceRegisterCopyWithImpl<$Res>
    implements _$DeviceRegisterCopyWith<$Res> {
  __$DeviceRegisterCopyWithImpl(this._self, this._then);

  final _DeviceRegister _self;
  final $Res Function(_DeviceRegister) _then;

/// Create a copy of DeviceRegister
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? installId = null,Object? platform = null,}) {
  return _then(_DeviceRegister(
installId: null == installId ? _self.installId : installId // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DeviceRegisterPlatform,
  ));
}


}

// dart format on
