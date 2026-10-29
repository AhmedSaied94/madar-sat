// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcast.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Broadcast {

@JsonKey(name: 'channel_count') int get channelCount;@JsonKey(name: 'has_free') bool get hasFree; List<HeadlineEntry> get headline;
/// Create a copy of Broadcast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BroadcastCopyWith<Broadcast> get copyWith => _$BroadcastCopyWithImpl<Broadcast>(this as Broadcast, _$identity);

  /// Serializes this Broadcast to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Broadcast;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Broadcast&&(identical(other.channelCount, _this.channelCount) || other.channelCount == _this.channelCount)&&(identical(other.hasFree, _this.hasFree) || other.hasFree == _this.hasFree)&&const DeepCollectionEquality().equals(other.headline, _this.headline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Broadcast;
  return Object.hash(runtimeType,_this.channelCount,_this.hasFree,const DeepCollectionEquality().hash(_this.headline));
}

@override
String toString() {
  final _this = this as Broadcast;
  return 'Broadcast(channelCount: ${_this.channelCount}, hasFree: ${_this.hasFree}, headline: ${_this.headline})';
}


}

/// @nodoc
abstract mixin class $BroadcastCopyWith<$Res>  {
  factory $BroadcastCopyWith(Broadcast value, $Res Function(Broadcast) _then) = _$BroadcastCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'channel_count') int channelCount,@JsonKey(name: 'has_free') bool hasFree, List<HeadlineEntry> headline
});




}
/// @nodoc
class _$BroadcastCopyWithImpl<$Res>
    implements $BroadcastCopyWith<$Res> {
  _$BroadcastCopyWithImpl(this._self, this._then);

  final Broadcast _self;
  final $Res Function(Broadcast) _then;

/// Create a copy of Broadcast
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channelCount = null,Object? hasFree = null,Object? headline = null,}) {
  return _then(Broadcast(
channelCount: null == channelCount ? _self.channelCount : channelCount // ignore: cast_nullable_to_non_nullable
as int,hasFree: null == hasFree ? _self.hasFree : hasFree // ignore: cast_nullable_to_non_nullable
as bool,headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as List<HeadlineEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [Broadcast].
extension BroadcastPatterns on Broadcast {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Broadcast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Broadcast() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Broadcast value)  $default,){
final _that = this;
switch (_that) {
case _Broadcast():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Broadcast value)?  $default,){
final _that = this;
switch (_that) {
case _Broadcast() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'channel_count')  int channelCount, @JsonKey(name: 'has_free')  bool hasFree,  List<HeadlineEntry> headline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Broadcast() when $default != null:
return $default(_that.channelCount,_that.hasFree,_that.headline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'channel_count')  int channelCount, @JsonKey(name: 'has_free')  bool hasFree,  List<HeadlineEntry> headline)  $default,) {final _that = this;
switch (_that) {
case _Broadcast():
return $default(_that.channelCount,_that.hasFree,_that.headline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'channel_count')  int channelCount, @JsonKey(name: 'has_free')  bool hasFree,  List<HeadlineEntry> headline)?  $default,) {final _that = this;
switch (_that) {
case _Broadcast() when $default != null:
return $default(_that.channelCount,_that.hasFree,_that.headline);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Broadcast implements Broadcast {
  const _Broadcast({@JsonKey(name: 'channel_count') required this.channelCount, @JsonKey(name: 'has_free') required this.hasFree, required  List<HeadlineEntry> headline}): _headline = headline;
  factory _Broadcast.fromJson(Map<String, dynamic> json) => _$BroadcastFromJson(json);

@override@JsonKey(name: 'channel_count') final  int channelCount;
@override@JsonKey(name: 'has_free') final  bool hasFree;
 final  List<HeadlineEntry> _headline;
@override List<HeadlineEntry> get headline {
  if (_headline is EqualUnmodifiableListView) return _headline;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_headline);
}


/// Create a copy of Broadcast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BroadcastCopyWith<_Broadcast> get copyWith => __$BroadcastCopyWithImpl<_Broadcast>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BroadcastToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Broadcast&&(identical(other.channelCount, channelCount) || other.channelCount == channelCount)&&(identical(other.hasFree, hasFree) || other.hasFree == hasFree)&&const DeepCollectionEquality().equals(other.headline, _headline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,channelCount,hasFree,const DeepCollectionEquality().hash(_headline));
}

@override
String toString() {
    return 'Broadcast(channelCount: $channelCount, hasFree: $hasFree, headline: $headline)';
}


}

/// @nodoc
abstract mixin class _$BroadcastCopyWith<$Res> implements $BroadcastCopyWith<$Res> {
  factory _$BroadcastCopyWith(_Broadcast value, $Res Function(_Broadcast) _then) = __$BroadcastCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'channel_count') int channelCount,@JsonKey(name: 'has_free') bool hasFree, List<HeadlineEntry> headline
});




}
/// @nodoc
class __$BroadcastCopyWithImpl<$Res>
    implements _$BroadcastCopyWith<$Res> {
  __$BroadcastCopyWithImpl(this._self, this._then);

  final _Broadcast _self;
  final $Res Function(_Broadcast) _then;

/// Create a copy of Broadcast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channelCount = null,Object? hasFree = null,Object? headline = null,}) {
  return _then(_Broadcast(
channelCount: null == channelCount ? _self.channelCount : channelCount // ignore: cast_nullable_to_non_nullable
as int,hasFree: null == hasFree ? _self.hasFree : hasFree // ignore: cast_nullable_to_non_nullable
as bool,headline: null == headline ? _self._headline : headline // ignore: cast_nullable_to_non_nullable
as List<HeadlineEntry>,
  ));
}


}

// dart format on
