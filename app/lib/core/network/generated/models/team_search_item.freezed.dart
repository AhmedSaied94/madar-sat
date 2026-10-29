// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_search_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamSearchItem {

 String? get country; int get id; String? get logo; String get name;@JsonKey(name: 'primary_competition') PrimaryCompetitionRef? get primaryCompetition; Sport get sport;
/// Create a copy of TeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamSearchItemCopyWith<TeamSearchItem> get copyWith => _$TeamSearchItemCopyWithImpl<TeamSearchItem>(this as TeamSearchItem, _$identity);

  /// Serializes this TeamSearchItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamSearchItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamSearchItem&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.primaryCompetition, _this.primaryCompetition) || other.primaryCompetition == _this.primaryCompetition)&&(identical(other.sport, _this.sport) || other.sport == _this.sport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamSearchItem;
  return Object.hash(runtimeType,_this.country,_this.id,_this.logo,_this.name,_this.primaryCompetition,_this.sport);
}

@override
String toString() {
  final _this = this as TeamSearchItem;
  return 'TeamSearchItem(country: ${_this.country}, id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, primaryCompetition: ${_this.primaryCompetition}, sport: ${_this.sport})';
}


}

/// @nodoc
abstract mixin class $TeamSearchItemCopyWith<$Res>  {
  factory $TeamSearchItemCopyWith(TeamSearchItem value, $Res Function(TeamSearchItem) _then) = _$TeamSearchItemCopyWithImpl;
@useResult
$Res call({
 String? country, int id, String? logo, String name,@JsonKey(name: 'primary_competition') PrimaryCompetitionRef? primaryCompetition, Sport sport
});


$PrimaryCompetitionRefCopyWith<$Res>? get primaryCompetition;

}
/// @nodoc
class _$TeamSearchItemCopyWithImpl<$Res>
    implements $TeamSearchItemCopyWith<$Res> {
  _$TeamSearchItemCopyWithImpl(this._self, this._then);

  final TeamSearchItem _self;
  final $Res Function(TeamSearchItem) _then;

/// Create a copy of TeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? country = freezed,Object? id = null,Object? logo = freezed,Object? name = null,Object? primaryCompetition = freezed,Object? sport = null,}) {
  return _then(TeamSearchItem(
country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,primaryCompetition: freezed == primaryCompetition ? _self.primaryCompetition : primaryCompetition // ignore: cast_nullable_to_non_nullable
as PrimaryCompetitionRef?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,
  ));
}
/// Create a copy of TeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PrimaryCompetitionRefCopyWith<$Res>? get primaryCompetition {
    if (_self.primaryCompetition == null) {
    return null;
  }

  return $PrimaryCompetitionRefCopyWith<$Res>(_self.primaryCompetition!, (value) {
    return _then(_self.copyWith(primaryCompetition: value));
  });
}
}


/// Adds pattern-matching-related methods to [TeamSearchItem].
extension TeamSearchItemPatterns on TeamSearchItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamSearchItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamSearchItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamSearchItem value)  $default,){
final _that = this;
switch (_that) {
case _TeamSearchItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamSearchItem value)?  $default,){
final _that = this;
switch (_that) {
case _TeamSearchItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? country,  int id,  String? logo,  String name, @JsonKey(name: 'primary_competition')  PrimaryCompetitionRef? primaryCompetition,  Sport sport)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamSearchItem() when $default != null:
return $default(_that.country,_that.id,_that.logo,_that.name,_that.primaryCompetition,_that.sport);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? country,  int id,  String? logo,  String name, @JsonKey(name: 'primary_competition')  PrimaryCompetitionRef? primaryCompetition,  Sport sport)  $default,) {final _that = this;
switch (_that) {
case _TeamSearchItem():
return $default(_that.country,_that.id,_that.logo,_that.name,_that.primaryCompetition,_that.sport);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? country,  int id,  String? logo,  String name, @JsonKey(name: 'primary_competition')  PrimaryCompetitionRef? primaryCompetition,  Sport sport)?  $default,) {final _that = this;
switch (_that) {
case _TeamSearchItem() when $default != null:
return $default(_that.country,_that.id,_that.logo,_that.name,_that.primaryCompetition,_that.sport);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamSearchItem implements TeamSearchItem {
  const _TeamSearchItem({required this.country, required this.id, required this.logo, required this.name, @JsonKey(name: 'primary_competition') required this.primaryCompetition, required this.sport});
  factory _TeamSearchItem.fromJson(Map<String, dynamic> json) => _$TeamSearchItemFromJson(json);

@override final  String? country;
@override final  int id;
@override final  String? logo;
@override final  String name;
@override@JsonKey(name: 'primary_competition') final  PrimaryCompetitionRef? primaryCompetition;
@override final  Sport sport;

/// Create a copy of TeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamSearchItemCopyWith<_TeamSearchItem> get copyWith => __$TeamSearchItemCopyWithImpl<_TeamSearchItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamSearchItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamSearchItem&&(identical(other.country, country) || other.country == country)&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.primaryCompetition, primaryCompetition) || other.primaryCompetition == primaryCompetition)&&(identical(other.sport, sport) || other.sport == sport));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,country,id,logo,name,primaryCompetition,sport);
}

@override
String toString() {
    return 'TeamSearchItem(country: $country, id: $id, logo: $logo, name: $name, primaryCompetition: $primaryCompetition, sport: $sport)';
}


}

/// @nodoc
abstract mixin class _$TeamSearchItemCopyWith<$Res> implements $TeamSearchItemCopyWith<$Res> {
  factory _$TeamSearchItemCopyWith(_TeamSearchItem value, $Res Function(_TeamSearchItem) _then) = __$TeamSearchItemCopyWithImpl;
@override @useResult
$Res call({
 String? country, int id, String? logo, String name,@JsonKey(name: 'primary_competition') PrimaryCompetitionRef? primaryCompetition, Sport sport
});


@override $PrimaryCompetitionRefCopyWith<$Res>? get primaryCompetition;

}
/// @nodoc
class __$TeamSearchItemCopyWithImpl<$Res>
    implements _$TeamSearchItemCopyWith<$Res> {
  __$TeamSearchItemCopyWithImpl(this._self, this._then);

  final _TeamSearchItem _self;
  final $Res Function(_TeamSearchItem) _then;

/// Create a copy of TeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? country = freezed,Object? id = null,Object? logo = freezed,Object? name = null,Object? primaryCompetition = freezed,Object? sport = null,}) {
  return _then(_TeamSearchItem(
country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,primaryCompetition: freezed == primaryCompetition ? _self.primaryCompetition : primaryCompetition // ignore: cast_nullable_to_non_nullable
as PrimaryCompetitionRef?,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,
  ));
}

/// Create a copy of TeamSearchItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PrimaryCompetitionRefCopyWith<$Res>? get primaryCompetition {
    if (_self.primaryCompetition == null) {
    return null;
  }

  return $PrimaryCompetitionRefCopyWith<$Res>(_self.primaryCompetition!, (value) {
    return _then(_self.copyWith(primaryCompetition: value));
  });
}
}

// dart format on
