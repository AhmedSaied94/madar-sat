// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope_follow_set.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EnvelopeFollowSet {

 FollowSet? get data; ErrorBody? get error; dynamic get meta; bool get success;
/// Create a copy of EnvelopeFollowSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnvelopeFollowSetCopyWith<EnvelopeFollowSet> get copyWith => _$EnvelopeFollowSetCopyWithImpl<EnvelopeFollowSet>(this as EnvelopeFollowSet, _$identity);

  /// Serializes this EnvelopeFollowSet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EnvelopeFollowSet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnvelopeFollowSet&&(identical(other.data, _this.data) || other.data == _this.data)&&(identical(other.error, _this.error) || other.error == _this.error)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.success, _this.success) || other.success == _this.success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EnvelopeFollowSet;
  return Object.hash(runtimeType,_this.data,_this.error,const DeepCollectionEquality().hash(_this.meta),_this.success);
}

@override
String toString() {
  final _this = this as EnvelopeFollowSet;
  return 'EnvelopeFollowSet(data: ${_this.data}, error: ${_this.error}, meta: ${_this.meta}, success: ${_this.success})';
}


}

/// @nodoc
abstract mixin class $EnvelopeFollowSetCopyWith<$Res>  {
  factory $EnvelopeFollowSetCopyWith(EnvelopeFollowSet value, $Res Function(EnvelopeFollowSet) _then) = _$EnvelopeFollowSetCopyWithImpl;
@useResult
$Res call({
 FollowSet? data, ErrorBody? error, dynamic meta, bool success
});


$FollowSetCopyWith<$Res>? get data;$ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class _$EnvelopeFollowSetCopyWithImpl<$Res>
    implements $EnvelopeFollowSetCopyWith<$Res> {
  _$EnvelopeFollowSetCopyWithImpl(this._self, this._then);

  final EnvelopeFollowSet _self;
  final $Res Function(EnvelopeFollowSet) _then;

/// Create a copy of EnvelopeFollowSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(EnvelopeFollowSet(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as FollowSet?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of EnvelopeFollowSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FollowSetCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $FollowSetCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}/// Create a copy of EnvelopeFollowSet
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


/// Adds pattern-matching-related methods to [EnvelopeFollowSet].
extension EnvelopeFollowSetPatterns on EnvelopeFollowSet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EnvelopeFollowSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EnvelopeFollowSet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EnvelopeFollowSet value)  $default,){
final _that = this;
switch (_that) {
case _EnvelopeFollowSet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EnvelopeFollowSet value)?  $default,){
final _that = this;
switch (_that) {
case _EnvelopeFollowSet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( FollowSet? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EnvelopeFollowSet() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( FollowSet? data,  ErrorBody? error,  dynamic meta,  bool success)  $default,) {final _that = this;
switch (_that) {
case _EnvelopeFollowSet():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( FollowSet? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,) {final _that = this;
switch (_that) {
case _EnvelopeFollowSet() when $default != null:
return $default(_that.data,_that.error,_that.meta,_that.success);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EnvelopeFollowSet implements EnvelopeFollowSet {
  const _EnvelopeFollowSet({required this.data, required this.error, required this.meta, required this.success});
  factory _EnvelopeFollowSet.fromJson(Map<String, dynamic> json) => _$EnvelopeFollowSetFromJson(json);

@override final  FollowSet? data;
@override final  ErrorBody? error;
@override final  dynamic meta;
@override final  bool success;

/// Create a copy of EnvelopeFollowSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnvelopeFollowSetCopyWith<_EnvelopeFollowSet> get copyWith => __$EnvelopeFollowSetCopyWithImpl<_EnvelopeFollowSet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnvelopeFollowSetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EnvelopeFollowSet&&(identical(other.data, data) || other.data == data)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.meta, meta)&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data,error,const DeepCollectionEquality().hash(meta),success);
}

@override
String toString() {
    return 'EnvelopeFollowSet(data: $data, error: $error, meta: $meta, success: $success)';
}


}

/// @nodoc
abstract mixin class _$EnvelopeFollowSetCopyWith<$Res> implements $EnvelopeFollowSetCopyWith<$Res> {
  factory _$EnvelopeFollowSetCopyWith(_EnvelopeFollowSet value, $Res Function(_EnvelopeFollowSet) _then) = __$EnvelopeFollowSetCopyWithImpl;
@override @useResult
$Res call({
 FollowSet? data, ErrorBody? error, dynamic meta, bool success
});


@override $FollowSetCopyWith<$Res>? get data;@override $ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class __$EnvelopeFollowSetCopyWithImpl<$Res>
    implements _$EnvelopeFollowSetCopyWith<$Res> {
  __$EnvelopeFollowSetCopyWithImpl(this._self, this._then);

  final _EnvelopeFollowSet _self;
  final $Res Function(_EnvelopeFollowSet) _then;

/// Create a copy of EnvelopeFollowSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(_EnvelopeFollowSet(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as FollowSet?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of EnvelopeFollowSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FollowSetCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $FollowSetCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}/// Create a copy of EnvelopeFollowSet
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
