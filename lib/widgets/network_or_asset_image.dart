import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NetworkOrAssetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;

  const NetworkOrAssetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        color: color,
        placeholder: (context, url) => const SizedBox(),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      );
    }
    return Image.asset(
      url,
      width: width,
      height: height,
      fit: fit,
      color: color,
    );
  }
}
