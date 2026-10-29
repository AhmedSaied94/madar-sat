// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'satellite_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SatelliteRef {

 int get id;@JsonKey(name: 'name_ar') String get nameAr;@JsonKey(name: 'name_en') String get nameEn;@JsonKey(name: 'orbital_position') num? get orbitalPosition; String get slug;
/// Create a copy of SatelliteRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SatelliteRefCopyWith<SatelliteRef> get copyWith => _$SatelliteRefCopyWithImpl<SatelliteRef>(this as SatelliteRef, _$identity);

  /// Serializes this SatelliteRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SatelliteRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SatelliteRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.nameAr, _this.nameAr) || other.nameAr == _this.nameAr)&&(identical(other.nameEn, _this.nameEn) || other.nameEn == _this.nameEn)&&(identical(other.orbitalPosition, _this.orbitalPosition) || other.orbitalPosition == _this.orbitalPosition)&&(identical(other.slug, _this.slug) || other.slug == _this.slug));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SatelliteRef;
  return Object.hash(runtimeType,_this.id,_this.nameAr,_this.nameEn,_this.orbitalPosition,_this.slug);
}

@override
String toString() {
  final _this = this as SatelliteRef;
  return 'SatelliteRef(id: ${_this.id}, nameAr: ${_this.nameAr}, nameEn: ${_this.nameEn}, orbitalPosition: ${_this.orbitalPosition}, slug: ${_this.slug})';
}


}

/// @nodoc
abstract mixin class $SatelliteRefCopyWith<$Res>  {
  factory $SatelliteRefCopyWith(SatelliteRef value, $Res Function(SatelliteRef) _then) = _$SatelliteRefCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'name_ar') String nameAr,@JsonKey(name: 'name_en') String nameEn,@JsonKey(name: 'orbital_position') num? orbitalPosition, String slug
});




}
/// @nodoc
class _$SatelliteRefCopyWithImpl<$Res>
    implements $SatelliteRefCopyWith<$Res> {
  _$SatelliteRefCopyWithImpl(this._self, this._then);

  final SatelliteRef _self;
  final $Res Function(SatelliteRef) _then;

/// Create a copy of SatelliteRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nameAr = null,Object? nameEn = null,Object? orbitalPosition = freezed,Object? slug = null,}) {
  return _then(SatelliteRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,orbitalPosition: freezed == orbitalPosition ? _self.orbitalPosition : orbitalPosition // ignore: cast_nullable_to_non_nullable
as num?,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SatelliteRef].
extension SatelliteRefPatterns on SatelliteRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SatelliteRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SatelliteRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SatelliteRef value)  $default,){
final _that = this;
switch (_that) {
case _SatelliteRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SatelliteRef value)?  $default,){
final _that = this;
switch (_that) {
case _SatelliteRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'name_ar')  String nameAr, @JsonKey(name: 'name_en')  String nameEn, @JsonKey(name: 'orbital_position')  num? orbitalPosition,  String slug)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SatelliteRef() when $default != null:
return $default(_that.id,_that.nameAr,_that.nameEn,_that.orbitalPosition,_that.slug);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'name_ar')  String nameAr, @JsonKey(name: 'name_en')  String nameEn, @JsonKey(name: 'orbital_position')  num? orbitalPosition,  String slug)  $default,) {final _that = this;
switch (_that) {
case _SatelliteRef():
return $default(_that.id,_that.nameAr,_that.nameEn,_that.orbitalPosition,_that.slug);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'name_ar')  String nameAr, @JsonKey(name: 'name_en')  String nameEn, @JsonKey(name: 'orbital_position')  num? orbitalPosition,  String slug)?  $default,) {final _that = this;
switch (_that) {
case _SatelliteRef() when $default != null:
return $default(_that.id,_that.nameAr,_that.nameEn,_that.orbitalPosition,_that.slug);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SatelliteRef implements SatelliteRef {
  const _SatelliteRef({required this.id, @JsonKey(name: 'name_ar') required this.nameAr, @JsonKey(name: 'name_en') required this.nameEn, @JsonKey(name: 'orbital_position') required this.orbitalPosition, required this.slug});
  factory _SatelliteRef.fromJson(Map<String, dynamic> json) => _$SatelliteRefFromJson(json);

@override final  int id;
@override@JsonKey(name: 'name_ar') final  String nameAr;
@override@JsonKey(name: 'name_en') final  String nameEn;
@override@JsonKey(name: 'orbital_position') final  num? orbitalPosition;
@override final  String slug;

/// Create a copy of SatelliteRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SatelliteRefCopyWith<_SatelliteRef> get copyWith => __$SatelliteRefCopyWithImpl<_SatelliteRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SatelliteRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SatelliteRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nameAr, nameAr) || other.nameAr == nameAr)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.orbitalPosition, orbitalPosition) || other.orbitalPosition == orbitalPosition)&&(identical(other.slug, slug) || other.slug == slug));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,nameAr,nameEn,orbitalPosition,slug);
}

@override
String toString() {
    return 'SatelliteRef(id: $id, nameAr: $nameAr, nameEn: $nameEn, orbitalPosition: $orbitalPosition, slug: $slug)';
}


}

/// @nodoc
abstract mixin class _$SatelliteRefCopyWith<$Res> implements $SatelliteRefCopyWith<$Res> {
  factory _$SatelliteRefCopyWith(_SatelliteRef value, $Res Function(_SatelliteRef) _then) = __$SatelliteRefCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'name_ar') String nameAr,@JsonKey(name: 'name_en') String nameEn,@JsonKey(name: 'orbital_position') num? orbitalPosition, String slug
});




}
/// @nodoc
class __$SatelliteRefCopyWithImpl<$Res>
    implements _$SatelliteRefCopyWith<$Res> {
  __$SatelliteRefCopyWithImpl(this._self, this._then);

  final _SatelliteRef _self;
  final $Res Function(_SatelliteRef) _then;

/// Create a copy of SatelliteRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nameAr = null,Object? nameEn = null,Object? orbitalPosition = freezed,Object? slug = null,}) {
  return _then(_SatelliteRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,orbitalPosition: freezed == orbitalPosition ? _self.orbitalPosition : orbitalPosition // ignore: cast_nullable_to_non_nullable
as num?,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
