// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceUpdate {

@JsonKey(name: 'app_version') String? get appVersion; String? get locale; NotificationPrefs? get prefs;@JsonKey(name: 'push_token') String? get pushToken;@JsonKey(name: 'satellite_ids') List<int>? get satelliteIds; String? get tz;
/// Create a copy of DeviceUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceUpdateCopyWith<DeviceUpdate> get copyWith => _$DeviceUpdateCopyWithImpl<DeviceUpdate>(this as DeviceUpdate, _$identity);

  /// Serializes this DeviceUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceUpdate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceUpdate&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion)&&(identical(other.locale, _this.locale) || other.locale == _this.locale)&&(identical(other.prefs, _this.prefs) || other.prefs == _this.prefs)&&(identical(other.pushToken, _this.pushToken) || other.pushToken == _this.pushToken)&&const DeepCollectionEquality().equals(other.satelliteIds, _this.satelliteIds)&&(identical(other.tz, _this.tz) || other.tz == _this.tz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceUpdate;
  return Object.hash(runtimeType,_this.appVersion,_this.locale,_this.prefs,_this.pushToken,const DeepCollectionEquality().hash(_this.satelliteIds),_this.tz);
}

@override
String toString() {
  final _this = this as DeviceUpdate;
  return 'DeviceUpdate(appVersion: ${_this.appVersion}, locale: ${_this.locale}, prefs: ${_this.prefs}, pushToken: ${_this.pushToken}, satelliteIds: ${_this.satelliteIds}, tz: ${_this.tz})';
}


}

/// @nodoc
abstract mixin class $DeviceUpdateCopyWith<$Res>  {
  factory $DeviceUpdateCopyWith(DeviceUpdate value, $Res Function(DeviceUpdate) _then) = _$DeviceUpdateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'app_version') String? appVersion, String? locale, NotificationPrefs? prefs,@JsonKey(name: 'push_token') String? pushToken,@JsonKey(name: 'satellite_ids') List<int>? satelliteIds, String? tz
});


