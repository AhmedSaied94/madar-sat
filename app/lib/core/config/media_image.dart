import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import '../links/url_opener.dart';

/// The one rule for logo and image URLs from the API (research R28, D2's security
/// follow-up): an image loads only from the active media host, over `https`, and anything
/// else becomes the component's placeholder instead of a request to a third party.
///
/// [MediaImageScope] carries the host from `main_*.dart`'s Remote Config values down the
/// tree, so a widget deep in a row never reads a provider or a global.
class MediaImageScope extends InheritedWidget {
  const MediaImageScope({super.key, required this.mediaBaseUrl, required super.child});

  final String mediaBaseUrl;

  static String? hostOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaImageScope>()?.mediaBaseUrl;

  @override
  bool updateShouldNotify(MediaImageScope oldWidget) => oldWidget.mediaBaseUrl != mediaBaseUrl;
}

/// The image for [raw], or null when it is not an `https` address on the active media host.
///
/// Null is the placeholder: every component that takes a logo draws its own frame for it
/// (`LogoTile`, `TeamCrest`), so a refused URL is a missing logo, never a broken image.
ImageProvider? mediaImage(BuildContext context, String? raw) =>
    mediaImageFor(raw, mediaBaseUrl: MediaImageScope.hostOf(context) ?? AppConfig.mediaBaseUrl);

/// [mediaImage] without a context, for tests and for callers that already know the host.
ImageProvider? mediaImageFor(String? raw, {required String mediaBaseUrl}) {
  final uri = httpsUri(raw);
  if (uri == null) return null;
  final host = Uri.tryParse(mediaBaseUrl);
  if (host == null || host.scheme != 'https' || host.host.isEmpty) return null;
  if (uri.host != host.host) return null;
  return CachedNetworkImageProvider(uri.toString());
}
