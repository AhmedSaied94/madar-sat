// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcast_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BroadcastEntry {

 Access? get access;@JsonKey(name: 'channel_id') int? get channelId; List<CommentatorRef> get commentators; Frequency? get frequency; BroadcastEntryKind get kind; String get label; String? get logo; SatelliteRef? get satellite;
/// Create a copy of BroadcastEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BroadcastEntryCopyWith<BroadcastEntry> get copyWith => _$BroadcastEntryCopyWithImpl<BroadcastEntry>(this as BroadcastEntry, _$identity);

  /// Serializes this BroadcastEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BroadcastEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BroadcastEntry&&(identical(other.access, _this.access) || other.access == _this.access)&&(identical(other.channelId, _this.channelId) || other.channelId == _this.channelId)&&const DeepCollectionEquality().equals(other.commentators, _this.commentators)&&(identical(other.frequency, _this.frequency) || other.frequency == _this.frequency)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.satellite, _this.satellite) || other.satellite == _this.satellite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BroadcastEntry;
  return Object.hash(runtimeType,_this.access,_this.channelId,const DeepCollectionEquality().hash(_this.commentators),_this.frequency,_this.kind,_this.label,_this.logo,_this.satellite);
}

@override
String toString() {
  final _this = this as BroadcastEntry;
  return 'BroadcastEntry(access: ${_this.access}, channelId: ${_this.channelId}, commentators: ${_this.commentators}, frequency: ${_this.frequency}, kind: ${_this.kind}, label: ${_this.label}, logo: ${_this.logo}, satellite: ${_this.satellite})';
}


}

/// @nodoc
abstract mixin class $BroadcastEntryCopyWith<$Res>  {
  factory $BroadcastEntryCopyWith(BroadcastEntry value, $Res Function(BroadcastEntry) _then) = _$BroadcastEntryCopyWithImpl;
@useResult
$Res call({
 Access? access,@JsonKey(name: 'channel_id') int? channelId, List<CommentatorRef> commentators, Frequency? frequency, BroadcastEntryKind kind, String label, String? logo, SatelliteRef? satellite
});


$FrequencyCopyWith<$Res>? get frequency;$SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class _$BroadcastEntryCopyWithImpl<$Res>
    implements $BroadcastEntryCopyWith<$Res> {
  _$BroadcastEntryCopyWithImpl(this._self, this._then);

  final BroadcastEntry _self;
  final $Res Function(BroadcastEntry) _then;

/// Create a copy of BroadcastEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? access = freezed,Object? channelId = freezed,Object? commentators = null,Object? frequency = freezed,Object? kind = null,Object? label = null,Object? logo = freezed,Object? satellite = freezed,}) {
  return _then(BroadcastEntry(
access: freezed == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access?,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as int?,commentators: null == commentators ? _self.commentators : commentators // ignore: cast_nullable_to_non_nullable
as List<CommentatorRef>,frequency: freezed == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as BroadcastEntryKind,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,
  ));
}
/// Create a copy of BroadcastEntry
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
}/// Create a copy of BroadcastEntry
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


