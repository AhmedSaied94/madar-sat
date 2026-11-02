// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Device {

@JsonKey(name: 'app_version') String? get appVersion;@JsonKey(name: 'device_id') int get deviceId;@JsonKey(name: 'has_push_token') bool get hasPushToken; String? get locale; DevicePlatform get platform; NotificationPrefs get prefs;@JsonKey(name: 'satellite_ids') List<int> get satelliteIds; String? get tz;
/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceCopyWith<Device> get copyWith => _$DeviceCopyWithImpl<Device>(this as Device, _$identity);

  /// Serializes this Device to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Device;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Device&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.hasPushToken, _this.hasPushToken) || other.hasPushToken == _this.hasPushToken)&&(identical(other.locale, _this.locale) || other.locale == _this.locale)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.prefs, _this.prefs) || other.prefs == _this.prefs)&&const DeepCollectionEquality().equals(other.satelliteIds, _this.satelliteIds)&&(identical(other.tz, _this.tz) || other.tz == _this.tz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Device;
  return Object.hash(runtimeType,_this.appVersion,_this.deviceId,_this.hasPushToken,_this.locale,_this.platform,_this.prefs,const DeepCollectionEquality().hash(_this.satelliteIds),_this.tz);
}

@override
String toString() {
  final _this = this as Device;
  return 'Device(appVersion: ${_this.appVersion}, deviceId: ${_this.deviceId}, hasPushToken: ${_this.hasPushToken}, locale: ${_this.locale}, platform: ${_this.platform}, prefs: ${_this.prefs}, satelliteIds: ${_this.satelliteIds}, tz: ${_this.tz})';
}


}

/// @nodoc
abstract mixin class $DeviceCopyWith<$Res>  {
  factory $DeviceCopyWith(Device value, $Res Function(Device) _then) = _$DeviceCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'app_version') String? appVersion,@JsonKey(name: 'device_id') int deviceId,@JsonKey(name: 'has_push_token') bool hasPushToken, String? locale, DevicePlatform platform, NotificationPrefs prefs,@JsonKey(name: 'satellite_ids') List<int> satelliteIds, String? tz
});


