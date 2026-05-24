import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'cube_lut.dart';

enum LutImageFormat { png, jpeg }

class LutImageProcessor {
  const LutImageProcessor();

  Uint8List applyCube({
    required Uint8List sourceBytes,
    required CubeLut cube,
    int? maxEdge = 1600,
    LutImageFormat format = LutImageFormat.png,
    int jpegQuality = 92,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format.');
    }

    // Keep previews bounded; full-resolution LUT processing should move to an isolate
    // or native pipeline when export-quality rendering is added.
    final source = _resizeIfNeeded(decoded, maxEdge);
    for (final pixel in source) {
      final sampled = cube.sample(
        pixel.r.toDouble() / 255,
        pixel.g.toDouble() / 255,
        pixel.b.toDouble() / 255,
      );
      pixel
        ..r = sampled[0]
        ..g = sampled[1]
        ..b = sampled[2];
    }

    return Uint8List.fromList(switch (format) {
      LutImageFormat.png => img.encodePng(source),
      LutImageFormat.jpeg => img.encodeJpg(source, quality: jpegQuality),
    });
  }

  img.Image _resizeIfNeeded(img.Image source, int? maxEdge) {
    if (maxEdge == null) return source;
    final longestEdge = source.width > source.height
        ? source.width
        : source.height;
    if (longestEdge <= maxEdge) return source;

    if (source.width >= source.height) {
      return img.copyResize(source, width: maxEdge);
    }
    return img.copyResize(source, height: maxEdge);
  }
}
