// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rights_holder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RightsHolder {

 int get id; String? get logo; String get name;@JsonKey(name: 'sort_order') int? get sortOrder;
/// Create a copy of RightsHolder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RightsHolderCopyWith<RightsHolder> get copyWith => _$RightsHolderCopyWithImpl<RightsHolder>(this as RightsHolder, _$identity);

  /// Serializes this RightsHolder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RightsHolder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RightsHolder&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RightsHolder;
  return Object.hash(runtimeType,_this.id,_this.logo,_this.name,_this.sortOrder);
}

@override
String toString() {
  final _this = this as RightsHolder;
  return 'RightsHolder(id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, sortOrder: ${_this.sortOrder})';
}


}

/// @nodoc
abstract mixin class $RightsHolderCopyWith<$Res>  {
  factory $RightsHolderCopyWith(RightsHolder value, $Res Function(RightsHolder) _then) = _$RightsHolderCopyWithImpl;
@useResult
$Res call({
 int id, String? logo, String name,@JsonKey(name: 'sort_order') int? sortOrder
});




}
/// @nodoc
class _$RightsHolderCopyWithImpl<$Res>
    implements $RightsHolderCopyWith<$Res> {
  _$RightsHolderCopyWithImpl(this._self, this._then);

  final RightsHolder _self;
  final $Res Function(RightsHolder) _then;

/// Create a copy of RightsHolder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? logo = freezed,Object? name = null,Object? sortOrder = freezed,}) {
  return _then(RightsHolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RightsHolder].
extension RightsHolderPatterns on RightsHolder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RightsHolder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RightsHolder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RightsHolder value)  $default,){
final _that = this;
switch (_that) {
case _RightsHolder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RightsHolder value)?  $default,){
final _that = this;
switch (_that) {
case _RightsHolder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? logo,  String name, @JsonKey(name: 'sort_order')  int? sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RightsHolder() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? logo,  String name, @JsonKey(name: 'sort_order')  int? sortOrder)  $default,) {final _that = this;
switch (_that) {
case _RightsHolder():
return $default(_that.id,_that.logo,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? logo,  String name, @JsonKey(name: 'sort_order')  int? sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _RightsHolder() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RightsHolder implements RightsHolder {
  const _RightsHolder({required this.id, required this.logo, required this.name, @JsonKey(name: 'sort_order') required this.sortOrder});
  factory _RightsHolder.fromJson(Map<String, dynamic> json) => _$RightsHolderFromJson(json);

@override final  int id;
@override final  String? logo;
@override final  String name;
@override@JsonKey(name: 'sort_order') final  int? sortOrder;

/// Create a copy of RightsHolder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RightsHolderCopyWith<_RightsHolder> get copyWith => __$RightsHolderCopyWithImpl<_RightsHolder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RightsHolderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RightsHolder&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,logo,name,sortOrder);
}

@override
String toString() {
    return 'RightsHolder(id: $id, logo: $logo, name: $name, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$RightsHolderCopyWith<$Res> implements $RightsHolderCopyWith<$Res> {
  factory _$RightsHolderCopyWith(_RightsHolder value, $Res Function(_RightsHolder) _then) = __$RightsHolderCopyWithImpl;
@override @useResult
$Res call({
 int id, String? logo, String name,@JsonKey(name: 'sort_order') int? sortOrder
});




}
/// @nodoc
class __$RightsHolderCopyWithImpl<$Res>
    implements _$RightsHolderCopyWith<$Res> {
  __$RightsHolderCopyWithImpl(this._self, this._then);

  final _RightsHolder _self;
  final $Res Function(_RightsHolder) _then;

/// Create a copy of RightsHolder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? logo = freezed,Object? name = null,Object? sortOrder = freezed,}) {
  return _then(_RightsHolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