$NotificationPrefsCopyWith<$Res>? get prefs;

}
/// @nodoc
class _$DeviceUpdateCopyWithImpl<$Res>
    implements $DeviceUpdateCopyWith<$Res> {
  _$DeviceUpdateCopyWithImpl(this._self, this._then);

  final DeviceUpdate _self;
  final $Res Function(DeviceUpdate) _then;

/// Create a copy of DeviceUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? appVersion = freezed,Object? locale = freezed,Object? prefs = freezed,Object? pushToken = freezed,Object? satelliteIds = freezed,Object? tz = freezed,}) {
  return _then(DeviceUpdate(
appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as NotificationPrefs?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,satelliteIds: freezed == satelliteIds ? _self.satelliteIds : satelliteIds // ignore: cast_nullable_to_non_nullable
as List<int>?,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DeviceUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $NotificationPrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeviceUpdate].
extension DeviceUpdatePatterns on DeviceUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceUpdate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceUpdate value)  $default,){
final _that = this;
switch (_that) {
case _DeviceUpdate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceUpdate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'app_version')  String? appVersion,  String? locale,  NotificationPrefs? prefs, @JsonKey(name: 'push_token')  String? pushToken, @JsonKey(name: 'satellite_ids')  List<int>? satelliteIds,  String? tz)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceUpdate() when $default != null:
return $default(_that.appVersion,_that.locale,_that.prefs,_that.pushToken,_that.satelliteIds,_that.tz);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'app_version')  String? appVersion,  String? locale,  NotificationPrefs? prefs, @JsonKey(name: 'push_token')  String? pushToken, @JsonKey(name: 'satellite_ids')  List<int>? satelliteIds,  String? tz)  $default,) {final _that = this;
switch (_that) {
case _DeviceUpdate():
return $default(_that.appVersion,_that.locale,_that.prefs,_that.pushToken,_that.satelliteIds,_that.tz);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'app_version')  String? appVersion,  String? locale,  NotificationPrefs? prefs, @JsonKey(name: 'push_token')  String? pushToken, @JsonKey(name: 'satellite_ids')  List<int>? satelliteIds,  String? tz)?  $default,) {final _that = this;
switch (_that) {
case _DeviceUpdate() when $default != null:
return $default(_that.appVersion,_that.locale,_that.prefs,_that.pushToken,_that.satelliteIds,_that.tz);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceUpdate implements DeviceUpdate {
  const _DeviceUpdate({@JsonKey(name: 'app_version') this.appVersion, this.locale, this.prefs, @JsonKey(name: 'push_token') this.pushToken, @JsonKey(name: 'satellite_ids')  List<int>? satelliteIds, this.tz}): _satelliteIds = satelliteIds;
  factory _DeviceUpdate.fromJson(Map<String, dynamic> json) => _$DeviceUpdateFromJson(json);

@override@JsonKey(name: 'app_version') final  String? appVersion;
@override final  String? locale;
@override final  NotificationPrefs? prefs;
@override@JsonKey(name: 'push_token') final  String? pushToken;
 final  List<int>? _satelliteIds;
@override@JsonKey(name: 'satellite_ids') List<int>? get satelliteIds {
  final value = _satelliteIds;
  if (value == null) return null;
  if (_satelliteIds is EqualUnmodifiableListView) return _satelliteIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? tz;

/// Create a copy of DeviceUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceUpdateCopyWith<_DeviceUpdate> get copyWith => __$DeviceUpdateCopyWithImpl<_DeviceUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceUpdate&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.prefs, prefs) || other.prefs == prefs)&&(identical(other.pushToken, pushToken) || other.pushToken == pushToken)&&const DeepCollectionEquality().equals(other.satelliteIds, _satelliteIds)&&(identical(other.tz, tz) || other.tz == tz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,appVersion,locale,prefs,pushToken,const DeepCollectionEquality().hash(_satelliteIds),tz);
}

@override
String toString() {
    return 'DeviceUpdate(appVersion: $appVersion, locale: $locale, prefs: $prefs, pushToken: $pushToken, satelliteIds: $satelliteIds, tz: $tz)';
}


}

/// @nodoc
abstract mixin class _$DeviceUpdateCopyWith<$Res> implements $DeviceUpdateCopyWith<$Res> {
  factory _$DeviceUpdateCopyWith(_DeviceUpdate value, $Res Function(_DeviceUpdate) _then) = __$DeviceUpdateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'app_version') String? appVersion, String? locale, NotificationPrefs? prefs,@JsonKey(name: 'push_token') String? pushToken,@JsonKey(name: 'satellite_ids') List<int>? satelliteIds, String? tz
});


@override $NotificationPrefsCopyWith<$Res>? get prefs;

}
/// @nodoc
class __$DeviceUpdateCopyWithImpl<$Res>
    implements _$DeviceUpdateCopyWith<$Res> {
  __$DeviceUpdateCopyWithImpl(this._self, this._then);

  final _DeviceUpdate _self;
  final $Res Function(_DeviceUpdate) _then;

/// Create a copy of DeviceUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? appVersion = freezed,Object? locale = freezed,Object? prefs = freezed,Object? pushToken = freezed,Object? satelliteIds = freezed,Object? tz = freezed,}) {
  return _then(_DeviceUpdate(
appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,prefs: freezed == prefs ? _self.prefs : prefs // ignore: cast_nullable_to_non_nullable
as NotificationPrefs?,pushToken: freezed == pushToken ? _self.pushToken : pushToken // ignore: cast_nullable_to_non_nullable
as String?,satelliteIds: freezed == satelliteIds ? _self._satelliteIds : satelliteIds // ignore: cast_nullable_to_non_nullable
as List<int>?,tz: freezed == tz ? _self.tz : tz // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DeviceUpdate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<$Res>? get prefs {
    if (_self.prefs == null) {
    return null;
  }

  return $NotificationPrefsCopyWith<$Res>(_self.prefs!, (value) {
    return _then(_self.copyWith(prefs: value));
  });
}
}

// dart format on
