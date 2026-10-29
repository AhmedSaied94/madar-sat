// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamDetail {

 List<NamedRef> get competitions; String? get country; int get id; String? get logo; String get name;@JsonKey(name: 'primary_competition') PrimaryCompetitionRef? get primaryCompetition; List<MatchSummary> get recent; Sport get sport; String? get stadium; List<MatchSummary> get upcoming;
/// Create a copy of TeamDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamDetailCopyWith<TeamDetail> get copyWith => _$TeamDetailCopyWithImpl<TeamDetail>(this as TeamDetail, _$identity);

  /// Serializes this TeamDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamDetail&&const DeepCollectionEquality().equals(other.competitions, _this.competitions)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.primaryCompetition, _this.primaryCompetition) || other.primaryCompetition == _this.primaryCompetition)&&const DeepCollectionEquality().equals(other.recent, _this.recent)&&(identical(other.sport, _this.sport) || other.sport == _this.sport)&&(identical(other.stadium, _this.stadium) || other.stadium == _this.stadium)&&const DeepCollectionEquality().equals(other.upcoming, _this.upcoming));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamDetail;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.competitions),_this.country,_this.id,_this.logo,_this.name,_this.primaryCompetition,const DeepCollectionEquality().hash(_this.recent),_this.sport,_this.stadium,const DeepCollectionEquality().hash(_this.upcoming));
}

@override
String toString() {
  final _this = this as TeamDetail;
  return 'TeamDetail(competitions: ${_this.competitions}, country: ${_this.country}, id: ${_this.id}, logo: ${_this.logo}, name: ${_this.name}, primaryCompetition: ${_this.primaryCompetition}, recent: ${_this.recent}, sport: ${_this.sport}, stadium: ${_this.stadium}, upcoming: ${_this.upcoming})';
}


}

/// @nodoc
abstract mixin class $TeamDetailCopyWith<$Res>  {
  factory $TeamDetailCopyWith(TeamDetail value, $Res Function(TeamDetail) _then) = _$TeamDetailCopyWithImpl;
@useResult
$Res call({
 List<NamedRef> competitions, String? country, int id, String? logo, String name,@JsonKey(name: 'primary_competition') PrimaryCompetitionRef? primaryCompetition, List<MatchSummary> recent, Sport sport, String? stadium, List<MatchSummary> upcoming
});


$PrimaryCompetitionRefCopyWith<$Res>? get primaryCompetition;

}
/// @nodoc
class _$TeamDetailCopyWithImpl<$Res>
    implements $TeamDetailCopyWith<$Res> {
  _$TeamDetailCopyWithImpl(this._self, this._then);

  final TeamDetail _self;
  final $Res Function(TeamDetail) _then;

/// Create a copy of TeamDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? competitions = null,Object? country = freezed,Object? id = null,Object? logo = freezed,Object? name = null,Object? primaryCompetition = freezed,Object? recent = null,Object? sport = null,Object? stadium = freezed,Object? upcoming = null,}) {
  return _then(TeamDetail(
competitions: null == competitions ? _self.competitions : competitions // ignore: cast_nullable_to_non_nullable
as List<NamedRef>,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,primaryCompetition: freezed == primaryCompetition ? _self.primaryCompetition : primaryCompetition // ignore: cast_nullable_to_non_nullable
as PrimaryCompetitionRef?,recent: null == recent ? _self.recent : recent // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,stadium: freezed == stadium ? _self.stadium : stadium // ignore: cast_nullable_to_non_nullable
as String?,upcoming: null == upcoming ? _self.upcoming : upcoming // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,
  ));
}
/// Create a copy of TeamDetail
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


