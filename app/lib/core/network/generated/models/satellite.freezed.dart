// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'satellite.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Satellite {

@JsonKey(name: 'best_frequency') Frequency? get bestFrequency;@JsonKey(name: 'channel_count') int get channelCount; int get id; Kind get kind; String? get logo;@JsonKey(name: 'name_ar') String get nameAr;@JsonKey(name: 'name_en') String get nameEn;@JsonKey(name: 'orbital_position') num? get orbitalPosition;@JsonKey(name: 'reception_url') String? get receptionUrl; String get slug;@JsonKey(name: 'worst_frequency') Frequency? get worstFrequency;
/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SatelliteCopyWith<Satellite> get copyWith => _$SatelliteCopyWithImpl<Satellite>(this as Satellite, _$identity);

  /// Serializes this Satellite to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Satellite;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Satellite&&(identical(other.bestFrequency, _this.bestFrequency) || other.bestFrequency == _this.bestFrequency)&&(identical(other.channelCount, _this.channelCount) || other.channelCount == _this.channelCount)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.nameAr, _this.nameAr) || other.nameAr == _this.nameAr)&&(identical(other.nameEn, _this.nameEn) || other.nameEn == _this.nameEn)&&(identical(other.orbitalPosition, _this.orbitalPosition) || other.orbitalPosition == _this.orbitalPosition)&&(identical(other.receptionUrl, _this.receptionUrl) || other.receptionUrl == _this.receptionUrl)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.worstFrequency, _this.worstFrequency) || other.worstFrequency == _this.worstFrequency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Satellite;
  return Object.hash(runtimeType,_this.bestFrequency,_this.channelCount,_this.id,_this.kind,_this.logo,_this.nameAr,_this.nameEn,_this.orbitalPosition,_this.receptionUrl,_this.slug,_this.worstFrequency);
}

@override
String toString() {
  final _this = this as Satellite;
  return 'Satellite(bestFrequency: ${_this.bestFrequency}, channelCount: ${_this.channelCount}, id: ${_this.id}, kind: ${_this.kind}, logo: ${_this.logo}, nameAr: ${_this.nameAr}, nameEn: ${_this.nameEn}, orbitalPosition: ${_this.orbitalPosition}, receptionUrl: ${_this.receptionUrl}, slug: ${_this.slug}, worstFrequency: ${_this.worstFrequency})';
}


}

/// @nodoc
abstract mixin class $SatelliteCopyWith<$Res>  {
  factory $SatelliteCopyWith(Satellite value, $Res Function(Satellite) _then) = _$SatelliteCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'best_frequency') Frequency? bestFrequency,@JsonKey(name: 'channel_count') int channelCount, int id, Kind kind, String? logo,@JsonKey(name: 'name_ar') String nameAr,@JsonKey(name: 'name_en') String nameEn,@JsonKey(name: 'orbital_position') num? orbitalPosition,@JsonKey(name: 'reception_url') String? receptionUrl, String slug,@JsonKey(name: 'worst_frequency') Frequency? worstFrequency
});


$FrequencyCopyWith<$Res>? get bestFrequency;$FrequencyCopyWith<$Res>? get worstFrequency;

}
/// @nodoc
class _$SatelliteCopyWithImpl<$Res>
    implements $SatelliteCopyWith<$Res> {
  _$SatelliteCopyWithImpl(this._self, this._then);

  final Satellite _self;
  final $Res Function(Satellite) _then;

/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bestFrequency = freezed,Object? channelCount = null,Object? id = null,Object? kind = null,Object? logo = freezed,Object? nameAr = null,Object? nameEn = null,Object? orbitalPosition = freezed,Object? receptionUrl = freezed,Object? slug = null,Object? worstFrequency = freezed,}) {
  return _then(Satellite(
bestFrequency: freezed == bestFrequency ? _self.bestFrequency : bestFrequency // ignore: cast_nullable_to_non_nullable
as Frequency?,channelCount: null == channelCount ? _self.channelCount : channelCount // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as Kind,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,orbitalPosition: freezed == orbitalPosition ? _self.orbitalPosition : orbitalPosition // ignore: cast_nullable_to_non_nullable
as num?,receptionUrl: freezed == receptionUrl ? _self.receptionUrl : receptionUrl // ignore: cast_nullable_to_non_nullable
as String?,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,worstFrequency: freezed == worstFrequency ? _self.worstFrequency : worstFrequency // ignore: cast_nullable_to_non_nullable
as Frequency?,
  ));
}
/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyCopyWith<$Res>? get bestFrequency {
    if (_self.bestFrequency == null) {
    return null;
  }

  return $FrequencyCopyWith<$Res>(_self.bestFrequency!, (value) {
    return _then(_self.copyWith(bestFrequency: value));
  });
}/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyCopyWith<$Res>? get worstFrequency {
    if (_self.worstFrequency == null) {
    return null;
  }

  return $FrequencyCopyWith<$Res>(_self.worstFrequency!, (value) {
    return _then(_self.copyWith(worstFrequency: value));
  });
}
}


