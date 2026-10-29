// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamRef {

 int? get id; String? get logo; String get name;
/// Create a copy of TeamRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamRefCopyWith<TeamRef> get copyWith => _$TeamRefCopyWithImpl<TeamRef>(this as TeamRef, _$identity);

  /// Serializes this TeamRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamRef;
  return Object.hash(runtimeType,_this.id,_this.logo,_this.name);
}

@override
String toString() {
  final _this = this as TeamRef;
  return 'TeamRef(id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $TeamRefCopyWith<$Res>  {
  factory $TeamRefCopyWith(TeamRef value, $Res Function(TeamRef) _then) = _$TeamRefCopyWithImpl;
@useResult
$Res call({
 int? id, String? logo, String name
});




}
/// @nodoc
class _$TeamRefCopyWithImpl<$Res>
    implements $TeamRefCopyWith<$Res> {
  _$TeamRefCopyWithImpl(this._self, this._then);

  final TeamRef _self;
  final $Res Function(TeamRef) _then;

/// Create a copy of TeamRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? logo = freezed,Object? name = null,}) {
  return _then(TeamRef(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamRef].
extension TeamRefPatterns on TeamRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamRef value)  $default,){
final _that = this;
switch (_that) {
case _TeamRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamRef value)?  $default,){
final _that = this;
switch (_that) {
case _TeamRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String? logo,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamRef() when $default != null:
return $default(_that.id,_that.logo,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String? logo,  String name)  $default,) {final _that = this;
switch (_that) {
case _TeamRef():
return $default(_that.id,_that.logo,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String? logo,  String name)?  $default,) {final _that = this;
switch (_that) {
case _TeamRef() when $default != null:
return $default(_that.id,_that.logo,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamRef implements TeamRef {
  const _TeamRef({required this.id, required this.logo, required this.name});
  factory _TeamRef.fromJson(Map<String, dynamic> json) => _$TeamRefFromJson(json);

@override final  int? id;
@override final  String? logo;
@override final  String name;

/// Create a copy of TeamRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamRefCopyWith<_TeamRef> get copyWith => __$TeamRefCopyWithImpl<_TeamRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamRef&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,logo,name);
}

@override
String toString() {
    return 'TeamRef(id: $id, logo: $logo, name: $name)';
}


}

/// @nodoc
abstract mixin class _$TeamRefCopyWith<$Res> implements $TeamRefCopyWith<$Res> {
  factory _$TeamRefCopyWith(_TeamRef value, $Res Function(_TeamRef) _then) = __$TeamRefCopyWithImpl;
@override @useResult
$Res call({
 int? id, String? logo, String name
});




}
/// @nodoc
class __$TeamRefCopyWithImpl<$Res>
    implements _$TeamRefCopyWith<$Res> {
  __$TeamRefCopyWithImpl(this._self, this._then);

  final _TeamRef _self;
  final $Res Function(_TeamRef) _then;

/// Create a copy of TeamRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? logo = freezed,Object? name = null,}) {
  return _then(_TeamRef(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
