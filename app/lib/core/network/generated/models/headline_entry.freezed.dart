// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'headline_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HeadlineEntry {

 Access? get access;@JsonKey(name: 'channel_id') int get channelId; Frequency? get frequency; String get name; SatelliteRef? get satellite;
/// Create a copy of HeadlineEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeadlineEntryCopyWith<HeadlineEntry> get copyWith => _$HeadlineEntryCopyWithImpl<HeadlineEntry>(this as HeadlineEntry, _$identity);

  /// Serializes this HeadlineEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HeadlineEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeadlineEntry&&(identical(other.access, _this.access) || other.access == _this.access)&&(identical(other.channelId, _this.channelId) || other.channelId == _this.channelId)&&(identical(other.frequency, _this.frequency) || other.frequency == _this.frequency)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.satellite, _this.satellite) || other.satellite == _this.satellite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HeadlineEntry;
  return Object.hash(runtimeType,_this.access,_this.channelId,_this.frequency,_this.name,_this.satellite);
}

@override
String toString() {
  final _this = this as HeadlineEntry;
  return 'HeadlineEntry(access: ${_this.access}, channelId: ${_this.channelId}, frequency: ${_this.frequency}, name: ${_this.name}, satellite: ${_this.satellite})';
}


}

/// @nodoc
abstract mixin class $HeadlineEntryCopyWith<$Res>  {
  factory $HeadlineEntryCopyWith(HeadlineEntry value, $Res Function(HeadlineEntry) _then) = _$HeadlineEntryCopyWithImpl;
@useResult
$Res call({
 Access? access,@JsonKey(name: 'channel_id') int channelId, Frequency? frequency, String name, SatelliteRef? satellite
});


$FrequencyCopyWith<$Res>? get frequency;$SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class _$HeadlineEntryCopyWithImpl<$Res>
    implements $HeadlineEntryCopyWith<$Res> {
  _$HeadlineEntryCopyWithImpl(this._self, this._then);

  final HeadlineEntry _self;
  final $Res Function(HeadlineEntry) _then;

/// Create a copy of HeadlineEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? access = freezed,Object? channelId = null,Object? frequency = freezed,Object? name = null,Object? satellite = freezed,}) {
  return _then(HeadlineEntry(
access: freezed == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access?,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as int,frequency: freezed == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,
  ));
}
/// Create a copy of HeadlineEntry
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
}/// Create a copy of HeadlineEntry
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


/// Adds pattern-matching-related methods to [HeadlineEntry].
extension HeadlineEntryPatterns on HeadlineEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeadlineEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeadlineEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeadlineEntry value)  $default,){
final _that = this;
switch (_that) {
case _HeadlineEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeadlineEntry value)?  $default,){
final _that = this;
switch (_that) {
case _HeadlineEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Access? access, @JsonKey(name: 'channel_id')  int channelId,  Frequency? frequency,  String name,  SatelliteRef? satellite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeadlineEntry() when $default != null:
return $default(_that.access,_that.channelId,_that.frequency,_that.name,_that.satellite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Access? access, @JsonKey(name: 'channel_id')  int channelId,  Frequency? frequency,  String name,  SatelliteRef? satellite)  $default,) {final _that = this;
switch (_that) {
case _HeadlineEntry():
return $default(_that.access,_that.channelId,_that.frequency,_that.name,_that.satellite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Access? access, @JsonKey(name: 'channel_id')  int channelId,  Frequency? frequency,  String name,  SatelliteRef? satellite)?  $default,) {final _that = this;
switch (_that) {
case _HeadlineEntry() when $default != null:
return $default(_that.access,_that.channelId,_that.frequency,_that.name,_that.satellite);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HeadlineEntry implements HeadlineEntry {
  const _HeadlineEntry({required this.access, @JsonKey(name: 'channel_id') required this.channelId, required this.frequency, required this.name, required this.satellite});
  factory _HeadlineEntry.fromJson(Map<String, dynamic> json) => _$HeadlineEntryFromJson(json);

@override final  Access? access;
@override@JsonKey(name: 'channel_id') final  int channelId;
@override final  Frequency? frequency;
@override final  String name;
@override final  SatelliteRef? satellite;

/// Create a copy of HeadlineEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeadlineEntryCopyWith<_HeadlineEntry> get copyWith => __$HeadlineEntryCopyWithImpl<_HeadlineEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HeadlineEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeadlineEntry&&(identical(other.access, access) || other.access == access)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.name, name) || other.name == name)&&(identical(other.satellite, satellite) || other.satellite == satellite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,access,channelId,frequency,name,satellite);
}

@override
String toString() {
    return 'HeadlineEntry(access: $access, channelId: $channelId, frequency: $frequency, name: $name, satellite: $satellite)';
}


}

/// @nodoc
abstract mixin class _$HeadlineEntryCopyWith<$Res> implements $HeadlineEntryCopyWith<$Res> {
  factory _$HeadlineEntryCopyWith(_HeadlineEntry value, $Res Function(_HeadlineEntry) _then) = __$HeadlineEntryCopyWithImpl;
@override @useResult
$Res call({
 Access? access,@JsonKey(name: 'channel_id') int channelId, Frequency? frequency, String name, SatelliteRef? satellite
});


@override $FrequencyCopyWith<$Res>? get frequency;@override $SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class __$HeadlineEntryCopyWithImpl<$Res>
    implements _$HeadlineEntryCopyWith<$Res> {
  __$HeadlineEntryCopyWithImpl(this._self, this._then);

  final _HeadlineEntry _self;
  final $Res Function(_HeadlineEntry) _then;

/// Create a copy of HeadlineEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? access = freezed,Object? channelId = null,Object? frequency = freezed,Object? name = null,Object? satellite = freezed,}) {
  return _then(_HeadlineEntry(
access: freezed == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access?,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as int,frequency: freezed == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,
  ));
}

/// Create a copy of HeadlineEntry
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
}/// Create a copy of HeadlineEntry
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
