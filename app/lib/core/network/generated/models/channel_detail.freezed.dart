// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChannelDetail {

 Access? get access; Beam? get beam; Category? get category; String? get country;@JsonKey(name: 'display_name') String? get displayName; Frequency? get frequency;@JsonKey(name: 'frequency_changed_at') DateTime? get frequencyChangedAt;@JsonKey(name: 'frequency_note') String? get frequencyNote; int get id; Kind get kind; String? get logo; String get name;@JsonKey(name: 'other_carriages') List<ChannelCarriage> get otherCarriages; String? get package; String? get provider;@JsonKey(name: 'recent_frequency_changes') List<dynamic> get recentFrequencyChanges; SatelliteRef? get satellite;@JsonKey(name: 'upcoming_matches') List<MatchSummary> get upcomingMatches;
/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelDetailCopyWith<ChannelDetail> get copyWith => _$ChannelDetailCopyWithImpl<ChannelDetail>(this as ChannelDetail, _$identity);

  /// Serializes this ChannelDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChannelDetail;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelDetail&&(identical(other.access, _this.access) || other.access == _this.access)&&(identical(other.beam, _this.beam) || other.beam == _this.beam)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.frequency, _this.frequency) || other.frequency == _this.frequency)&&(identical(other.frequencyChangedAt, _this.frequencyChangedAt) || other.frequencyChangedAt == _this.frequencyChangedAt)&&(identical(other.frequencyNote, _this.frequencyNote) || other.frequencyNote == _this.frequencyNote)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.otherCarriages, _this.otherCarriages)&&(identical(other.package, _this.package) || other.package == _this.package)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&const DeepCollectionEquality().equals(other.recentFrequencyChanges, _this.recentFrequencyChanges)&&(identical(other.satellite, _this.satellite) || other.satellite == _this.satellite)&&const DeepCollectionEquality().equals(other.upcomingMatches, _this.upcomingMatches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChannelDetail;
  return Object.hash(runtimeType,_this.access,_this.beam,_this.category,_this.country,_this.displayName,_this.frequency,_this.frequencyChangedAt,_this.frequencyNote,_this.id,_this.kind,_this.logo,_this.name,const DeepCollectionEquality().hash(_this.otherCarriages),_this.package,_this.provider,const DeepCollectionEquality().hash(_this.recentFrequencyChanges),_this.satellite,const DeepCollectionEquality().hash(_this.upcomingMatches));
}

@override
String toString() {
  final _this = this as ChannelDetail;
  return 'ChannelDetail(access: ${_this.access}, beam: ${_this.beam}, category: ${_this.category}, country: ${_this.country}, displayName: ${_this.displayName}, frequency: ${_this.frequency}, frequencyChangedAt: ${_this.frequencyChangedAt}, frequencyNote: ${_this.frequencyNote}, id: ${_this.id}, kind: ${_this.kind}, logo: ${_this.logo}, name: ${_this.name}, otherCarriages: ${_this.otherCarriages}, package: ${_this.package}, provider: ${_this.provider}, recentFrequencyChanges: ${_this.recentFrequencyChanges}, satellite: ${_this.satellite}, upcomingMatches: ${_this.upcomingMatches})';
}


}

