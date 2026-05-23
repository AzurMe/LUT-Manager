import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'cube_lut.dart';

class LutImageProcessor {
  const LutImageProcessor();

  Uint8List applyCube({
    required Uint8List sourceBytes,
    required CubeLut cube,
    int maxPreviewEdge = 1600,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format.');
    }

    final source = _resizeForPreview(decoded, maxPreviewEdge);
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

    return Uint8List.fromList(img.encodePng(source));
  }

  img.Image _resizeForPreview(img.Image source, int maxPreviewEdge) {
    final longestEdge = source.width > source.height
        ? source.width
        : source.height;
    if (longestEdge <= maxPreviewEdge) return source;

    if (source.width >= source.height) {
      return img.copyResize(source, width: maxPreviewEdge);
    }
    return img.copyResize(source, height: maxPreviewEdge);
  }
}
