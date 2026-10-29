// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope_list_team_search_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EnvelopeListTeamSearchItem {

 List<TeamSearchItem>? get data; ErrorBody? get error; dynamic get meta; bool get success;
/// Create a copy of EnvelopeListTeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnvelopeListTeamSearchItemCopyWith<EnvelopeListTeamSearchItem> get copyWith => _$EnvelopeListTeamSearchItemCopyWithImpl<EnvelopeListTeamSearchItem>(this as EnvelopeListTeamSearchItem, _$identity);

  /// Serializes this EnvelopeListTeamSearchItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EnvelopeListTeamSearchItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnvelopeListTeamSearchItem&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.error, _this.error) || other.error == _this.error)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.success, _this.success) || other.success == _this.success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EnvelopeListTeamSearchItem;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.error,const DeepCollectionEquality().hash(_this.meta),_this.success);
}

@override
String toString() {
  final _this = this as EnvelopeListTeamSearchItem;
  return 'EnvelopeListTeamSearchItem(data: ${_this.data}, error: ${_this.error}, meta: ${_this.meta}, success: ${_this.success})';
}


}

/// @nodoc
abstract mixin class $EnvelopeListTeamSearchItemCopyWith<$Res>  {
  factory $EnvelopeListTeamSearchItemCopyWith(EnvelopeListTeamSearchItem value, $Res Function(EnvelopeListTeamSearchItem) _then) = _$EnvelopeListTeamSearchItemCopyWithImpl;
@useResult
$Res call({
 List<TeamSearchItem>? data, ErrorBody? error, dynamic meta, bool success
});


$ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class _$EnvelopeListTeamSearchItemCopyWithImpl<$Res>
    implements $EnvelopeListTeamSearchItemCopyWith<$Res> {
  _$EnvelopeListTeamSearchItemCopyWithImpl(this._self, this._then);

  final EnvelopeListTeamSearchItem _self;
  final $Res Function(EnvelopeListTeamSearchItem) _then;

/// Create a copy of EnvelopeListTeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(EnvelopeListTeamSearchItem(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TeamSearchItem>?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of EnvelopeListTeamSearchItem
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


/// Adds pattern-matching-related methods to [EnvelopeListTeamSearchItem].
extension EnvelopeListTeamSearchItemPatterns on EnvelopeListTeamSearchItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EnvelopeListTeamSearchItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EnvelopeListTeamSearchItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EnvelopeListTeamSearchItem value)  $default,){
final _that = this;
switch (_that) {
case _EnvelopeListTeamSearchItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EnvelopeListTeamSearchItem value)?  $default,){
final _that = this;
switch (_that) {
case _EnvelopeListTeamSearchItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TeamSearchItem>? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EnvelopeListTeamSearchItem() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TeamSearchItem>? data,  ErrorBody? error,  dynamic meta,  bool success)  $default,) {final _that = this;
switch (_that) {
case _EnvelopeListTeamSearchItem():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TeamSearchItem>? data,  ErrorBody? error,  dynamic meta,  bool success)?  $default,) {final _that = this;
switch (_that) {
case _EnvelopeListTeamSearchItem() when $default != null:
return $default(_that.data,_that.error,_that.meta,_that.success);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EnvelopeListTeamSearchItem implements EnvelopeListTeamSearchItem {
  const _EnvelopeListTeamSearchItem({required  List<TeamSearchItem>? data, required this.error, required this.meta, required this.success}): _data = data;
  factory _EnvelopeListTeamSearchItem.fromJson(Map<String, dynamic> json) => _$EnvelopeListTeamSearchItemFromJson(json);

 final  List<TeamSearchItem>? _data;
@override List<TeamSearchItem>? get data {
  final value = _data;
  if (value == null) return null;
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  ErrorBody? error;
@override final  dynamic meta;
@override final  bool success;

/// Create a copy of EnvelopeListTeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnvelopeListTeamSearchItemCopyWith<_EnvelopeListTeamSearchItem> get copyWith => __$EnvelopeListTeamSearchItemCopyWithImpl<_EnvelopeListTeamSearchItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnvelopeListTeamSearchItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EnvelopeListTeamSearchItem&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.error, error) || other.error == error)&&const DeepCollectionEquality().equals(other.meta, meta)&&(identical(other.success, success) || other.success == success));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),error,const DeepCollectionEquality().hash(meta),success);
}

@override
String toString() {
    return 'EnvelopeListTeamSearchItem(data: $data, error: $error, meta: $meta, success: $success)';
}


}

/// @nodoc
abstract mixin class _$EnvelopeListTeamSearchItemCopyWith<$Res> implements $EnvelopeListTeamSearchItemCopyWith<$Res> {
  factory _$EnvelopeListTeamSearchItemCopyWith(_EnvelopeListTeamSearchItem value, $Res Function(_EnvelopeListTeamSearchItem) _then) = __$EnvelopeListTeamSearchItemCopyWithImpl;
@override @useResult
$Res call({
 List<TeamSearchItem>? data, ErrorBody? error, dynamic meta, bool success
});


@override $ErrorBodyCopyWith<$Res>? get error;

}
/// @nodoc
class __$EnvelopeListTeamSearchItemCopyWithImpl<$Res>
    implements _$EnvelopeListTeamSearchItemCopyWith<$Res> {
  __$EnvelopeListTeamSearchItemCopyWithImpl(this._self, this._then);

  final _EnvelopeListTeamSearchItem _self;
  final $Res Function(_EnvelopeListTeamSearchItem) _then;

/// Create a copy of EnvelopeListTeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,Object? error = freezed,Object? meta = freezed,Object? success = null,}) {
  return _then(_EnvelopeListTeamSearchItem(
data: freezed == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TeamSearchItem>?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ErrorBody?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as dynamic,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of EnvelopeListTeamSearchItem
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