$NotificationPrefsCopyWith<$Res> get prefs;

}
/// @nodoc
class _$DeviceCopyWithImpl<$Res>
    implements $DeviceCopyWith<$Res> {
  _$DeviceCopyWithImpl(this._self, this._then);

  final Device _self;
  final $Res Function(Device) _then;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? appVersion = freezed,Object? deviceId = null,Object? hasPushToken = null,Object? locale = freezed,Object? platform = null,Object? prefs = null,Object? satelliteIds = null,Object? tz = freezed,}) {
  return _then(Device(
appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as int,hasPushToken: null == hasPushToken ? _self.hasPushToken : hasPushToken // ignore: cast_nullable_to_non_nullable
as bool,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,prefs: null == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as NotificationPrefs,satelliteIds: null == satelliteIds ? _self.satelliteIds : satelliteIds // ignore: cast_nullable_to_non_nullable
as List<int>,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<$Res> get prefs {
  
  return $NotificationPrefsCopyWith<$Res>(_self.prefs, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}
}


/// Adds pattern-matching-related methods to [Device].
extension DevicePatterns on Device {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Device value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Device() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Device value)  $default,){
final _that = this;
switch (_that) {
case _Device():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Device value)?  $default,){
final _that = this;
switch (_that) {
case _Device() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'app_version')  String? appVersion, @JsonKey(name: 'device_id')  int deviceId, @JsonKey(name: 'has_push_token')  bool hasPushToken,  String? locale,  DevicePlatform platform,  NotificationPrefs prefs, @JsonKey(name: 'satellite_ids')  List<int> satelliteIds,  String? tz)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that.appVersion,_that.deviceId,_that.hasPushToken,_that.locale,_that.platform,_that.prefs,_that.satelliteIds,_that.tz);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'app_version')  String? appVersion, @JsonKey(name: 'device_id')  int deviceId, @JsonKey(name: 'has_push_token')  bool hasPushToken,  String? locale,  DevicePlatform platform,  NotificationPrefs prefs, @JsonKey(name: 'satellite_ids')  List<int> satelliteIds,  String? tz)  $default,) {final _that = this;
switch (_that) {
case _Device():
return $default(_that.appVersion,_that.deviceId,_that.hasPushToken,_that.locale,_that.platform,_that.prefs,_that.satelliteIds,_that.tz);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'app_version')  String? appVersion, @JsonKey(name: 'device_id')  int deviceId, @JsonKey(name: 'has_push_token')  bool hasPushToken,  String? locale,  DevicePlatform platform,  NotificationPrefs prefs, @JsonKey(name: 'satellite_ids')  List<int> satelliteIds,  String? tz)?  $default,) {final _that = this;
switch (_that) {
case _Device() when $default != null:
return $default(_that.appVersion,_that.deviceId,_that.hasPushToken,_that.locale,_that.platform,_that.prefs,_that.satelliteIds,_that.tz);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Device implements Device {
  const _Device({@JsonKey(name: 'app_version') required this.appVersion, @JsonKey(name: 'device_id') required this.deviceId, @JsonKey(name: 'has_push_token') required this.hasPushToken, required this.locale, required this.platform, required this.prefs, @JsonKey(name: 'satellite_ids') required  List<int> satelliteIds, required this.tz}): _satelliteIds = satelliteIds;
  factory _Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

@override@JsonKey(name: 'app_version') final  String? appVersion;
@override@JsonKey(name: 'device_id') final  int deviceId;
@override@JsonKey(name: 'has_push_token') final  bool hasPushToken;
@override final  String? locale;
@override final  DevicePlatform platform;
@override final  NotificationPrefs prefs;
 final  List<int> _satelliteIds;
@override@JsonKey(name: 'satellite_ids') List<int> get satelliteIds {
  if (_satelliteIds is EqualUnmodifiableListView) return _satelliteIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_satelliteIds);
}

@override final  String? tz;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceCopyWith<_Device> get copyWith => __$DeviceCopyWithImpl<_Device>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Device&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.hasPushToken, hasPushToken) || other.hasPushToken == hasPushToken)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.prefs, prefs) || other.prefs == prefs)&&const DeepCollectionEquality().equals(other.satelliteIds, _satelliteIds)&&(identical(other.tz, tz) || other.tz == tz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,appVersion,deviceId,hasPushToken,locale,platform,prefs,const DeepCollectionEquality().hash(_satelliteIds),tz);
}

@override
String toString() {
    return 'Device(appVersion: $appVersion, deviceId: $deviceId, hasPushToken: $hasPushToken, locale: $locale, platform: $platform, prefs: $prefs, satelliteIds: $satelliteIds, tz: $tz)';
}


}

/// @nodoc
abstract mixin class _$DeviceCopyWith<$Res> implements $DeviceCopyWith<$Res> {
  factory _$DeviceCopyWith(_Device value, $Res Function(_Device) _then) = __$DeviceCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'app_version') String? appVersion,@JsonKey(name: 'device_id') int deviceId,@JsonKey(name: 'has_push_token') bool hasPushToken, String? locale, DevicePlatform platform, NotificationPrefs prefs,@JsonKey(name: 'satellite_ids') List<int> satelliteIds, String? tz
});


@override $NotificationPrefsCopyWith<$Res> get prefs;

}
/// @nodoc
class __$DeviceCopyWithImpl<$Res>
    implements _$DeviceCopyWith<$Res> {
  __$DeviceCopyWithImpl(this._self, this._then);

  final _Device _self;
  final $Res Function(_Device) _then;

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? appVersion = freezed,Object? deviceId = null,Object? hasPushToken = null,Object? locale = freezed,Object? platform = null,Object? prefs = null,Object? satelliteIds = null,Object? tz = freezed,}) {
  return _then(_Device(
appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as int,hasPushToken: null == hasPushToken ? _self.hasPushToken : hasPushToken // ignore: cast_nullable_to_non_nullable
as bool,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as DevicePlatform,prefs: null == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as NotificationPrefs,satelliteIds: null == satelliteIds ? _self._satelliteIds : satelliteIds // ignore: cast_nullable_to_non_nullable
as List<int>,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Device
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<$Res> get prefs {
  
  return $NotificationPrefsCopyWith<$Res>(_self.prefs, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}
}

// dart format on