/// @nodoc
abstract mixin class $ChannelDetailCopyWith<$Res>  {
  factory $ChannelDetailCopyWith(ChannelDetail value, $Res Function(ChannelDetail) _then) = _$ChannelDetailCopyWithImpl;
@useResult
$Res call({
 Access? access, Beam? beam, Category? category, String? country,@JsonKey(name: 'display_name') String? displayName, Frequency? frequency,@JsonKey(name: 'frequency_changed_at') DateTime? frequencyChangedAt,@JsonKey(name: 'frequency_note') String? frequencyNote, int id, Kind kind, String? logo, String name,@JsonKey(name: 'other_carriages') List<ChannelCarriage> otherCarriages, String? package, String? provider,@JsonKey(name: 'recent_frequency_changes') List<dynamic> recentFrequencyChanges, SatelliteRef? satellite,@JsonKey(name: 'upcoming_matches') List<MatchSummary> upcomingMatches
});


$FrequencyCopyWith<$Res>? get frequency;$SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class _$ChannelDetailCopyWithImpl<$Res>
    implements $ChannelDetailCopyWith<$Res> {
  _$ChannelDetailCopyWithImpl(this._self, this._then);

  final ChannelDetail _self;
  final $Res Function(ChannelDetail) _then;

/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? access = freezed,Object? beam = freezed,Object? category = freezed,Object? country = freezed,Object? displayName = freezed,Object? frequency = freezed,Object? frequencyChangedAt = freezed,Object? frequencyNote = freezed,Object? id = null,Object? kind = null,Object? logo = freezed,Object? name = null,Object? otherCarriages = null,Object? package = freezed,Object? provider = freezed,Object? recentFrequencyChanges = null,Object? satellite = freezed,Object? upcomingMatches = null,}) {
  return _then(ChannelDetail(
access: freezed == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access?,beam: freezed == beam ? _self.beam : beam // ignore: cast_nullable_to_non_nullable
as Beam?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,frequency: freezed == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency?,frequencyChangedAt: freezed == frequencyChangedAt ? _self.frequencyChangedAt : frequencyChangedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,frequencyNote: freezed == frequencyNote ? _self.frequencyNote : frequencyNote // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as Kind,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,otherCarriages: null == otherCarriages ? _self.otherCarriages : otherCarriages // ignore: cast_nullable_to_non_nullable
as List<ChannelCarriage>,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,recentFrequencyChanges: null == recentFrequencyChanges ? _self.recentFrequencyChanges : recentFrequencyChanges // ignore: cast_nullable_to_non_nullable
as List<dynamic>,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,upcomingMatches: null == upcomingMatches ? _self.upcomingMatches : upcomingMatches // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,
  ));
}
/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyCopyWith<$Res>? get frequency {
    if (_self.frequency == null) {
    return null;
  }

  return $FrequencyCopyWith<$Res>(_self.frequency!, (value) {
    return _then(_self.copyWith(frequency: value));
  });
}/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SatelliteRefCopyWith<$Res>? get satellite {
    if (_self.satellite == null) {
    return null;
  }

  return $SatelliteRefCopyWith<$Res>(_self.satellite!, (value) {
    return _then(_self.copyWith(satellite: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChannelDetail].
extension ChannelDetailPatterns on ChannelDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChannelDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChannelDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChannelDetail value)  $default,){
final _that = this;
switch (_that) {
case _ChannelDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChannelDetail value)?  $default,){
final _that = this;
switch (_that) {
case _ChannelDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Access? access,  Beam? beam,  Category? category,  String? country, @JsonKey(name: 'display_name')  String? displayName,  Frequency? frequency, @JsonKey(name: 'frequency_changed_at')  DateTime? frequencyChangedAt, @JsonKey(name: 'frequency_note')  String? frequencyNote,  int id,  Kind kind,  String? logo,  String name, @JsonKey(name: 'other_carriages')  List<ChannelCarriage> otherCarriages,  String? package,  String? provider, @JsonKey(name: 'recent_frequency_changes')  List<dynamic> recentFrequencyChanges,  SatelliteRef? satellite, @JsonKey(name: 'upcoming_matches')  List<MatchSummary> upcomingMatches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChannelDetail() when $default != null:
return $default(_that.access,_that.beam,_that.category,_that.country,_that.displayName,_that.frequency,_that.frequencyChangedAt,_that.frequencyNote,_that.id,_that.kind,_that.logo,_that.name,_that.otherCarriages,_that.package,_that.provider,_that.recentFrequencyChanges,_that.satellite,_that.upcomingMatches);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Access? access,  Beam? beam,  Category? category,  String? country, @JsonKey(name: 'display_name')  String? displayName,  Frequency? frequency, @JsonKey(name: 'frequency_changed_at')  DateTime? frequencyChangedAt, @JsonKey(name: 'frequency_note')  String? frequencyNote,  int id,  Kind kind,  String? logo,  String name, @JsonKey(name: 'other_carriages')  List<ChannelCarriage> otherCarriages,  String? package,  String? provider, @JsonKey(name: 'recent_frequency_changes')  List<dynamic> recentFrequencyChanges,  SatelliteRef? satellite, @JsonKey(name: 'upcoming_matches')  List<MatchSummary> upcomingMatches)  $default,) {final _that = this;
switch (_that) {
case _ChannelDetail():
return $default(_that.access,_that.beam,_that.category,_that.country,_that.displayName,_that.frequency,_that.frequencyChangedAt,_that.frequencyNote,_that.id,_that.kind,_that.logo,_that.name,_that.otherCarriages,_that.package,_that.provider,_that.recentFrequencyChanges,_that.satellite,_that.upcomingMatches);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Access? access,  Beam? beam,  Category? category,  String? country, @JsonKey(name: 'display_name')  String? displayName,  Frequency? frequency, @JsonKey(name: 'frequency_changed_at')  DateTime? frequencyChangedAt, @JsonKey(name: 'frequency_note')  String? frequencyNote,  int id,  Kind kind,  String? logo,  String name, @JsonKey(name: 'other_carriages')  List<ChannelCarriage> otherCarriages,  String? package,  String? provider, @JsonKey(name: 'recent_frequency_changes')  List<dynamic> recentFrequencyChanges,  SatelliteRef? satellite, @JsonKey(name: 'upcoming_matches')  List<MatchSummary> upcomingMatches)?  $default,) {final _that = this;
switch (_that) {
case _ChannelDetail() when $default != null:
return $default(_that.access,_that.beam,_that.category,_that.country,_that.displayName,_that.frequency,_that.frequencyChangedAt,_that.frequencyNote,_that.id,_that.kind,_that.logo,_that.name,_that.otherCarriages,_that.package,_that.provider,_that.recentFrequencyChanges,_that.satellite,_that.upcomingMatches);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChannelDetail implements ChannelDetail {
  const _ChannelDetail({required this.access, required this.beam, required this.category, required this.country, @JsonKey(name: 'display_name') required this.displayName, required this.frequency, @JsonKey(name: 'frequency_changed_at') required this.frequencyChangedAt, @JsonKey(name: 'frequency_note') required this.frequencyNote, required this.id, required this.kind, required this.logo, required this.name, @JsonKey(name: 'other_carriages') required  List<ChannelCarriage> otherCarriages, required this.package, required this.provider, @JsonKey(name: 'recent_frequency_changes') required  List<dynamic> recentFrequencyChanges, required this.satellite, @JsonKey(name: 'upcoming_matches') required  List<MatchSummary> upcomingMatches}): _otherCarriages = otherCarriages,_recentFrequencyChanges = recentFrequencyChanges,_upcomingMatches = upcomingMatches;
  factory _ChannelDetail.fromJson(Map<String, dynamic> json) => _$ChannelDetailFromJson(json);

@override final  Access? access;
@override final  Beam? beam;
@override final  Category? category;
@override final  String? country;
@override@JsonKey(name: 'display_name') final  String? displayName;
@override final  Frequency? frequency;
@override@JsonKey(name: 'frequency_changed_at') final  DateTime? frequencyChangedAt;
@override@JsonKey(name: 'frequency_note') final  String? frequencyNote;
@override final  int id;
@override final  Kind kind;
@override final  String? logo;
@override final  String name;
 final  List<ChannelCarriage> _otherCarriages;
@override@JsonKey(name: 'other_carriages') List<ChannelCarriage> get otherCarriages {
  if (_otherCarriages is EqualUnmodifiableListView) return _otherCarriages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_otherCarriages);
}

@override final  String? package;
@override final  String? provider;
 final  List<dynamic> _recentFrequencyChanges;
@override@JsonKey(name: 'recent_frequency_changes') List<dynamic> get recentFrequencyChanges {
  if (_recentFrequencyChanges is EqualUnmodifiableListView) return _recentFrequencyChanges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentFrequencyChanges);
}

@override final  SatelliteRef? satellite;
 final  List<MatchSummary> _upcomingMatches;
@override@JsonKey(name: 'upcoming_matches') List<MatchSummary> get upcomingMatches {
  if (_upcomingMatches is EqualUnmodifiableListView) return _upcomingMatches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_upcomingMatches);
}


/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelDetailCopyWith<_ChannelDetail> get copyWith => __$ChannelDetailCopyWithImpl<_ChannelDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChannelDetailToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChannelDetail&&(identical(other.access, access) || other.access == access)&&(identical(other.beam, beam) || other.beam == beam)&&(identical(other.category, category) || other.category == category)&&(identical(other.country, country) || other.country == country)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.frequencyChangedAt, frequencyChangedAt) || other.frequencyChangedAt == frequencyChangedAt)&&(identical(other.frequencyNote, frequencyNote) || other.frequencyNote == frequencyNote)&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.otherCarriages, _otherCarriages)&&(identical(other.package, package) || other.package == package)&&(identical(other.provider, provider) || other.provider == provider)&&const DeepCollectionEquality().equals(other.recentFrequencyChanges, _recentFrequencyChanges)&&(identical(other.satellite, satellite) || other.satellite == satellite)&&const DeepCollectionEquality().equals(other.upcomingMatches, _upcomingMatches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,access,beam,category,country,displayName,frequency,frequencyChangedAt,frequencyNote,id,kind,logo,name,const DeepCollectionEquality().hash(_otherCarriages),package,provider,const DeepCollectionEquality().hash(_recentFrequencyChanges),satellite,const DeepCollectionEquality().hash(_upcomingMatches));
}

