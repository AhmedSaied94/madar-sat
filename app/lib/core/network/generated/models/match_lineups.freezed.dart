// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'match_lineups.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatchLineups {

 LineupSide? get away; LineupSide? get home;
/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatchLineupsCopyWith<MatchLineups> get copyWith => _$MatchLineupsCopyWithImpl<MatchLineups>(this as MatchLineups, _$identity);

  /// Serializes this MatchLineups to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MatchLineups;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatchLineups&&(identical(other.away, _this.away) || other.away == _this.away)&&(identical(other.home, _this.home) || other.home == _this.home));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MatchLineups;
  return Object.hash(runtimeType,_this.away,_this.home);
}

@override
String toString() {
  final _this = this as MatchLineups;
  return 'MatchLineups(away: ${_this.away}, home: ${_this.home})';
}


}

/// @nodoc
abstract mixin class $MatchLineupsCopyWith<$Res>  {
  factory $MatchLineupsCopyWith(MatchLineups value, $Res Function(MatchLineups) _then) = _$MatchLineupsCopyWithImpl;
@useResult
$Res call({
 LineupSide? away, LineupSide? home
});


$LineupSideCopyWith<$Res>? get away;$LineupSideCopyWith<$Res>? get home;

}
/// @nodoc
class _$MatchLineupsCopyWithImpl<$Res>
    implements $MatchLineupsCopyWith<$Res> {
  _$MatchLineupsCopyWithImpl(this._self, this._then);

  final MatchLineups _self;
  final $Res Function(MatchLineups) _then;

/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? away = freezed,Object? home = freezed,}) {
  return _then(MatchLineups(
away: freezed == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as LineupSide?,home: freezed == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as LineupSide?,
  ));
}
/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LineupSideCopyWith<$Res>? get away {
    if (_self.away == null) {
    return null;
  }

  return $LineupSideCopyWith<$Res>(_self.away!, (value) {
    return _then(_self.copyWith(away: value));
  });
}/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LineupSideCopyWith<$Res>? get home {
    if (_self.home == null) {
    return null;
  }

  return $LineupSideCopyWith<$Res>(_self.home!, (value) {
    return _then(_self.copyWith(home: value));
  });
}
}


/// Adds pattern-matching-related methods to [MatchLineups].
extension MatchLineupsPatterns on MatchLineups {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatchLineups value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatchLineups() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatchLineups value)  $default,){
final _that = this;
switch (_that) {
case _MatchLineups():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatchLineups value)?  $default,){
final _that = this;
switch (_that) {
case _MatchLineups() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LineupSide? away,  LineupSide? home)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatchLineups() when $default != null:
return $default(_that.away,_that.home);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LineupSide? away,  LineupSide? home)  $default,) {final _that = this;
switch (_that) {
case _MatchLineups():
return $default(_that.away,_that.home);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LineupSide? away,  LineupSide? home)?  $default,) {final _that = this;
switch (_that) {
case _MatchLineups() when $default != null:
return $default(_that.away,_that.home);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatchLineups implements MatchLineups {
  const _MatchLineups({required this.away, required this.home});
  factory _MatchLineups.fromJson(Map<String, dynamic> json) => _$MatchLineupsFromJson(json);

@override final  LineupSide? away;
@override final  LineupSide? home;

/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatchLineupsCopyWith<_MatchLineups> get copyWith => __$MatchLineupsCopyWithImpl<_MatchLineups>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatchLineupsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatchLineups&&(identical(other.away, away) || other.away == away)&&(identical(other.home, home) || other.home == home));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,away,home);
}

@override
String toString() {
    return 'MatchLineups(away: $away, home: $home)';
}


}

/// @nodoc
abstract mixin class _$MatchLineupsCopyWith<$Res> implements $MatchLineupsCopyWith<$Res> {
  factory _$MatchLineupsCopyWith(_MatchLineups value, $Res Function(_MatchLineups) _then) = __$MatchLineupsCopyWithImpl;
@override @useResult
$Res call({
 LineupSide? away, LineupSide? home
});


@override $LineupSideCopyWith<$Res>? get away;@override $LineupSideCopyWith<$Res>? get home;

}
/// @nodoc
class __$MatchLineupsCopyWithImpl<$Res>
    implements _$MatchLineupsCopyWith<$Res> {
  __$MatchLineupsCopyWithImpl(this._self, this._then);

  final _MatchLineups _self;
  final $Res Function(_MatchLineups) _then;

/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? away = freezed,Object? home = freezed,}) {
  return _then(_MatchLineups(
away: freezed == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as LineupSide?,home: freezed == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as LineupSide?,
  ));
}

/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LineupSideCopyWith<$Res>? get away {
    if (_self.away == null) {
    return null;
  }

  return $LineupSideCopyWith<$Res>(_self.away!, (value) {
    return _then(_self.copyWith(away: value));
  });
}/// Create a copy of MatchLineups
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LineupSideCopyWith<$Res>? get home {
    if (_self.home == null) {
    return null;
  }

  return $LineupSideCopyWith<$Res>(_self.home!, (value) {
    return _then(_self.copyWith(home: value));
  });
}
}

// dart format on
