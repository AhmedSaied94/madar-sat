// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'platform_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlatformGroup {

 List<PlatformEntry> get items; String get region;
/// Create a copy of PlatformGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlatformGroupCopyWith<PlatformGroup> get copyWith => _$PlatformGroupCopyWithImpl<PlatformGroup>(this as PlatformGroup, _$identity);

  /// Serializes this PlatformGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlatformGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlatformGroup&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.region, _this.region) || other.region == _this.region));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlatformGroup;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.region);
}

@override
String toString() {
  final _this = this as PlatformGroup;
  return 'PlatformGroup(items: ${_this.items}, region: ${_this.region})';
}


}

/// @nodoc
abstract mixin class $PlatformGroupCopyWith<$Res>  {
  factory $PlatformGroupCopyWith(PlatformGroup value, $Res Function(PlatformGroup) _then) = _$PlatformGroupCopyWithImpl;
@useResult
$Res call({
 List<PlatformEntry> items, String region
});




}
/// @nodoc
class _$PlatformGroupCopyWithImpl<$Res>
    implements $PlatformGroupCopyWith<$Res> {
  _$PlatformGroupCopyWithImpl(this._self, this._then);

  final PlatformGroup _self;
  final $Res Function(PlatformGroup) _then;

/// Create a copy of PlatformGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? region = null,}) {
  return _then(PlatformGroup(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<PlatformEntry>,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PlatformGroup].
extension PlatformGroupPatterns on PlatformGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlatformGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlatformGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlatformGroup value)  $default,){
final _that = this;
switch (_that) {
case _PlatformGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlatformGroup value)?  $default,){
final _that = this;
switch (_that) {
case _PlatformGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PlatformEntry> items,  String region)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlatformGroup() when $default != null:
return $default(_that.items,_that.region);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PlatformEntry> items,  String region)  $default,) {final _that = this;
switch (_that) {
case _PlatformGroup():
return $default(_that.items,_that.region);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PlatformEntry> items,  String region)?  $default,) {final _that = this;
switch (_that) {
case _PlatformGroup() when $default != null:
return $default(_that.items,_that.region);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlatformGroup implements PlatformGroup {
  const _PlatformGroup({required  List<PlatformEntry> items, required this.region}): _items = items;
  factory _PlatformGroup.fromJson(Map<String, dynamic> json) => _$PlatformGroupFromJson(json);

 final  List<PlatformEntry> _items;
@override List<PlatformEntry> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String region;

/// Create a copy of PlatformGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlatformGroupCopyWith<_PlatformGroup> get copyWith => __$PlatformGroupCopyWithImpl<_PlatformGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlatformGroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlatformGroup&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.region, region) || other.region == region));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),region);
}

@override
String toString() {
    return 'PlatformGroup(items: $items, region: $region)';
}


}

/// @nodoc
abstract mixin class _$PlatformGroupCopyWith<$Res> implements $PlatformGroupCopyWith<$Res> {
  factory _$PlatformGroupCopyWith(_PlatformGroup value, $Res Function(_PlatformGroup) _then) = __$PlatformGroupCopyWithImpl;
@override @useResult
$Res call({
 List<PlatformEntry> items, String region
});




}
/// @nodoc
class __$PlatformGroupCopyWithImpl<$Res>
    implements _$PlatformGroupCopyWith<$Res> {
  __$PlatformGroupCopyWithImpl(this._self, this._then);

  final _PlatformGroup _self;
  final $Res Function(_PlatformGroup) _then;

/// Create a copy of PlatformGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? region = null,}) {
  return _then(_PlatformGroup(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<PlatformEntry>,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
