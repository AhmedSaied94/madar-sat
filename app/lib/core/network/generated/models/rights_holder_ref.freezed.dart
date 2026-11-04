// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rights_holder_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RightsHolderRef {

@JsonKey(name: 'competition_count') int get competitionCount; int get id; String? get logo; String get name; List<SatelliteRef> get satellites;
/// Create a copy of RightsHolderRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RightsHolderRefCopyWith<RightsHolderRef> get copyWith => _$RightsHolderRefCopyWithImpl<RightsHolderRef>(this as RightsHolderRef, _$identity);

  /// Serializes this RightsHolderRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RightsHolderRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RightsHolderRef&&(identical(other.competitionCount, _this.competitionCount) || other.competitionCount == _this.competitionCount)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.satellites, _this.satellites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RightsHolderRef;
  return Object.hash(runtimeType,_this.competitionCount,_this.id,_this.logo,_this.name,const DeepCollectionEquality().hash(_this.satellites));
}

@override
String toString() {
  final _this = this as RightsHolderRef;
  return 'RightsHolderRef(competitionCount: ${_this.competitionCount}, id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, satellites: ${_this.satellites})';
}


}

/// @nodoc
abstract mixin class $RightsHolderRefCopyWith<$Res>  {
  factory $RightsHolderRefCopyWith(RightsHolderRef value, $Res Function(RightsHolderRef) _then) = _$RightsHolderRefCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'competition_count') int competitionCount, int id, String? logo, String name, List<SatelliteRef> satellites
});




}
/// @nodoc
class _$RightsHolderRefCopyWithImpl<$Res>
    implements $RightsHolderRefCopyWith<$Res> {
  _$RightsHolderRefCopyWithImpl(this._self, this._then);

  final RightsHolderRef _self;
  final $Res Function(RightsHolderRef) _then;

/// Create a copy of RightsHolderRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? competitionCount = null,Object? id = null,Object? logo = freezed,Object? name = null,Object? satellites = null,}) {
  return _then(RightsHolderRef(
competitionCount: null == competitionCount ? _self.competitionCount : competitionCount // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,satellites: null == satellites ? _self.satellites : satellites // ignore: cast_nullable_to_non_nullable
as List<SatelliteRef>,
  ));
}

}


/// Adds pattern-matching-related methods to [RightsHolderRef].
extension RightsHolderRefPatterns on RightsHolderRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RightsHolderRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RightsHolderRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RightsHolderRef value)  $default,){
final _that = this;
switch (_that) {
case _RightsHolderRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RightsHolderRef value)?  $default,){
final _that = this;
switch (_that) {
case _RightsHolderRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'competition_count')  int competitionCount,  int id,  String? logo,  String name,  List<SatelliteRef> satellites)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RightsHolderRef() when $default != null:
return $default(_that.competitionCount,_that.id,_that.logo,_that.name,_that.satellites);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'competition_count')  int competitionCount,  int id,  String? logo,  String name,  List<SatelliteRef> satellites)  $default,) {final _that = this;
switch (_that) {
case _RightsHolderRef():
return $default(_that.competitionCount,_that.id,_that.logo,_that.name,_that.satellites);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'competition_count')  int competitionCount,  int id,  String? logo,  String name,  List<SatelliteRef> satellites)?  $default,) {final _that = this;
switch (_that) {
case _RightsHolderRef() when $default != null:
return $default(_that.competitionCount,_that.id,_that.logo,_that.name,_that.satellites);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RightsHolderRef implements RightsHolderRef {
  const _RightsHolderRef({@JsonKey(name: 'competition_count') required this.competitionCount, required this.id, required this.logo, required this.name, required  List<SatelliteRef> satellites}): _satellites = satellites;
  factory _RightsHolderRef.fromJson(Map<String, dynamic> json) => _$RightsHolderRefFromJson(json);

@override@JsonKey(name: 'competition_count') final  int competitionCount;
@override final  int id;
@override final  String? logo;
@override final  String name;
 final  List<SatelliteRef> _satellites;
@override List<SatelliteRef> get satellites {
  if (_satellites is EqualUnmodifiableListView) return _satellites;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_satellites);
}


/// Create a copy of RightsHolderRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RightsHolderRefCopyWith<_RightsHolderRef> get copyWith => __$RightsHolderRefCopyWithImpl<_RightsHolderRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RightsHolderRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RightsHolderRef&&(identical(other.competitionCount, competitionCount) || other.competitionCount == competitionCount)&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.satellites, _satellites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,competitionCount,id,logo,name,const DeepCollectionEquality().hash(_satellites));
}

@override
String toString() {
    return 'RightsHolderRef(competitionCount: $competitionCount, id: $id, logo: $logo, name: $name, satellites: $satellites)';
}


}

/// @nodoc
abstract mixin class _$RightsHolderRefCopyWith<$Res> implements $RightsHolderRefCopyWith<$Res> {
  factory _$RightsHolderRefCopyWith(_RightsHolderRef value, $Res Function(_RightsHolderRef) _then) = __$RightsHolderRefCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'competition_count') int competitionCount, int id, String? logo, String name, List<SatelliteRef> satellites
});




}
/// @nodoc
class __$RightsHolderRefCopyWithImpl<$Res>
    implements _$RightsHolderRefCopyWith<$Res> {
  __$RightsHolderRefCopyWithImpl(this._self, this._then);

  final _RightsHolderRef _self;
  final $Res Function(_RightsHolderRef) _then;

/// Create a copy of RightsHolderRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? competitionCount = null,Object? id = null,Object? logo = freezed,Object? name = null,Object? satellites = null,}) {
  return _then(_RightsHolderRef(
competitionCount: null == competitionCount ? _self.competitionCount : competitionCount // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,satellites: null == satellites ? _self._satellites : satellites // ignore: cast_nullable_to_non_nullable
as List<SatelliteRef>,
  ));
}


}

// dart format on
