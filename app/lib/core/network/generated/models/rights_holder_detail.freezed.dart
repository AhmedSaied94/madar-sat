// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rights_holder_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RightsHolderDetail {

 List<RightsHolderCarriage> get carriages; List<NamedRef> get competitions; int get id; String? get logo; String get name;@JsonKey(name: 'sort_order') int? get sortOrder;
/// Create a copy of RightsHolderDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RightsHolderDetailCopyWith<RightsHolderDetail> get copyWith => _$RightsHolderDetailCopyWithImpl<RightsHolderDetail>(this as RightsHolderDetail, _$identity);

  /// Serializes this RightsHolderDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RightsHolderDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RightsHolderDetail&&const DeepCollectionEquality().equals(other.carriages, _this.carriages)&&const DeepCollectionEquality().equals(other.competitions, _this.competitions)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RightsHolderDetail;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.carriages),const DeepCollectionEquality().hash(_this.competitions),_this.id,_this.logo,_this.name,_this.sortOrder);
}

@override
String toString() {
  final _this = this as RightsHolderDetail;
  return 'RightsHolderDetail(carriages: ${_this.carriages}, competitions: ${_this.competitions}, id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, sortOrder: ${_this.sortOrder})';
}


}

/// @nodoc
abstract mixin class $RightsHolderDetailCopyWith<$Res>  {
  factory $RightsHolderDetailCopyWith(RightsHolderDetail value, $Res Function(RightsHolderDetail) _then) = _$RightsHolderDetailCopyWithImpl;
@useResult
$Res call({
 List<RightsHolderCarriage> carriages, List<NamedRef> competitions, int id, String? logo, String name,@JsonKey(name: 'sort_order') int? sortOrder
});




}
/// @nodoc
class _$RightsHolderDetailCopyWithImpl<$Res>
    implements $RightsHolderDetailCopyWith<$Res> {
  _$RightsHolderDetailCopyWithImpl(this._self, this._then);

  final RightsHolderDetail _self;
  final $Res Function(RightsHolderDetail) _then;

/// Create a copy of RightsHolderDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? carriages = null,Object? competitions = null,Object? id = null,Object? logo = freezed,Object? name = null,Object? sortOrder = freezed,}) {
  return _then(RightsHolderDetail(
carriages: null == carriages ? _self.carriages : carriages // ignore: cast_nullable_to_non_nullable
as List<RightsHolderCarriage>,competitions: null == competitions ? _self.competitions : competitions // ignore: cast_nullable_to_non_nullable
as List<NamedRef>,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RightsHolderDetail].
extension RightsHolderDetailPatterns on RightsHolderDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RightsHolderDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RightsHolderDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RightsHolderDetail value)  $default,){
final _that = this;
switch (_that) {
case _RightsHolderDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RightsHolderDetail value)?  $default,){
final _that = this;
switch (_that) {
case _RightsHolderDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RightsHolderCarriage> carriages,  List<NamedRef> competitions,  int id,  String? logo,  String name, @JsonKey(name: 'sort_order')  int? sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RightsHolderDetail() when $default != null:
return $default(_that.carriages,_that.competitions,_that.id,_that.logo,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RightsHolderCarriage> carriages,  List<NamedRef> competitions,  int id,  String? logo,  String name, @JsonKey(name: 'sort_order')  int? sortOrder)  $default,) {final _that = this;
switch (_that) {
case _RightsHolderDetail():
return $default(_that.carriages,_that.competitions,_that.id,_that.logo,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RightsHolderCarriage> carriages,  List<NamedRef> competitions,  int id,  String? logo,  String name, @JsonKey(name: 'sort_order')  int? sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _RightsHolderDetail() when $default != null:
return $default(_that.carriages,_that.competitions,_that.id,_that.logo,_that.name,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RightsHolderDetail implements RightsHolderDetail {
  const _RightsHolderDetail({required  List<RightsHolderCarriage> carriages, required  List<NamedRef> competitions, required this.id, required this.logo, required this.name, @JsonKey(name: 'sort_order') required this.sortOrder}): _carriages = carriages,_competitions = competitions;
  factory _RightsHolderDetail.fromJson(Map<String, dynamic> json) => _$RightsHolderDetailFromJson(json);

 final  List<RightsHolderCarriage> _carriages;
@override List<RightsHolderCarriage> get carriages {
  if (_carriages is EqualUnmodifiableListView) return _carriages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_carriages);
}

 final  List<NamedRef> _competitions;
@override List<NamedRef> get competitions {
  if (_competitions is EqualUnmodifiableListView) return _competitions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_competitions);
}

@override final  int id;
@override final  String? logo;
@override final  String name;
@override@JsonKey(name: 'sort_order') final  int? sortOrder;

/// Create a copy of RightsHolderDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RightsHolderDetailCopyWith<_RightsHolderDetail> get copyWith => __$RightsHolderDetailCopyWithImpl<_RightsHolderDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RightsHolderDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RightsHolderDetail&&const DeepCollectionEquality().equals(other.carriages, _carriages)&&const DeepCollectionEquality().equals(other.competitions, _competitions)&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_carriages),const DeepCollectionEquality().hash(_competitions),id,logo,name,sortOrder);
}

@override
String toString() {
    return 'RightsHolderDetail(carriages: $carriages, competitions: $competitions, id: $id, logo: $logo, name: $name, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$RightsHolderDetailCopyWith<$Res> implements $RightsHolderDetailCopyWith<$Res> {
  factory _$RightsHolderDetailCopyWith(_RightsHolderDetail value, $Res Function(_RightsHolderDetail) _then) = __$RightsHolderDetailCopyWithImpl;
@override @useResult
$Res call({
 List<RightsHolderCarriage> carriages, List<NamedRef> competitions, int id, String? logo, String name,@JsonKey(name: 'sort_order') int? sortOrder
});




}
/// @nodoc
class __$RightsHolderDetailCopyWithImpl<$Res>
    implements _$RightsHolderDetailCopyWith<$Res> {
  __$RightsHolderDetailCopyWithImpl(this._self, this._then);

  final _RightsHolderDetail _self;
  final $Res Function(_RightsHolderDetail) _then;

/// Create a copy of RightsHolderDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? carriages = null,Object? competitions = null,Object? id = null,Object? logo = freezed,Object? name = null,Object? sortOrder = freezed,}) {
  return _then(_RightsHolderDetail(
carriages: null == carriages ? _self._carriages : carriages // ignore: cast_nullable_to_non_nullable
as List<RightsHolderCarriage>,competitions: null == competitions ? _self._competitions : competitions // ignore: cast_nullable_to_non_nullable
as List<NamedRef>,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: freezed == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
