import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Loads and displays a song's album-art cover.
///
/// Internally uses [picUrlProvider] to resolve the GD Studio API JSON
/// (`{"url":"..."}`) → actual CDN URL, then renders with [CachedNetworkImage].
///
/// Shows a music-note placeholder while loading / on error.
class SongCover extends ConsumerWidget {
  const SongCover({
    super.key,
    required this.source,
    required this.picId,
    this.size = 300,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
    /// When true wraps the image in a [ClipOval] instead of [ClipRRect].
    this.oval = false,
  });

  final String source;
  final String picId;

  /// Resolution size hint sent to the API (e.g. 300, 400, 500).
  final int size;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final bool oval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = _Placeholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
      oval: oval,
    );

    if (picId.isEmpty) return placeholder;

    final urlAsync = ref.watch(picUrlProvider((source, picId, size)));

    return urlAsync.when(
      loading: () => placeholder,
      error: (_, _) => placeholder,
      data: (url) {
        if (url.isEmpty) return placeholder;
        final image = CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
        );
        if (oval) {
          return ClipOval(child: SizedBox(width: width, height: height, child: image));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: image,
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.oval,
  });

  final double width;
  final double height;
  final double borderRadius;
  final bool oval;

  @override
  Widget build(BuildContext context) {
    final iconSize = (width < height ? width : height) * 0.4;
    final inner = Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F3EE),
      child: Icon(Icons.music_note, color: const Color(0xFF847467), size: iconSize),
    );
    if (oval) return ClipOval(child: inner);
    return ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: inner);
  }
}