/// Adds pattern-matching-related methods to [Satellite].
extension SatellitePatterns on Satellite {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Satellite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Satellite() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Satellite value)  $default,){
final _that = this;
switch (_that) {
case _Satellite():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Satellite value)?  $default,){
final _that = this;
switch (_that) {
case _Satellite() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'best_frequency')  Frequency? bestFrequency, @JsonKey(name: 'channel_count')  int channelCount,  int id,  Kind kind,  String? logo, @JsonKey(name: 'name_ar')  String nameAr, @JsonKey(name: 'name_en')  String nameEn, @JsonKey(name: 'orbital_position')  num? orbitalPosition, @JsonKey(name: 'reception_url')  String? receptionUrl,  String slug, @JsonKey(name: 'worst_frequency')  Frequency? worstFrequency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Satellite() when $default != null:
return $default(_that.bestFrequency,_that.channelCount,_that.id,_that.kind,_that.logo,_that.nameAr,_that.nameEn,_that.orbitalPosition,_that.receptionUrl,_that.slug,_that.worstFrequency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'best_frequency')  Frequency? bestFrequency, @JsonKey(name: 'channel_count')  int channelCount,  int id,  Kind kind,  String? logo, @JsonKey(name: 'name_ar')  String nameAr, @JsonKey(name: 'name_en')  String nameEn, @JsonKey(name: 'orbital_position')  num? orbitalPosition, @JsonKey(name: 'reception_url')  String? receptionUrl,  String slug, @JsonKey(name: 'worst_frequency')  Frequency? worstFrequency)  $default,) {final _that = this;
switch (_that) {
case _Satellite():
return $default(_that.bestFrequency,_that.channelCount,_that.id,_that.kind,_that.logo,_that.nameAr,_that.nameEn,_that.orbitalPosition,_that.receptionUrl,_that.slug,_that.worstFrequency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'best_frequency')  Frequency? bestFrequency, @JsonKey(name: 'channel_count')  int channelCount,  int id,  Kind kind,  String? logo, @JsonKey(name: 'name_ar')  String nameAr, @JsonKey(name: 'name_en')  String nameEn, @JsonKey(name: 'orbital_position')  num? orbitalPosition, @JsonKey(name: 'reception_url')  String? receptionUrl,  String slug, @JsonKey(name: 'worst_frequency')  Frequency? worstFrequency)?  $default,) {final _that = this;
switch (_that) {
case _Satellite() when $default != null:
return $default(_that.bestFrequency,_that.channelCount,_that.id,_that.kind,_that.logo,_that.nameAr,_that.nameEn,_that.orbitalPosition,_that.receptionUrl,_that.slug,_that.worstFrequency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Satellite implements Satellite {
  const _Satellite({@JsonKey(name: 'best_frequency') required this.bestFrequency, @JsonKey(name: 'channel_count') required this.channelCount, required this.id, required this.kind, required this.logo, @JsonKey(name: 'name_ar') required this.nameAr, @JsonKey(name: 'name_en') required this.nameEn, @JsonKey(name: 'orbital_position') required this.orbitalPosition, @JsonKey(name: 'reception_url') required this.receptionUrl, required this.slug, @JsonKey(name: 'worst_frequency') required this.worstFrequency});
  factory _Satellite.fromJson(Map<String, dynamic> json) => _$SatelliteFromJson(json);

@override@JsonKey(name: 'best_frequency') final  Frequency? bestFrequency;
@override@JsonKey(name: 'channel_count') final  int channelCount;
@override final  int id;
@override final  Kind kind;
@override final  String? logo;
@override@JsonKey(name: 'name_ar') final  String nameAr;
@override@JsonKey(name: 'name_en') final  String nameEn;
@override@JsonKey(name: 'orbital_position') final  num? orbitalPosition;
@override@JsonKey(name: 'reception_url') final  String? receptionUrl;
@override final  String slug;
@override@JsonKey(name: 'worst_frequency') final  Frequency? worstFrequency;

/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SatelliteCopyWith<_Satellite> get copyWith => __$SatelliteCopyWithImpl<_Satellite>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SatelliteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Satellite&&(identical(other.bestFrequency, bestFrequency) || other.bestFrequency == bestFrequency)&&(identical(other.channelCount, channelCount) || other.channelCount == channelCount)&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.nameAr, nameAr) || other.nameAr == nameAr)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.orbitalPosition, orbitalPosition) || other.orbitalPosition == orbitalPosition)&&(identical(other.receptionUrl, receptionUrl) || other.receptionUrl == receptionUrl)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.worstFrequency, worstFrequency) || other.worstFrequency == worstFrequency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bestFrequency,channelCount,id,kind,logo,nameAr,nameEn,orbitalPosition,receptionUrl,slug,worstFrequency);
}

