// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope_list_live_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EnvelopeListLiveState {

 List<LiveState>? get data; ErrorBody? get error; dynamic get meta; bool get success;
/// Create a copy of EnvelopeListLiveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnvelopeListLiveStateCopyWith<EnvelopeListLiveState> get copyWith => _$EnvelopeListLiveStateCopyWithImpl<EnvelopeListLiveState>(this as EnvelopeListLiveState, _$identity);

  /// Serializes this EnvelopeListLiveState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EnvelopeListLiveState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnvelopeListLiveState&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.error, _this.error) || other.error == _this.error)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.success, _this.success) || other.success == _this.success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EnvelopeListLiveState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.error,const DeepCollectionEquality().hash(_this.meta),_this.success);
}

@override
String toString() {
  final _this = this as EnvelopeListLiveState;
  return 'EnvelopeListLiveState(data: ${_this.data}, error: ${_this.error}, meta: ${_this.meta}, success: ${_this.success})';
}


}

/// @nodoc
abstract mixin class $EnvelopeListLiveStateCopyWith<$Res>  {
  factory $EnvelopeListLiveStateCopyWith(EnvelopeListLiveState value, $Res Function(EnvelopeListLiveState) _then) = _$EnvelopeListLiveStateCopyWithImpl;
@useResult
$Res call({
 List<LiveState>? data, ErrorBody? error, dynamic meta, bool success
});


$ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class _$EnvelopeListLiveStateCopyWithImpl<$Res>
    implements $EnvelopeListLiveStateCopyWith<$Res> {
  _$EnvelopeListLiveStateCopyWithImpl(this._self, this._then);

  final EnvelopeListLiveState _self;
  final $Res Function(EnvelopeListLiveState) _then;

/// Create a copy of EnvelopeListLiveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(EnvelopeListLiveState(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<LiveState>?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of EnvelopeListLiveState
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


/// Adds pattern-matching-related methods to [EnvelopeListLiveState].
extension EnvelopeListLiveStatePatterns on EnvelopeListLiveState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EnvelopeListLiveState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EnvelopeListLiveState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EnvelopeListLiveState value)  $default,){
final _that = this;
switch (_that) {
case _EnvelopeListLiveState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EnvelopeListLiveState value)?  $default,){
final _that = this;
switch (_that) {
case _EnvelopeListLiveState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LiveState>? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EnvelopeListLiveState() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LiveState>? data,  ErrorBody? error,  dynamic meta,  bool success)  $default,) {final _that = this;
switch (_that) {
case _EnvelopeListLiveState():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LiveState>? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,) {final _that = this;
switch (_that) {
case _EnvelopeListLiveState() when $default != null:
return $default(_that.data,_that.error,_that.meta,_that.success);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EnvelopeListLiveState implements EnvelopeListLiveState {
  const _EnvelopeListLiveState({required  List<LiveState>? data, required this.error, required this.meta, required this.success}): _data = data;
  factory _EnvelopeListLiveState.fromJson(Map<String, dynamic> json) => _$EnvelopeListLiveStateFromJson(json);

 final  List<LiveState>? _data;
@override List<LiveState>? get data {
  final value = _data;
  if (value == null) return null;
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  ErrorBody? error;
@override final  dynamic meta;
@override final  bool success;

/// Create a copy of EnvelopeListLiveState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnvelopeListLiveStateCopyWith<_EnvelopeListLiveState> get copyWith => __$EnvelopeListLiveStateCopyWithImpl<_EnvelopeListLiveState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnvelopeListLiveStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EnvelopeListLiveState&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.meta, meta)&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),error,const DeepCollectionEquality().hash(meta),success);
}

@override
String toString() {
    return 'EnvelopeListLiveState(data: $data, error: $error, meta: $meta, success: $success)';
}


}

/// @nodoc
abstract mixin class _$EnvelopeListLiveStateCopyWith<$Res> implements $EnvelopeListLiveStateCopyWith<$Res> {
  factory _$EnvelopeListLiveStateCopyWith(_EnvelopeListLiveState value, $Res Function(_EnvelopeListLiveState) _then) = __$EnvelopeListLiveStateCopyWithImpl;
@override @useResult
$Res call({
 List<LiveState>? data, ErrorBody? error, dynamic meta, bool success
});


@override $ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class __$EnvelopeListLiveStateCopyWithImpl<$Res>
    implements _$EnvelopeListLiveStateCopyWith<$Res> {
  __$EnvelopeListLiveStateCopyWithImpl(this._self, this._then);

  final _EnvelopeListLiveState _self;
  final $Res Function(_EnvelopeListLiveState) _then;

/// Create a copy of EnvelopeListLiveState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(_EnvelopeListLiveState(
data: freezed == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<LiveState>?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of EnvelopeListLiveState
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
