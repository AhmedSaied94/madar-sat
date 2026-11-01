// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'follow_set.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FollowSet {

 List<int>? get channels; List<int>? get commentators; List<int>? get competitions; List<int>? get matches; List<int>? get teams;
/// Create a copy of FollowSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowSetCopyWith<FollowSet> get copyWith => _$FollowSetCopyWithImpl<FollowSet>(this as FollowSet, _$identity);

  /// Serializes this FollowSet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FollowSet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowSet&&const DeepCollectionEquality().equals(other.channels, _this.channels)&&const DeepCollectionEquality().equals(other.commentators, _this.commentators)&&const DeepCollectionEquality().equals(other.competitions, _this.competitions)&&const DeepCollectionEquality().equals(other.matches, _this.matches)&&const DeepCollectionEquality().equals(other.teams, _this.teams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FollowSet;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.channels),const DeepCollectionEquality().hash(_this.commentators),const DeepCollectionEquality().hash(_this.competitions),const DeepCollectionEquality().hash(_this.matches),const DeepCollectionEquality().hash(_this.teams));
}

@override
String toString() {
  final _this = this as FollowSet;
  return 'FollowSet(channels: ${_this.channels}, commentators: ${_this.commentators}, competitions: ${_this.competitions}, matches: ${_this.matches}, teams: ${_this.teams})';
}


}

/// @nodoc
abstract mixin class $FollowSetCopyWith<$Res>  {
  factory $FollowSetCopyWith(FollowSet value, $Res Function(FollowSet) _then) = _$FollowSetCopyWithImpl;
@useResult
$Res call({
 List<int>? channels, List<int>? commentators, List<int>? competitions, List<int>? matches, List<int>? teams
});




}
/// @nodoc
class _$FollowSetCopyWithImpl<$Res>
    implements $FollowSetCopyWith<$Res> {
  _$FollowSetCopyWithImpl(this._self, this._then);

  final FollowSet _self;
  final $Res Function(FollowSet) _then;

/// Create a copy of FollowSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channels = freezed,Object? commentators = freezed,Object? competitions = freezed,Object? matches = freezed,Object? teams = freezed,}) {
  return _then(FollowSet(
channels: freezed == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as List<int>?,commentators: freezed == commentators ? _self.commentators : commentators // ignore: cast_nullable_to_non_nullable
as List<int>?,competitions: freezed == competitions ? _self.competitions : competitions // ignore: cast_nullable_to_non_nullable
as List<int>?,matches: freezed == matches ? _self.matches : matches // ignore: cast_nullable_to_non_nullable
as List<int>?,teams: freezed == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<int>?,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowSet].
extension FollowSetPatterns on FollowSet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowSet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowSet value)  $default,){
final _that = this;
switch (_that) {
case _FollowSet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowSet value)?  $default,){
final _that = this;
switch (_that) {
case _FollowSet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<int>? channels,  List<int>? commentators,  List<int>? competitions,  List<int>? matches,  List<int>? teams)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowSet() when $default != null:
return $default(_that.channels,_that.commentators,_that.competitions,_that.matches,_that.teams);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<int>? channels,  List<int>? commentators,  List<int>? competitions,  List<int>? matches,  List<int>? teams)  $default,) {final _that = this;
switch (_that) {
case _FollowSet():
return $default(_that.channels,_that.commentators,_that.competitions,_that.matches,_that.teams);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<int>? channels,  List<int>? commentators,  List<int>? competitions,  List<int>? matches,  List<int>? teams)?  $default,) {final _that = this;
switch (_that) {
case _FollowSet() when $default != null:
return $default(_that.channels,_that.commentators,_that.competitions,_that.matches,_that.teams);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FollowSet implements FollowSet {
  const _FollowSet({ List<int>? channels,  List<int>? commentators,  List<int>? competitions,  List<int>? matches,  List<int>? teams}): _channels = channels,_commentators = commentators,_competitions = competitions,_matches = matches,_teams = teams;
  factory _FollowSet.fromJson(Map<String, dynamic> json) => _$FollowSetFromJson(json);

 final  List<int>? _channels;
@override List<int>? get channels {
  final value = _channels;
  if (value == null) return null;
  if (_channels is EqualUnmodifiableListView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _commentators;
@override List<int>? get commentators {
  final value = _commentators;
  if (value == null) return null;
  if (_commentators is EqualUnmodifiableListView) return _commentators;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _competitions;
@override List<int>? get competitions {
  final value = _competitions;
  if (value == null) return null;
  if (_competitions is EqualUnmodifiableListView) return _competitions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _matches;
@override List<int>? get matches {
  final value = _matches;
  if (value == null) return null;
  if (_matches is EqualUnmodifiableListView) return _matches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _teams;
@override List<int>? get teams {
  final value = _teams;
  if (value == null) return null;
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of FollowSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowSetCopyWith<_FollowSet> get copyWith => __$FollowSetCopyWithImpl<_FollowSet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FollowSetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowSet&&const DeepCollectionEquality().equals(other.channels, _channels)&&const DeepCollectionEquality().equals(other.commentators, _commentators)&&const DeepCollectionEquality().equals(other.competitions, _competitions)&&const DeepCollectionEquality().equals(other.matches, _matches)&&const DeepCollectionEquality().equals(other.teams, _teams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_channels),const DeepCollectionEquality().hash(_commentators),const DeepCollectionEquality().hash(_competitions),const DeepCollectionEquality().hash(_matches),const DeepCollectionEquality().hash(_teams));
}

@override
String toString() {
    return 'FollowSet(channels: $channels, commentators: $commentators, competitions: $competitions, matches: $matches, teams: $teams)';
}


}

/// @nodoc
abstract mixin class _$FollowSetCopyWith<$Res> implements $FollowSetCopyWith<$Res> {
  factory _$FollowSetCopyWith(_FollowSet value, $Res Function(_FollowSet) _then) = __$FollowSetCopyWithImpl;
@override @useResult
$Res call({
 List<int>? channels, List<int>? commentators, List<int>? competitions, List<int>? matches, List<int>? teams
});




}
/// @nodoc
class __$FollowSetCopyWithImpl<$Res>
    implements _$FollowSetCopyWith<$Res> {
  __$FollowSetCopyWithImpl(this._self, this._then);

  final _FollowSet _self;
  final $Res Function(_FollowSet) _then;

/// Create a copy of FollowSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channels = freezed,Object? commentators = freezed,Object? competitions = freezed,Object? matches = freezed,Object? teams = freezed,}) {
  return _then(_FollowSet(
channels: freezed == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as List<int>?,commentators: freezed == commentators ? _self._commentators : commentators // ignore: cast_nullable_to_non_nullable
as List<int>?,competitions: freezed == competitions ? _self._competitions : competitions // ignore: cast_nullable_to_non_nullable
as List<int>?,matches: freezed == matches ? _self._matches : matches // ignore: cast_nullable_to_non_nullable
as List<int>?,teams: freezed == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<int>?,
  ));
}


}

// dart format on
