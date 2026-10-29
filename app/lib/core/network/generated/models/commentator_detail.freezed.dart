// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'commentator_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommentatorDetail {

 String? get audio; int get id; String? get image; String get name; List<MatchSummary> get upcoming;
/// Create a copy of CommentatorDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommentatorDetailCopyWith<CommentatorDetail> get copyWith => _$CommentatorDetailCopyWithImpl<CommentatorDetail>(this as CommentatorDetail, _$identity);

  /// Serializes this CommentatorDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CommentatorDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommentatorDetail&&(identical(other.audio, _this.audio) || other.audio == _this.audio)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.image, _this.image) || other.image == _this.image)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.upcoming, _this.upcoming));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CommentatorDetail;
  return Object.hash(runtimeType,_this.audio,_this.id,_this.image,_this.name,const DeepCollectionEquality().hash(_this.upcoming));
}

@override
String toString() {
  final _this = this as CommentatorDetail;
  return 'CommentatorDetail(audio: ${_this.audio}, id: ${_this.id}, image: ${_this.image}, name: ${_this.name}, upcoming: ${_this.upcoming})';
}


}

/// @nodoc
abstract mixin class $CommentatorDetailCopyWith<$Res>  {
  factory $CommentatorDetailCopyWith(CommentatorDetail value, $Res Function(CommentatorDetail) _then) = _$CommentatorDetailCopyWithImpl;
@useResult
$Res call({
 String? audio, int id, String? image, String name, List<MatchSummary> upcoming
});




}
/// @nodoc
class _$CommentatorDetailCopyWithImpl<$Res>
    implements $CommentatorDetailCopyWith<$Res> {
  _$CommentatorDetailCopyWithImpl(this._self, this._then);

  final CommentatorDetail _self;
  final $Res Function(CommentatorDetail) _then;

/// Create a copy of CommentatorDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? audio = freezed,Object? id = null,Object? image = freezed,Object? name = null,Object? upcoming = null,}) {
  return _then(CommentatorDetail(
audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,upcoming: null == upcoming ? _self.upcoming : upcoming // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommentatorDetail].
extension CommentatorDetailPatterns on CommentatorDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommentatorDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommentatorDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommentatorDetail value)  $default,){
final _that = this;
switch (_that) {
case _CommentatorDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommentatorDetail value)?  $default,){
final _that = this;
switch (_that) {
case _CommentatorDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? audio,  int id,  String? image,  String name,  List<MatchSummary> upcoming)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommentatorDetail() when $default != null:
return $default(_that.audio,_that.id,_that.image,_that.name,_that.upcoming);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? audio,  int id,  String? image,  String name,  List<MatchSummary> upcoming)  $default,) {final _that = this;
switch (_that) {
case _CommentatorDetail():
return $default(_that.audio,_that.id,_that.image,_that.name,_that.upcoming);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? audio,  int id,  String? image,  String name,  List<MatchSummary> upcoming)?  $default,) {final _that = this;
switch (_that) {
case _CommentatorDetail() when $default != null:
return $default(_that.audio,_that.id,_that.image,_that.name,_that.upcoming);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommentatorDetail implements CommentatorDetail {
  const _CommentatorDetail({required this.audio, required this.id, required this.image, required this.name, required  List<MatchSummary> upcoming}): _upcoming = upcoming;
  factory _CommentatorDetail.fromJson(Map<String, dynamic> json) => _$CommentatorDetailFromJson(json);

@override final  String? audio;
@override final  int id;
@override final  String? image;
@override final  String name;
 final  List<MatchSummary> _upcoming;
@override List<MatchSummary> get upcoming {
  if (_upcoming is EqualUnmodifiableListView) return _upcoming;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_upcoming);
}


/// Create a copy of CommentatorDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommentatorDetailCopyWith<_CommentatorDetail> get copyWith => __$CommentatorDetailCopyWithImpl<_CommentatorDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommentatorDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommentatorDetail&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.id, id) || other.id == id)&&(identical(other.image, image) || other.image == image)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.upcoming, _upcoming));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,audio,id,image,name,const DeepCollectionEquality().hash(_upcoming));
}

@override
String toString() {
    return 'CommentatorDetail(audio: $audio, id: $id, image: $image, name: $name, upcoming: $upcoming)';
}


}

/// @nodoc
abstract mixin class _$CommentatorDetailCopyWith<$Res> implements $CommentatorDetailCopyWith<$Res> {
  factory _$CommentatorDetailCopyWith(_CommentatorDetail value, $Res Function(_CommentatorDetail) _then) = __$CommentatorDetailCopyWithImpl;
@override @useResult
$Res call({
 String? audio, int id, String? image, String name, List<MatchSummary> upcoming
});




}
/// @nodoc
class __$CommentatorDetailCopyWithImpl<$Res>
    implements _$CommentatorDetailCopyWith<$Res> {
  __$CommentatorDetailCopyWithImpl(this._self, this._then);

  final _CommentatorDetail _self;
  final $Res Function(_CommentatorDetail) _then;

/// Create a copy of CommentatorDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? audio = freezed,Object? id = null,Object? image = freezed,Object? name = null,Object? upcoming = null,}) {
  return _then(_CommentatorDetail(
audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,upcoming: null == upcoming ? _self._upcoming : upcoming // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,
  ));
}


}

// dart format on