/// Adds pattern-matching-related methods to [BroadcastEntry].
extension BroadcastEntryPatterns on BroadcastEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BroadcastEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BroadcastEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BroadcastEntry value)  $default,){
final _that = this;
switch (_that) {
case _BroadcastEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BroadcastEntry value)?  $default,){
final _that = this;
switch (_that) {
case _BroadcastEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Access? access, @JsonKey(name: 'channel_id')  int? channelId,  List<CommentatorRef> commentators,  Frequency? frequency,  BroadcastEntryKind kind,  String label,  String? logo,  SatelliteRef? satellite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BroadcastEntry() when $default != null:
return $default(_that.access,_that.channelId,_that.commentators,_that.frequency,_that.kind,_that.label,_that.logo,_that.satellite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Access? access, @JsonKey(name: 'channel_id')  int? channelId,  List<CommentatorRef> commentators,  Frequency? frequency,  BroadcastEntryKind kind,  String label,  String? logo,  SatelliteRef? satellite)  $default,) {final _that = this;
switch (_that) {
case _BroadcastEntry():
return $default(_that.access,_that.channelId,_that.commentators,_that.frequency,_that.kind,_that.label,_that.logo,_that.satellite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Access? access, @JsonKey(name: 'channel_id')  int? channelId,  List<CommentatorRef> commentators,  Frequency? frequency,  BroadcastEntryKind kind,  String label,  String? logo,  SatelliteRef? satellite)?  $default,) {final _that = this;
switch (_that) {
case _BroadcastEntry() when $default != null:
return $default(_that.access,_that.channelId,_that.commentators,_that.frequency,_that.kind,_that.label,_that.logo,_that.satellite);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BroadcastEntry implements BroadcastEntry {
  const _BroadcastEntry({required this.access, @JsonKey(name: 'channel_id') required this.channelId, required  List<CommentatorRef> commentators, required this.frequency, required this.kind, required this.label, required this.logo, required this.satellite}): _commentators = commentators;
  factory _BroadcastEntry.fromJson(Map<String, dynamic> json) => _$BroadcastEntryFromJson(json);

@override final  Access? access;
@override@JsonKey(name: 'channel_id') final  int? channelId;
 final  List<CommentatorRef> _commentators;
@override List<CommentatorRef> get commentators {
  if (_commentators is EqualUnmodifiableListView) return _commentators;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commentators);
}

@override final  Frequency? frequency;
@override final  BroadcastEntryKind kind;
@override final  String label;
@override final  String? logo;
@override final  SatelliteRef? satellite;

/// Create a copy of BroadcastEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BroadcastEntryCopyWith<_BroadcastEntry> get copyWith => __$BroadcastEntryCopyWithImpl<_BroadcastEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BroadcastEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BroadcastEntry&&(identical(other.access, access) || other.access == access)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&const DeepCollectionEquality().equals(other.commentators, _commentators)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.satellite, satellite) || other.satellite == satellite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,access,channelId,const DeepCollectionEquality().hash(_commentators),frequency,kind,label,logo,satellite);
}

@override
String toString() {
    return 'BroadcastEntry(access: $access, channelId: $channelId, commentators: $commentators, frequency: $frequency, kind: $kind, label: $label, logo: $logo, satellite: $satellite)';
}


}

/// @nodoc
abstract mixin class _$BroadcastEntryCopyWith<$Res> implements $BroadcastEntryCopyWith<$Res> {
  factory _$BroadcastEntryCopyWith(_BroadcastEntry value, $Res Function(_BroadcastEntry) _then) = __$BroadcastEntryCopyWithImpl;
@override @useResult
$Res call({
 Access? access,@JsonKey(name: 'channel_id') int? channelId, List<CommentatorRef> commentators, Frequency? frequency, BroadcastEntryKind kind, String label, String? logo, SatelliteRef? satellite
});


@override $FrequencyCopyWith<$Res>? get frequency;@override $SatelliteRefCopyWith<$Res>? get satellite;

}
/// @nodoc
class __$BroadcastEntryCopyWithImpl<$Res>
    implements _$BroadcastEntryCopyWith<$Res> {
  __$BroadcastEntryCopyWithImpl(this._self, this._then);

  final _BroadcastEntry _self;
  final $Res Function(_BroadcastEntry) _then;

/// Create a copy of BroadcastEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? access = freezed,Object? channelId = freezed,Object? commentators = null,Object? frequency = freezed,Object? kind = null,Object? label = null,Object? logo = freezed,Object? satellite = freezed,}) {
  return _then(_BroadcastEntry(
access: freezed == access ? _self.access : access // ignore: cast_nullable_to_non_nullable
as Access?,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as int?,commentators: null == commentators ? _self._commentators : commentators // ignore: cast_nullable_to_non_nullable
as List<CommentatorRef>,frequency: freezed == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as Frequency?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as BroadcastEntryKind,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,satellite: freezed == satellite ? _self.satellite : satellite // ignore: cast_nullable_to_non_nullable
as SatelliteRef?,
  ));
}

/// Create a copy of BroadcastEntry
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
}/// Create a copy of BroadcastEntry
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
