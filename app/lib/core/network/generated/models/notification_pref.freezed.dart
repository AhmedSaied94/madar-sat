// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_pref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationPref {

/// The name has been replaced because it contains a keyword. Original name: `on`.
@JsonKey(name: 'on') bool get onValue;@JsonKey(name: 'lead_min') NotificationPrefLeadMin? get leadMin;
/// Create a copy of NotificationPref
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPrefCopyWith<NotificationPref> get copyWith => _$NotificationPrefCopyWithImpl<NotificationPref>(this as NotificationPref, _$identity);

  /// Serializes this NotificationPref to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as NotificationPref;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPref&&(identical(other.onValue, _this.onValue) || other.onValue == _this.onValue)&&(identical(other.leadMin, _this.leadMin) || other.leadMin == _this.leadMin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as NotificationPref;
  return Object.hash(runtimeType,_this.onValue,_this.leadMin);
}

@override
String toString() {
  final _this = this as NotificationPref;
  return 'NotificationPref(onValue: ${_this.onValue}, leadMin: ${_this.leadMin})';
}


}

/// @nodoc
abstract mixin class $NotificationPrefCopyWith<$Res>  {
  factory $NotificationPrefCopyWith(NotificationPref value, $Res Function(NotificationPref) _then) = _$NotificationPrefCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'on') bool onValue,@JsonKey(name: 'lead_min') NotificationPrefLeadMin? leadMin
});




}
/// @nodoc
class _$NotificationPrefCopyWithImpl<$Res>
    implements $NotificationPrefCopyWith<$Res> {
  _$NotificationPrefCopyWithImpl(this._self, this._then);

  final NotificationPref _self;
  final $Res Function(NotificationPref) _then;

/// Create a copy of NotificationPref
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? onValue = null,Object? leadMin = freezed,}) {
  return _then(NotificationPref(
onValue: null == onValue ? _self.onValue : onValue // ignore: cast_nullable_to_non_nullable
as bool,leadMin: freezed == leadMin ? _self.leadMin : leadMin // ignore: cast_nullable_to_non_nullable
as NotificationPrefLeadMin?,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationPref].
extension NotificationPrefPatterns on NotificationPref {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPref value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPref() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPref value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPref():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPref value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPref() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'on')  bool onValue, @JsonKey(name: 'lead_min')  NotificationPrefLeadMin? leadMin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPref() when $default != null:
return $default(_that.onValue,_that.leadMin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'on')  bool onValue, @JsonKey(name: 'lead_min')  NotificationPrefLeadMin? leadMin)  $default,) {final _that = this;
switch (_that) {
case _NotificationPref():
return $default(_that.onValue,_that.leadMin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'on')  bool onValue, @JsonKey(name: 'lead_min')  NotificationPrefLeadMin? leadMin)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPref() when $default != null:
return $default(_that.onValue,_that.leadMin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationPref implements NotificationPref {
  const _NotificationPref({@JsonKey(name: 'on') this.onValue = true, @JsonKey(name: 'lead_min') this.leadMin});
  factory _NotificationPref.fromJson(Map<String, dynamic> json) => _$NotificationPrefFromJson(json);

/// The name has been replaced because it contains a keyword. Original name: `on`.
@override@JsonKey(name: 'on') final  bool onValue;
@override@JsonKey(name: 'lead_min') final  NotificationPrefLeadMin? leadMin;

/// Create a copy of NotificationPref
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPrefCopyWith<_NotificationPref> get copyWith => __$NotificationPrefCopyWithImpl<_NotificationPref>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationPrefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPref&&(identical(other.onValue, onValue) || other.onValue == onValue)&&(identical(other.leadMin, leadMin) || other.leadMin == leadMin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,onValue,leadMin);
}

@override
String toString() {
    return 'NotificationPref(onValue: $onValue, leadMin: $leadMin)';
}


}

/// @nodoc
abstract mixin class _$NotificationPrefCopyWith<$Res> implements $NotificationPrefCopyWith<$Res> {
  factory _$NotificationPrefCopyWith(_NotificationPref value, $Res Function(_NotificationPref) _then) = __$NotificationPrefCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'on') bool onValue,@JsonKey(name: 'lead_min') NotificationPrefLeadMin? leadMin
});




}
/// @nodoc
class __$NotificationPrefCopyWithImpl<$Res>
    implements _$NotificationPrefCopyWith<$Res> {
  __$NotificationPrefCopyWithImpl(this._self, this._then);

  final _NotificationPref _self;
  final $Res Function(_NotificationPref) _then;

/// Create a copy of NotificationPref
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? onValue = null,Object? leadMin = freezed,}) {
  return _then(_NotificationPref(
onValue: null == onValue ? _self.onValue : onValue // ignore: cast_nullable_to_non_nullable
as bool,leadMin: freezed == leadMin ? _self.leadMin : leadMin // ignore: cast_nullable_to_non_nullable
as NotificationPrefLeadMin?,
  ));
}


}

// dart format on
