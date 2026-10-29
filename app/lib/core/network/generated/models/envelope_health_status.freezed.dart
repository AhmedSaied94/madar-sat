// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope_health_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EnvelopeHealthStatus {

 HealthStatus? get data; ErrorBody? get error; dynamic get meta; bool get success;
/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnvelopeHealthStatusCopyWith<EnvelopeHealthStatus> get copyWith => _$EnvelopeHealthStatusCopyWithImpl<EnvelopeHealthStatus>(this as EnvelopeHealthStatus, _$identity);

  /// Serializes this EnvelopeHealthStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EnvelopeHealthStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnvelopeHealthStatus&&(identical(other.data, _this.data) || other.data == _this.data)&&(identical(other.error, _this.error) || other.error == _this.error)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.success, _this.success) || other.success == _this.success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EnvelopeHealthStatus;
  return Object.hash(runtimeType,_this.data,_this.error,const DeepCollectionEquality().hash(_this.meta),_this.success);
}

@override
String toString() {
  final _this = this as EnvelopeHealthStatus;
  return 'EnvelopeHealthStatus(data: ${_this.data}, error: ${_this.error}, meta: ${_this.meta}, success: ${_this.success})';
}


}

/// @nodoc
abstract mixin class $EnvelopeHealthStatusCopyWith<$Res>  {
  factory $EnvelopeHealthStatusCopyWith(EnvelopeHealthStatus value, $Res Function(EnvelopeHealthStatus) _then) = _$EnvelopeHealthStatusCopyWithImpl;
@useResult
$Res call({
 HealthStatus? data, ErrorBody? error, dynamic meta, bool success
});


$HealthStatusCopyWith<$Res>? get data;$ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class _$EnvelopeHealthStatusCopyWithImpl<$Res>
    implements $EnvelopeHealthStatusCopyWith<$Res> {
  _$EnvelopeHealthStatusCopyWithImpl(this._self, this._then);

  final EnvelopeHealthStatus _self;
  final $Res Function(EnvelopeHealthStatus) _then;

/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(EnvelopeHealthStatus(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as HealthStatus?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthStatusCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $HealthStatusCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ErrorBodyCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $ErrorBodyCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [EnvelopeHealthStatus].
extension EnvelopeHealthStatusPatterns on EnvelopeHealthStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EnvelopeHealthStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EnvelopeHealthStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EnvelopeHealthStatus value)  $default,){
final _that = this;
switch (_that) {
case _EnvelopeHealthStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EnvelopeHealthStatus value)?  $default,){
final _that = this;
switch (_that) {
case _EnvelopeHealthStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( HealthStatus? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EnvelopeHealthStatus() when $default != null:
return $default(_that.data,_that.error,_that.meta,_that.success);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( HealthStatus? data,  ErrorBody? error,  dynamic meta,  bool success)  $default,) {final _that = this;
switch (_that) {
case _EnvelopeHealthStatus():
return $default(_that.data,_that.error,_that.meta,_that.success);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( HealthStatus? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,) {final _that = this;
switch (_that) {
case _EnvelopeHealthStatus() when $default != null:
return $default(_that.data,_that.error,_that.meta,_that.success);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EnvelopeHealthStatus implements EnvelopeHealthStatus {
  const _EnvelopeHealthStatus({required this.data, required this.error, required this.meta, required this.success});
  factory _EnvelopeHealthStatus.fromJson(Map<String, dynamic> json) => _$EnvelopeHealthStatusFromJson(json);

@override final  HealthStatus? data;
@override final  ErrorBody? error;
@override final  dynamic meta;
@override final  bool success;

/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnvelopeHealthStatusCopyWith<_EnvelopeHealthStatus> get copyWith => __$EnvelopeHealthStatusCopyWithImpl<_EnvelopeHealthStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnvelopeHealthStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EnvelopeHealthStatus&&(identical(other.data, data) || other.data == data)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.meta, meta)&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data,error,const DeepCollectionEquality().hash(meta),success);
}

@override
String toString() {
    return 'EnvelopeHealthStatus(data: $data, error: $error, meta: $meta, success: $success)';
}


}

/// @nodoc
abstract mixin class _$EnvelopeHealthStatusCopyWith<$Res> implements $EnvelopeHealthStatusCopyWith<$Res> {
  factory _$EnvelopeHealthStatusCopyWith(_EnvelopeHealthStatus value, $Res Function(_EnvelopeHealthStatus) _then) = __$EnvelopeHealthStatusCopyWithImpl;
@override @useResult
$Res call({
 HealthStatus? data, ErrorBody? error, dynamic meta, bool success
});


@override $HealthStatusCopyWith<$Res>? get data;@override $ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class __$EnvelopeHealthStatusCopyWithImpl<$Res>
    implements _$EnvelopeHealthStatusCopyWith<$Res> {
  __$EnvelopeHealthStatusCopyWithImpl(this._self, this._then);

  final _EnvelopeHealthStatus _self;
  final $Res Function(_EnvelopeHealthStatus) _then;

/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(_EnvelopeHealthStatus(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as HealthStatus?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HealthStatusCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $HealthStatusCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}/// Create a copy of EnvelopeHealthStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ErrorBodyCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $ErrorBodyCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