/// Adds pattern-matching-related methods to [TeamDetail].
extension TeamDetailPatterns on TeamDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamDetail value)  $default,){
final _that = this;
switch (_that) {
case _TeamDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamDetail value)?  $default,){
final _that = this;
switch (_that) {
case _TeamDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<NamedRef> competitions,  String? country,  int id,  String? logo,  String name, @JsonKey(name: 'primary_competition')  PrimaryCompetitionRef? primaryCompetition,  List<MatchSummary> recent,  Sport sport,  String? stadium,  List<MatchSummary> upcoming)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamDetail() when $default != null:
return $default(_that.competitions,_that.country,_that.id,_that.logo,_that.name,_that.primaryCompetition,_that.recent,_that.sport,_that.stadium,_that.upcoming);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<NamedRef> competitions,  String? country,  int id,  String? logo,  String name, @JsonKey(name: 'primary_competition')  PrimaryCompetitionRef? primaryCompetition,  List<MatchSummary> recent,  Sport sport,  String? stadium,  List<MatchSummary> upcoming)  $default,) {final _that = this;
switch (_that) {
case _TeamDetail():
return $default(_that.competitions,_that.country,_that.id,_that.logo,_that.name,_that.primaryCompetition,_that.recent,_that.sport,_that.stadium,_that.upcoming);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<NamedRef> competitions,  String? country,  int id,  String? logo,  String name, @JsonKey(name: 'primary_competition')  PrimaryCompetitionRef? primaryCompetition,  List<MatchSummary> recent,  Sport sport,  String? stadium,  List<MatchSummary> upcoming)?  $default,) {final _that = this;
switch (_that) {
case _TeamDetail() when $default != null:
return $default(_that.competitions,_that.country,_that.id,_that.logo,_that.name,_that.primaryCompetition,_that.recent,_that.sport,_that.stadium,_that.upcoming);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamDetail implements TeamDetail {
  const _TeamDetail({required  List<NamedRef> competitions, required this.country, required this.id, required this.logo, required this.name, @JsonKey(name: 'primary_competition') required this.primaryCompetition, required  List<MatchSummary> recent, required this.sport, required this.stadium, required  List<MatchSummary> upcoming}): _competitions = competitions,_recent = recent,_upcoming = upcoming;
  factory _TeamDetail.fromJson(Map<String, dynamic> json) => _$TeamDetailFromJson(json);

 final  List<NamedRef> _competitions;
@override List<NamedRef> get competitions {
  if (_competitions is EqualUnmodifiableListView) return _competitions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_competitions);
}

@override final  String? country;
@override final  int id;
@override final  String? logo;
@override final  String name;
@override@JsonKey(name: 'primary_competition') final  PrimaryCompetitionRef? primaryCompetition;
 final  List<MatchSummary> _recent;
@override List<MatchSummary> get recent {
  if (_recent is EqualUnmodifiableListView) return _recent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recent);
}

@override final  Sport sport;
@override final  String? stadium;
 final  List<MatchSummary> _upcoming;
@override List<MatchSummary> get upcoming {
  if (_upcoming is EqualUnmodifiableListView) return _upcoming;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_upcoming);
}


/// Create a copy of TeamDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamDetailCopyWith<_TeamDetail> get copyWith => __$TeamDetailCopyWithImpl<_TeamDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamDetail&&const DeepCollectionEquality().equals(other.competitions, _competitions)&&(identical(other.country, country) || other.country == country)&&(identical(other.id, id) || other.id == id)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.primaryCompetition, primaryCompetition) || other.primaryCompetition == primaryCompetition)&&const DeepCollectionEquality().equals(other.recent, _recent)&&(identical(other.sport, sport) || other.sport == sport)&&(identical(other.stadium, stadium) || other.stadium == stadium)&&const DeepCollectionEquality().equals(other.upcoming, _upcoming));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_competitions),country,id,logo,name,primaryCompetition,const DeepCollectionEquality().hash(_recent),sport,stadium,const DeepCollectionEquality().hash(_upcoming));
}

@override
String toString() {
    return 'TeamDetail(competitions: $competitions, country: $country, id: $id, logo: $logo, name: $name, primaryCompetition: $primaryCompetition, recent: $recent, sport: $sport, stadium: $stadium, upcoming: $upcoming)';
}


}

/// @nodoc
abstract mixin class _$TeamDetailCopyWith<$Res> implements $TeamDetailCopyWith<$Res> {
  factory _$TeamDetailCopyWith(_TeamDetail value, $Res Function(_TeamDetail) _then) = __$TeamDetailCopyWithImpl;
@override @useResult
$Res call({
 List<NamedRef> competitions, String? country, int id, String? logo, String name,@JsonKey(name: 'primary_competition') PrimaryCompetitionRef? primaryCompetition, List<MatchSummary> recent, Sport sport, String? stadium, List<MatchSummary> upcoming
});


@override $PrimaryCompetitionRefCopyWith<$Res>? get primaryCompetition;

}
/// @nodoc
class __$TeamDetailCopyWithImpl<$Res>
    implements _$TeamDetailCopyWith<$Res> {
  __$TeamDetailCopyWithImpl(this._self, this._then);

  final _TeamDetail _self;
  final $Res Function(_TeamDetail) _then;

/// Create a copy of TeamDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? competitions = null,Object? country = freezed,Object? id = null,Object? logo = freezed,Object? name = null,Object? primaryCompetition = freezed,Object? recent = null,Object? sport = null,Object? stadium = freezed,Object? upcoming = null,}) {
  return _then(_TeamDetail(
competitions: null == competitions ? _self._competitions : competitions // ignore: cast_nullable_to_non_nullable
as List<NamedRef>,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,primaryCompetition: freezed == primaryCompetition ? _self.primaryCompetition : primaryCompetition // ignore: cast_nullable_to_non_nullable
as PrimaryCompetitionRef?,recent: null == recent ? _self._recent : recent // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,sport: null == sport ? _self.sport : sport // ignore: cast_nullable_to_non_nullable
as Sport,stadium: freezed == stadium ? _self.stadium : stadium // ignore: cast_nullable_to_non_nullable
as String?,upcoming: null == upcoming ? _self._upcoming : upcoming // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,
  ));
}

/// Create a copy of TeamDetail
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
