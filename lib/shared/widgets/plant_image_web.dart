import 'package:flutter/material.dart';

class PlantImage extends StatelessWidget {
  final String? imagePath;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;

  const PlantImage({
    super.key,
    required this.imagePath,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null || path.isEmpty) {
      return SizedBox(width: width, height: height, child: fallback);
    }
    return Image.network(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => SizedBox(
        width: width,
        height: height,
        child: fallback,
      ),
    );
  }
}
