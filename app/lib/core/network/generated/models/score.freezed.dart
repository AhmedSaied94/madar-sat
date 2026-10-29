// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Score {

 int get away;@JsonKey(name: 'away_pen') int? get awayPen; int get home;@JsonKey(name: 'home_pen') int? get homePen;
/// Create a copy of Score
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScoreCopyWith<Score> get copyWith => _$ScoreCopyWithImpl<Score>(this as Score, _$identity);

  /// Serializes this Score to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Score;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Score&&(identical(other.away, _this.away) || other.away == _this.away)&&(identical(other.awayPen, _this.awayPen) || other.awayPen == _this.awayPen)&&(identical(other.home, _this.home) || other.home == _this.home)&&(identical(other.homePen, _this.homePen) || other.homePen == _this.homePen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Score;
  return Object.hash(runtimeType,_this.away,_this.awayPen,_this.home,_this.homePen);
}

@override
String toString() {
  final _this = this as Score;
  return 'Score(away: ${_this.away}, awayPen: ${_this.awayPen}, home: ${_this.home}, homePen: ${_this.homePen})';
}


}

/// @nodoc
abstract mixin class $ScoreCopyWith<$Res>  {
  factory $ScoreCopyWith(Score value, $Res Function(Score) _then) = _$ScoreCopyWithImpl;
@useResult
$Res call({
 int away,@JsonKey(name: 'away_pen') int? awayPen, int home,@JsonKey(name: 'home_pen') int? homePen
});




}
/// @nodoc
class _$ScoreCopyWithImpl<$Res>
    implements $ScoreCopyWith<$Res> {
  _$ScoreCopyWithImpl(this._self, this._then);

  final Score _self;
  final $Res Function(Score) _then;

/// Create a copy of Score
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? away = null,Object? awayPen = freezed,Object? home = null,Object? homePen = freezed,}) {
  return _then(Score(
away: null == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as int,awayPen: freezed == awayPen ? _self.awayPen : awayPen // ignore: cast_nullable_to_non_nullable
as int?,home: null == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as int,homePen: freezed == homePen ? _self.homePen : homePen // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Score].
extension ScorePatterns on Score {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Score value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Score() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Score value)  $default,){
final _that = this;
switch (_that) {
case _Score():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Score value)?  $default,){
final _that = this;
switch (_that) {
case _Score() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int away, @JsonKey(name: 'away_pen')  int? awayPen,  int home, @JsonKey(name: 'home_pen')  int? homePen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Score() when $default != null:
return $default(_that.away,_that.awayPen,_that.home,_that.homePen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int away, @JsonKey(name: 'away_pen')  int? awayPen,  int home, @JsonKey(name: 'home_pen')  int? homePen)  $default,) {final _that = this;
switch (_that) {
case _Score():
return $default(_that.away,_that.awayPen,_that.home,_that.homePen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int away, @JsonKey(name: 'away_pen')  int? awayPen,  int home, @JsonKey(name: 'home_pen')  int? homePen)?  $default,) {final _that = this;
switch (_that) {
case _Score() when $default != null:
return $default(_that.away,_that.awayPen,_that.home,_that.homePen);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Score implements Score {
  const _Score({required this.away, @JsonKey(name: 'away_pen') required this.awayPen, required this.home, @JsonKey(name: 'home_pen') required this.homePen});
  factory _Score.fromJson(Map<String, dynamic> json) => _$ScoreFromJson(json);

@override final  int away;
@override@JsonKey(name: 'away_pen') final  int? awayPen;
@override final  int home;
@override@JsonKey(name: 'home_pen') final  int? homePen;

/// Create a copy of Score
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScoreCopyWith<_Score> get copyWith => __$ScoreCopyWithImpl<_Score>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScoreToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Score&&(identical(other.away, away) || other.away == away)&&(identical(other.awayPen, awayPen) || other.awayPen == awayPen)&&(identical(other.home, home) || other.home == home)&&(identical(other.homePen, homePen) || other.homePen == homePen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,away,awayPen,home,homePen);
}

@override
String toString() {
    return 'Score(away: $away, awayPen: $awayPen, home: $home, homePen: $homePen)';
}


}

/// @nodoc
abstract mixin class _$ScoreCopyWith<$Res> implements $ScoreCopyWith<$Res> {
  factory _$ScoreCopyWith(_Score value, $Res Function(_Score) _then) = __$ScoreCopyWithImpl;
@override @useResult
$Res call({
 int away,@JsonKey(name: 'away_pen') int? awayPen, int home,@JsonKey(name: 'home_pen') int? homePen
});




}
/// @nodoc
class __$ScoreCopyWithImpl<$Res>
    implements _$ScoreCopyWith<$Res> {
  __$ScoreCopyWithImpl(this._self, this._then);

  final _Score _self;
  final $Res Function(_Score) _then;

/// Create a copy of Score
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? away = null,Object? awayPen = freezed,Object? home = null,Object? homePen = freezed,}) {
  return _then(_Score(
away: null == away ? _self.away : away // ignore: cast_nullable_to_non_nullable
as int,awayPen: freezed == awayPen ? _self.awayPen : awayPen // ignore: cast_nullable_to_non_nullable
as int?,home: null == home ? _self.home : home // ignore: cast_nullable_to_non_nullable
as int,homePen: freezed == homePen ? _self.homePen : homePen // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
