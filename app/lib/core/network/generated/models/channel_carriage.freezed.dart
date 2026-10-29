// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel_carriage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChannelCarriage {

 Access? get access; Beam? get beam; Category? get category; String? get country;@JsonKey(name: 'display_name') String? get displayName; Frequency? get frequency;@JsonKey(name: 'frequency_changed_at') DateTime? get frequencyChangedAt;@JsonKey(name: 'frequency_note') String? get frequencyNote; int get id; Kind get kind; String? get logo; String get name; String? get package; String? get provider; SatelliteRef? get satellite;
/// Create a copy of ChannelCarriage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelCarriageCopyWith<ChannelCarriage> get copyWith => _$ChannelCarriageCopyWithImpl<ChannelCarriage>(this as ChannelCarriage, _$identity);

  /// Serializes this ChannelCarriage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChannelCarriage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelCarriage&&(identical(other.access, _this.access) || other.access == _this.access)&&(identical(other.beam, _this.beam) || other.beam == _this.beam)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.frequency, _this.frequency) || other.frequency == _this.frequency)&&(identical(other.frequencyChangedAt, _this.frequencyChangedAt) || other.frequencyChangedAt == _this.frequencyChangedAt)&&(identical(other.frequencyNote, _this.frequencyNote) || other.frequencyNote == _this.frequencyNote)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.package, _this.package) || other.package == _this.package)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.satellite, _this.satellite) || other.satellite == _this.satellite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChannelCarriage;
  return Object.hash(runtimeType,_this.access,_this.beam,_this.category,_this.country,_this.displayName,_this.frequency,_this.frequencyChangedAt,_this.frequencyNote,_this.id,_this.kind,_this.logo,_this.name,_this.package,_this.provider,_this.satellite);
}

@override
String toString() {
  final _this = this as ChannelCarriage;
  return 'ChannelCarriage(access: ${_this.access}, beam: ${_this.beam}, category: ${_this.category}, country: ${_this.country}, displayName: ${_this.displayName}, frequency: ${_this.frequency}, frequencyChangedAt: ${_this.frequencyChangedAt}, frequencyNote: ${_this.frequencyNote}, id: ${_this.id}, kind: ${_this.kind}, logo: ${_this.logo}, name: ${_this.name}, package: ${_this.package}, provider: ${_this.provider}, satellite: ${_this.satellite})';
}


}

/// @nodoc
abstract mixin class $ChannelCarriageCopyWith<$Res>  {
  factory $ChannelCarriageCopyWith(ChannelCarriage value, $Res Function(ChannelCarriage) _then) = _$ChannelCarriageCopyWithImpl;
@useResult
$Res call({
 Access? access, Beam? beam, Category? category, String? country,@JsonKey(name: 'display_name') String? displayName, Frequency? frequency,@JsonKey(name: 'frequency_changed_at') DateTime? frequencyChangedAt,@JsonKey(name: 'frequency_note') String? frequencyNote, int id, Kind kind, String? logo, String name, String? package, String? provider, SatelliteRef? satellite
});


$FrequencyCopyWith<$Res>? get frequency;$SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class _$ChannelCarriageCopyWithImpl<$Res>
    implements $ChannelCarriageCopyWith<$Res> {
  _$ChannelCarriageCopyWithImpl(this._self, this._then);

  final ChannelCarriage _self;
  final $Res Function(ChannelCarriage) _then;

/// Create a copy of ChannelCarriage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? access = freezed,Object? beam = freezed,Object? category = freezed,Object? country = freezed,Object? displayName = freezed,Object? frequency = freezed,Object? frequencyChangedAt = freezed,Object? frequencyNote = freezed,Object? id = null,Object? kind = null,Object? logo = freezed,Object? name = null,Object? package = freezed,Object? provider = freezed,Object? satellite = freezed,}) {
  return _then(ChannelCarriage(
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
as String,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,
  ));
}
/// Create a copy of ChannelCarriage
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
}/// Create a copy of ChannelCarriage
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


