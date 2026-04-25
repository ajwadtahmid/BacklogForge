import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _kNoArtwork = 'assets/artwork/no_artwork.png';

/// Displays game artwork from a network [url], falling back to the bundled
/// no-artwork asset when the URL is null or the network request fails.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Image.asset(_kNoArtwork, width: width, height: height, fit: fit);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey[800],
      ),
      errorWidget: (context, url, error) => Image.asset(
        _kNoArtwork,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
}