@override
String toString() {
    return 'ChannelDetail(access: $access, beam: $beam, category: $category, country: $country, displayName: $displayName, frequency: $frequency, frequencyChangedAt: $frequencyChangedAt, frequencyNote: $frequencyNote, id: $id, kind: $kind, logo: $logo, name: $name, otherCarriages: $otherCarriages, package: $package, provider: $provider, recentFrequencyChanges: $recentFrequencyChanges, satellite: $satellite, upcomingMatches: $upcomingMatches)';
}


}

/// @nodoc
abstract mixin class _$ChannelDetailCopyWith<$Res> implements $ChannelDetailCopyWith<$Res> {
  factory _$ChannelDetailCopyWith(_ChannelDetail value, $Res Function(_ChannelDetail) _then) = __$ChannelDetailCopyWithImpl;
@override @useResult
$Res call({
 Access? access, Beam? beam, Category? category, String? country,@JsonKey(name: 'display_name') String? displayName, Frequency? frequency,@JsonKey(name: 'frequency_changed_at') DateTime? frequencyChangedAt,@JsonKey(name: 'frequency_note') String? frequencyNote, int id, Kind kind, String? logo, String name,@JsonKey(name: 'other_carriages') List<ChannelCarriage> otherCarriages, String? package, String? provider,@JsonKey(name: 'recent_frequency_changes') List<dynamic> recentFrequencyChanges, SatelliteRef? satellite,@JsonKey(name: 'upcoming_matches') List<MatchSummary> upcomingMatches
});


@override $FrequencyCopyWith<$Res>? get frequency;@override $SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class __$ChannelDetailCopyWithImpl<$Res>
    implements _$ChannelDetailCopyWith<$Res> {
  __$ChannelDetailCopyWithImpl(this._self, this._then);

  final _ChannelDetail _self;
  final $Res Function(_ChannelDetail) _then;

/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? access = freezed,Object? beam = freezed,Object? category = freezed,Object? country = freezed,Object? displayName = freezed,Object? frequency = freezed,Object? frequencyChangedAt = freezed,Object? frequencyNote = freezed,Object? id = null,Object? kind = null,Object? logo = freezed,Object? name = null,Object? otherCarriages = null,Object? package = freezed,Object? provider = freezed,Object? recentFrequencyChanges = null,Object? satellite = freezed,Object? upcomingMatches = null,}) {
  return _then(_ChannelDetail(
access: freezed == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access?,beam: freezed == beam ? _self.beam : beam // ignore: cast_nullable_to_non_nullable
as Beam?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as Category?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,frequency: freezed == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency?,frequencyChangedAt: freezed == frequencyChangedAt ? _self.frequencyChangedAt : frequencyChangedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,frequencyNote: freezed == frequencyNote ? _self.frequencyNote : frequencyNote // ignore: cast_nullable_to_non_nullable
as String?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as Kind,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,otherCarriages: null == otherCarriages ? _self._otherCarriages : otherCarriages // ignore: cast_nullable_to_non_nullable
as List<ChannelCarriage>,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,recentFrequencyChanges: null == recentFrequencyChanges ? _self._recentFrequencyChanges : recentFrequencyChanges // ignore: cast_nullable_to_non_nullable
as List<dynamic>,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,upcomingMatches: null == upcomingMatches ? _self._upcomingMatches : upcomingMatches // ignore: cast_nullable_to_non_nullable
as List<MatchSummary>,
  ));
}

/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyCopyWith<$Res>? get frequency {
    if (_self.frequency == null) {
    return null;
  }

  return $FrequencyCopyWith<$Res>(_self.frequency!, (value) {
    return _then(_self.copyWith(frequency: value));
  });
}/// Create a copy of ChannelDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SatelliteRefCopyWith<$Res>? get satellite {
    if (_self.satellite == null) {
    return null;
  }

  return $SatelliteRefCopyWith<$Res>(_self.satellite!, (value) {
    return _then(_self.copyWith(satellite: value));
  });
}
}

// dart format on