/// Adds pattern-matching-related methods to [ChannelCarriage].
extension ChannelCarriagePatterns on ChannelCarriage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChannelCarriage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChannelCarriage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChannelCarriage value)  $default,){
final _that = this;
switch (_that) {
case _ChannelCarriage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChannelCarriage value)?  $default,){
final _that = this;
switch (_that) {
case _ChannelCarriage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Access? access,  Beam? beam,  Category? category,  String? country, @JsonKey(name: 'display_name')  String? displayName,  Frequency? frequency, @JsonKey(name: 'frequency_changed_at')  DateTime? frequencyChangedAt, @JsonKey(name: 'frequency_note')  String? frequencyNote,  int id,  Kind kind,  String? logo,  String name,  String? package,  String? provider,  SatelliteRef? satellite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChannelCarriage() when $default != null:
return $default(_that.access,_that.beam,_that.category,_that.country,_that.displayName,_that.frequency,_that.frequencyChangedAt,_that.frequencyNote,_that.id,_that.kind,_that.logo,_that.name,_that.package,_that.provider,_that.satellite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Access? access,  Beam? beam,  Category? category,  String? country, @JsonKey(name: 'display_name')  String? displayName,  Frequency? frequency, @JsonKey(name: 'frequency_changed_at')  DateTime? frequencyChangedAt, @JsonKey(name: 'frequency_note')  String? frequencyNote,  int id,  Kind kind,  String? logo,  String name,  String? package,  String? provider,  SatelliteRef? satellite)  $default,) {final _that = this;
switch (_that) {
case _ChannelCarriage():
return $default(_that.access,_that.beam,_that.category,_that.country,_that.displayName,_that.frequency,_that.frequencyChangedAt,_that.frequencyNote,_that.id,_that.kind,_that.logo,_that.name,_that.package,_that.provider,_that.satellite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Access? access,  Beam? beam,  Category? category,  String? country, @JsonKey(name: 'display_name')  String? displayName,  Frequency? frequency, @JsonKey(name: 'frequency_changed_at')  DateTime? frequencyChangedAt, @JsonKey(name: 'frequency_note')  String? frequencyNote,  int id,  Kind kind,  String? logo,  String name,  String? package,  String? provider,  SatelliteRef? satellite)?  $default,) {final _that = this;
switch (_that) {
case _ChannelCarriage() when $default != null:
return $default(_that.access,_that.beam,_that.category,_that.country,_that.displayName,_that.frequency,_that.frequencyChangedAt,_that.frequencyNote,_that.id,_that.kind,_that.logo,_that.name,_that.package,_that.provider,_that.satellite);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChannelCarriage implements ChannelCarriage {
  const _ChannelCarriage({required this.access, required this.beam, required this.category, required this.country, @JsonKey(name: 'display_name') required this.displayName, required this.frequency, @JsonKey(name: 'frequency_changed_at') required this.frequencyChangedAt, @JsonKey(name: 'frequency_note') required this.frequencyNote, required this.id, required this.kind, required this.logo, required this.name, required this.package, required this.provider, required this.satellite});
  factory _ChannelCarriage.fromJson(Map<String, dynamic> json) => _$ChannelCarriageFromJson(json);

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
@override final  String? package;
@override final  String? provider;
@override final  SatelliteRef? satellite;

/// Create a copy of ChannelCarriage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelCarriageCopyWith<_ChannelCarriage> get copyWith => __$ChannelCarriageCopyWithImpl<_ChannelCarriage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChannelCarriageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChannelCarriage&&(identical(other.access, access) || other.access == access)&&(identical(other.beam, beam) || other.beam == beam)&&(identical(other.category, category) || other.category == category)&&(identical(other.country, country) || other.country == country)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.frequencyChangedAt, frequencyChangedAt) || other.frequencyChangedAt == frequencyChangedAt)&&(identical(other.frequencyNote, frequencyNote) || other.frequencyNote == frequencyNote)&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name)&&(identical(other.package, package) || other.package == package)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.satellite, satellite) || other.satellite == satellite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,access,beam,category,country,displayName,frequency,frequencyChangedAt,frequencyNote,id,kind,logo,name,package,provider,satellite);
}

@override
String toString() {
    return 'ChannelCarriage(access: $access, beam: $beam, category: $category, country: $country, displayName: $displayName, frequency: $frequency, frequencyChangedAt: $frequencyChangedAt, frequencyNote: $frequencyNote, id: $id, kind: $kind, logo: $logo, name: $name, package: $package, provider: $provider, satellite: $satellite)';
}


}

/// @nodoc
abstract mixin class _$ChannelCarriageCopyWith<$Res> implements $ChannelCarriageCopyWith<$Res> {
  factory _$ChannelCarriageCopyWith(_ChannelCarriage value, $Res Function(_ChannelCarriage) _then) = __$ChannelCarriageCopyWithImpl;
@override @useResult
$Res call({
 Access? access, Beam? beam, Category? category, String? country,@JsonKey(name: 'display_name') String? displayName, Frequency? frequency,@JsonKey(name: 'frequency_changed_at') DateTime? frequencyChangedAt,@JsonKey(name: 'frequency_note') String? frequencyNote, int id, Kind kind, String? logo, String name, String? package, String? provider, SatelliteRef? satellite
});


@override $FrequencyCopyWith<$Res>? get frequency;@override $SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class __$ChannelCarriageCopyWithImpl<$Res>
    implements _$ChannelCarriageCopyWith<$Res> {
  __$ChannelCarriageCopyWithImpl(this._self, this._then);

  final _ChannelCarriage _self;
  final $Res Function(_ChannelCarriage) _then;

/// Create a copy of ChannelCarriage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? access = freezed,Object? beam = freezed,Object? category = freezed,Object? country = freezed,Object? displayName = freezed,Object? frequency = freezed,Object? frequencyChangedAt = freezed,Object? frequencyNote = freezed,Object? id = null,Object? kind = null,Object? logo = freezed,Object? name = null,Object? package = freezed,Object? provider = freezed,Object? satellite = freezed,}) {
  return _then(_ChannelCarriage(
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
as String,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,
  ));
}

/// Create a copy of ChannelCarriage
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
}/// Create a copy of ChannelCarriage
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
