// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'platform_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlatformEntry {

@JsonKey(name: 'channel_id') int get channelId; String? get country; String? get logo; String get name;
/// Create a copy of PlatformEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlatformEntryCopyWith<PlatformEntry> get copyWith => _$PlatformEntryCopyWithImpl<PlatformEntry>(this as PlatformEntry, _$identity);

  /// Serializes this PlatformEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlatformEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlatformEntry&&(identical(other.channelId, _this.channelId) || other.channelId == _this.channelId)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlatformEntry;
  return Object.hash(runtimeType,_this.channelId,_this.country,_this.logo,_this.name);
}

@override
String toString() {
  final _this = this as PlatformEntry;
  return 'PlatformEntry(channelId: ${_this.channelId}, country: ${_this.country}, logo: ${_this.logo}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $PlatformEntryCopyWith<$Res>  {
  factory $PlatformEntryCopyWith(PlatformEntry value, $Res Function(PlatformEntry) _then) = _$PlatformEntryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'channel_id') int channelId, String? country, String? logo, String name
});




}
/// @nodoc
class _$PlatformEntryCopyWithImpl<$Res>
    implements $PlatformEntryCopyWith<$Res> {
  _$PlatformEntryCopyWithImpl(this._self, this._then);

  final PlatformEntry _self;
  final $Res Function(PlatformEntry) _then;

/// Create a copy of PlatformEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channelId = null,Object? country = freezed,Object? logo = freezed,Object? name = null,}) {
  return _then(PlatformEntry(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as int,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PlatformEntry].
extension PlatformEntryPatterns on PlatformEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlatformEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlatformEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlatformEntry value)  $default,){
final _that = this;
switch (_that) {
case _PlatformEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlatformEntry value)?  $default,){
final _that = this;
switch (_that) {
case _PlatformEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'channel_id')  int channelId,  String? country,  String? logo,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlatformEntry() when $default != null:
return $default(_that.channelId,_that.country,_that.logo,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'channel_id')  int channelId,  String? country,  String? logo,  String name)  $default,) {final _that = this;
switch (_that) {
case _PlatformEntry():
return $default(_that.channelId,_that.country,_that.logo,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'channel_id')  int channelId,  String? country,  String? logo,  String name)?  $default,) {final _that = this;
switch (_that) {
case _PlatformEntry() when $default != null:
return $default(_that.channelId,_that.country,_that.logo,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlatformEntry implements PlatformEntry {
  const _PlatformEntry({@JsonKey(name: 'channel_id') required this.channelId, required this.country, required this.logo, required this.name});
  factory _PlatformEntry.fromJson(Map<String, dynamic> json) => _$PlatformEntryFromJson(json);

@override@JsonKey(name: 'channel_id') final  int channelId;
@override final  String? country;
@override final  String? logo;
@override final  String name;

/// Create a copy of PlatformEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlatformEntryCopyWith<_PlatformEntry> get copyWith => __$PlatformEntryCopyWithImpl<_PlatformEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlatformEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlatformEntry&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.country, country) || other.country == country)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,channelId,country,logo,name);
}

@override
String toString() {
    return 'PlatformEntry(channelId: $channelId, country: $country, logo: $logo, name: $name)';
}


}

/// @nodoc
abstract mixin class _$PlatformEntryCopyWith<$Res> implements $PlatformEntryCopyWith<$Res> {
  factory _$PlatformEntryCopyWith(_PlatformEntry value, $Res Function(_PlatformEntry) _then) = __$PlatformEntryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'channel_id') int channelId, String? country, String? logo, String name
});




}
/// @nodoc
class __$PlatformEntryCopyWithImpl<$Res>
    implements _$PlatformEntryCopyWith<$Res> {
  __$PlatformEntryCopyWithImpl(this._self, this._then);

  final _PlatformEntry _self;
  final $Res Function(_PlatformEntry) _then;

/// Create a copy of PlatformEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channelId = null,Object? country = freezed,Object? logo = freezed,Object? name = null,}) {
  return _then(_PlatformEntry(
channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as int,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