@override
String toString() {
    return 'Satellite(bestFrequency: $bestFrequency, channelCount: $channelCount, id: $id, kind: $kind, logo: $logo, nameAr: $nameAr, nameEn: $nameEn, orbitalPosition: $orbitalPosition, receptionUrl: $receptionUrl, slug: $slug, worstFrequency: $worstFrequency)';
}


}

/// @nodoc
abstract mixin class _$SatelliteCopyWith<$Res> implements $SatelliteCopyWith<$Res> {
  factory _$SatelliteCopyWith(_Satellite value, $Res Function(_Satellite) _then) = __$SatelliteCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'best_frequency') Frequency? bestFrequency,@JsonKey(name: 'channel_count') int channelCount, int id, Kind kind, String? logo,@JsonKey(name: 'name_ar') String nameAr,@JsonKey(name: 'name_en') String nameEn,@JsonKey(name: 'orbital_position') num? orbitalPosition,@JsonKey(name: 'reception_url') String? receptionUrl, String slug,@JsonKey(name: 'worst_frequency') Frequency? worstFrequency
});


@override $FrequencyCopyWith<$Res>? get bestFrequency;@override $FrequencyCopyWith<$Res>? get worstFrequency;

}
/// @nodoc
class __$SatelliteCopyWithImpl<$Res>
    implements _$SatelliteCopyWith<$Res> {
  __$SatelliteCopyWithImpl(this._self, this._then);

  final _Satellite _self;
  final $Res Function(_Satellite) _then;

/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bestFrequency = freezed,Object? channelCount = null,Object? id = null,Object? kind = null,Object? logo = freezed,Object? nameAr = null,Object? nameEn = null,Object? orbitalPosition = freezed,Object? receptionUrl = freezed,Object? slug = null,Object? worstFrequency = freezed,}) {
  return _then(_Satellite(
bestFrequency: freezed == bestFrequency ? _self.bestFrequency : bestFrequency // ignore: cast_nullable_to_non_nullable
as Frequency?,channelCount: null == channelCount ? _self.channelCount : channelCount // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as Kind,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,nameEn: null == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String,orbitalPosition: freezed == orbitalPosition ? _self.orbitalPosition : orbitalPosition // ignore: cast_nullable_to_non_nullable
as num?,receptionUrl: freezed == receptionUrl ? _self.receptionUrl : receptionUrl // ignore: cast_nullable_to_non_nullable
as String?,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,worstFrequency: freezed == worstFrequency ? _self.worstFrequency : worstFrequency // ignore: cast_nullable_to_non_nullable
as Frequency?,
  ));
}

/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyCopyWith<$Res>? get bestFrequency {
    if (_self.bestFrequency == null) {
    return null;
  }

  return $FrequencyCopyWith<$Res>(_self.bestFrequency!, (value) {
    return _then(_self.copyWith(bestFrequency: value));
  });
}/// Create a copy of Satellite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrequencyCopyWith<$Res>? get worstFrequency {
    if (_self.worstFrequency == null) {
    return null;
  }

  return $FrequencyCopyWith<$Res>(_self.worstFrequency!, (value) {
    return _then(_self.copyWith(worstFrequency: value));
  });
}
}

// dart format on
