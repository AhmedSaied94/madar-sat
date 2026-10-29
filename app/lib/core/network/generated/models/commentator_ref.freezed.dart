// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'commentator_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommentatorRef {

 String? get audio; int get id; String? get image; String get name;
/// Create a copy of CommentatorRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommentatorRefCopyWith<CommentatorRef> get copyWith => _$CommentatorRefCopyWithImpl<CommentatorRef>(this as CommentatorRef, _$identity);

  /// Serializes this CommentatorRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CommentatorRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommentatorRef&&(identical(other.audio, _this.audio) || other.audio == _this.audio)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.image, _this.image) || other.image == _this.image)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CommentatorRef;
  return Object.hash(runtimeType,_this.audio,_this.id,_this.image,_this.name);
}

@override
String toString() {
  final _this = this as CommentatorRef;
  return 'CommentatorRef(audio: ${_this.audio}, id: ${_this.id}, image: ${_this.image}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $CommentatorRefCopyWith<$Res>  {
  factory $CommentatorRefCopyWith(CommentatorRef value, $Res Function(CommentatorRef) _then) = _$CommentatorRefCopyWithImpl;
@useResult
$Res call({
 String? audio, int id, String? image, String name
});




}
/// @nodoc
class _$CommentatorRefCopyWithImpl<$Res>
    implements $CommentatorRefCopyWith<$Res> {
  _$CommentatorRefCopyWithImpl(this._self, this._then);

  final CommentatorRef _self;
  final $Res Function(CommentatorRef) _then;

/// Create a copy of CommentatorRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? audio = freezed,Object? id = null,Object? image = freezed,Object? name = null,}) {
  return _then(CommentatorRef(
audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CommentatorRef].
extension CommentatorRefPatterns on CommentatorRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommentatorRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommentatorRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommentatorRef value)  $default,){
final _that = this;
switch (_that) {
case _CommentatorRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommentatorRef value)?  $default,){
final _that = this;
switch (_that) {
case _CommentatorRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? audio,  int id,  String? image,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommentatorRef() when $default != null:
return $default(_that.audio,_that.id,_that.image,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? audio,  int id,  String? image,  String name)  $default,) {final _that = this;
switch (_that) {
case _CommentatorRef():
return $default(_that.audio,_that.id,_that.image,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? audio,  int id,  String? image,  String name)?  $default,) {final _that = this;
switch (_that) {
case _CommentatorRef() when $default != null:
return $default(_that.audio,_that.id,_that.image,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommentatorRef implements CommentatorRef {
  const _CommentatorRef({required this.audio, required this.id, required this.image, required this.name});
  factory _CommentatorRef.fromJson(Map<String, dynamic> json) => _$CommentatorRefFromJson(json);

@override final  String? audio;
@override final  int id;
@override final  String? image;
@override final  String name;

/// Create a copy of CommentatorRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommentatorRefCopyWith<_CommentatorRef> get copyWith => __$CommentatorRefCopyWithImpl<_CommentatorRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommentatorRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommentatorRef&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.id, id) || other.id == id)&&(identical(other.image, image) || other.image == image)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,audio,id,image,name);
}

@override
String toString() {
    return 'CommentatorRef(audio: $audio, id: $id, image: $image, name: $name)';
}


}

/// @nodoc
abstract mixin class _$CommentatorRefCopyWith<$Res> implements $CommentatorRefCopyWith<$Res> {
  factory _$CommentatorRefCopyWith(_CommentatorRef value, $Res Function(_CommentatorRef) _then) = __$CommentatorRefCopyWithImpl;
@override @useResult
$Res call({
 String? audio, int id, String? image, String name
});




}
/// @nodoc
class __$CommentatorRefCopyWithImpl<$Res>
    implements _$CommentatorRefCopyWith<$Res> {
  __$CommentatorRefCopyWithImpl(this._self, this._then);

  final _CommentatorRef _self;
  final $Res Function(_CommentatorRef) _then;

/// Create a copy of CommentatorRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? audio = freezed,Object? id = null,Object? image = freezed,Object? name = null,}) {
  return _then(_CommentatorRef(
audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
