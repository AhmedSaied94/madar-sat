// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'competition_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CompetitionDetail {

 int get id; String? get logo; String get name; int? get priority;@JsonKey(name: 'rights_holders') List<NamedRef> get rightsHolders; Sport get sport;
/// Create a copy of CompetitionDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompetitionDetailCopyWith<CompetitionDetail> get copyWith => _$CompetitionDetailCopyWithImpl<CompetitionDetail>(this as CompetitionDetail, _$identity);

  /// Serializes this CompetitionDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CompetitionDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompetitionDetail&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&const DeepCollectionEquality().equals(other.rightsHolders, _this.rightsHolders)&&(identical(other.sport, _this.sport) || other.sport == _this.sport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CompetitionDetail;
  return Object.hash(runtimeType,_this.id,_this.logo,_this.name,_this.priority,const DeepCollectionEquality().hash(_this.rightsHolders),_this.sport);
}

@override
String toString() {
  final _this = this as CompetitionDetail;
  return 'CompetitionDetail(id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, priority: ${_this.priority}, rightsHolders: ${_this.rightsHolders}, sport: ${_this.sport})';
}


}

/// @nodoc
abstract mixin class $CompetitionDetailCopyWith<$Res>  {
  factory $CompetitionDetailCopyWith(CompetitionDetail value, $Res Function(CompetitionDetail) _then) = _$CompetitionDetailCopyWithImpl;
@useResult
$Res call({
 int id, String? logo, String name, int? priority,@JsonKey(name: 'rights_holders') List<NamedRef> rightsHolders, Sport sport
});




}
/// @nodoc
class _$CompetitionDetailCopyWithImpl<$Res>
    implements $CompetitionDetailCopyWith<$Res> {
  _$CompetitionDetailCopyWithImpl(this._self, this._then);

  final CompetitionDetail _self;
  final $Res Function(CompetitionDetail) _then;

/// Create a copy of CompetitionDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? logo = freezed,Object? name = null,Object? priority = freezed,Object? rightsHolders = null,Object? sport = null,}) {
  return _then(CompetitionDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int?,rightsHolders: null == rightsHolders ? _self.rightsHolders : rightsHolders // ignore: cast_nullable_to_non_nullable
as List<NamedRef>,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,
  ));
}

}


/// Adds pattern-matching-related methods to [CompetitionDetail].
extension CompetitionDetailPatterns on CompetitionDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompetitionDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompetitionDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompetitionDetail value)  $default,){
final _that = this;
switch (_that) {
case _CompetitionDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompetitionDetail value)?  $default,){
final _that = this;
switch (_that) {
case _CompetitionDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? logo,  String name,  int? priority, @JsonKey(name: 'rights_holders')  List<NamedRef> rightsHolders,  Sport sport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompetitionDetail() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.rightsHolders,_that.sport);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? logo,  String name,  int? priority, @JsonKey(name: 'rights_holders')  List<NamedRef> rightsHolders,  Sport sport)  $default,) {final _that = this;
switch (_that) {
case _CompetitionDetail():
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.rightsHolders,_that.sport);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? logo,  String name,  int? priority, @JsonKey(name: 'rights_holders')  List<NamedRef> rightsHolders,  Sport sport)?  $default,) {final _that = this;
switch (_that) {
case _CompetitionDetail() when $default != null:
return $default(_that.id,_that.logo,_that.name,_that.priority,_that.rightsHolders,_that.sport);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompetitionDetail implements CompetitionDetail {
  const _CompetitionDetail({required this.id, required this.logo, required this.name, required this.priority, @JsonKey(name: 'rights_holders') required  List<NamedRef> rightsHolders, required this.sport}): _rightsHolders = rightsHolders;
  factory _CompetitionDetail.fromJson(Map<String, dynamic> json) => _$CompetitionDetailFromJson(json);

@override final  int id;
@override final  String? logo;
@override final  String name;
@override final  int? priority;
 final  List<NamedRef> _rightsHolders;
@override@JsonKey(name: 'rights_holders') List<NamedRef> get rightsHolders {
  if (_rightsHolders is EqualUnmodifiableListView) return _rightsHolders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rightsHolders);
}

@override final  Sport sport;

/// Create a copy of CompetitionDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompetitionDetailCopyWith<_CompetitionDetail> get copyWith => __$CompetitionDetailCopyWithImpl<_CompetitionDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompetitionDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompetitionDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.rightsHolders, _rightsHolders)&&(identical(other.sport, sport) || other.sport == sport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,logo,name,priority,const DeepCollectionEquality().hash(_rightsHolders),sport);
}

@override
String toString() {
    return 'CompetitionDetail(id: $id, logo: $logo, name: $name, priority: $priority, rightsHolders: $rightsHolders, sport: $sport)';
}


}

/// @nodoc
abstract mixin class _$CompetitionDetailCopyWith<$Res> implements $CompetitionDetailCopyWith<$Res> {
  factory _$CompetitionDetailCopyWith(_CompetitionDetail value, $Res Function(_CompetitionDetail) _then) = __$CompetitionDetailCopyWithImpl;
@override @useResult
$Res call({
 int id, String? logo, String name, int? priority,@JsonKey(name: 'rights_holders') List<NamedRef> rightsHolders, Sport sport
});




}
/// @nodoc
class __$CompetitionDetailCopyWithImpl<$Res>
    implements _$CompetitionDetailCopyWith<$Res> {
  __$CompetitionDetailCopyWithImpl(this._self, this._then);

  final _CompetitionDetail _self;
  final $Res Function(_CompetitionDetail) _then;

/// Create a copy of CompetitionDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? logo = freezed,Object? name = null,Object? priority = freezed,Object? rightsHolders = null,Object? sport = null,}) {
  return _then(_CompetitionDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int?,rightsHolders: null == rightsHolders ? _self._rightsHolders : rightsHolders // ignore: cast_nullable_to_non_nullable
as List<NamedRef>,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,
  ));
}


}

// dart format on
