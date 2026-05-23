import 'dart:typed_data';

class CubeLut {
  const CubeLut({
    required this.title,
    required this.size,
    required this.data,
    required this.normalizedContent,
  });

  final String title;
  final int size;
  final Float32List data;
  final String normalizedContent;

  static CubeLut parse(String text) {
    var title = '';
    var size = 0;
    final values = <double>[];

    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final titleMatch = RegExp(r'^TITLE\s+"?(.*?)"?$').firstMatch(line);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.trim() ?? '';
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.first == 'LUT_3D_SIZE' && parts.length >= 2) {
        size = int.tryParse(parts[1]) ?? 0;
        continue;
      }

      if (RegExp(r'^[A-Z_]+$').hasMatch(parts.first)) continue;
      if (parts.length < 3) continue;

      final rgb = parts.take(3).map(double.tryParse).toList();
      if (rgb.every((value) => value != null)) {
        values.addAll(
          rgb.cast<double>().map((value) => value.clamp(0, 1).toDouble()),
        );
      }
    }

    if (size <= 1) {
      throw const FormatException('Missing or invalid LUT_3D_SIZE.');
    }
    if (values.length != size * size * size * 3) {
      throw FormatException(
        'Expected ${size * size * size} RGB rows, found ${values.length ~/ 3}.',
      );
    }

    return CubeLut(
      title: title,
      size: size,
      data: Float32List.fromList(values),
      normalizedContent: _normalize(size, values),
    );
  }

  static String _normalize(int size, List<double> values) {
    final buffer = StringBuffer('LUT_3D_SIZE $size\n');
    for (var index = 0; index < values.length; index += 3) {
      buffer
        ..write(values[index].toStringAsFixed(9))
        ..write(' ')
        ..write(values[index + 1].toStringAsFixed(9))
        ..write(' ')
        ..writeln(values[index + 2].toStringAsFixed(9));
    }
    return buffer.toString();
  }

  List<int> sample(double red, double green, double blue) {
    final max = size - 1;
    final rf = red.clamp(0, 1).toDouble() * max;
    final gf = green.clamp(0, 1).toDouble() * max;
    final bf = blue.clamp(0, 1).toDouble() * max;
    final r0 = rf.floor();
    final g0 = gf.floor();
    final b0 = bf.floor();
    final r1 = (r0 + 1).clamp(0, max).toInt();
    final g1 = (g0 + 1).clamp(0, max).toInt();
    final b1 = (b0 + 1).clamp(0, max).toInt();
    final tr = rf - r0;
    final tg = gf - g0;
    final tb = bf - b0;

    final c000 = _at(r0, g0, b0);
    final c100 = _at(r1, g0, b0);
    final c010 = _at(r0, g1, b0);
    final c110 = _at(r1, g1, b0);
    final c001 = _at(r0, g0, b1);
    final c101 = _at(r1, g0, b1);
    final c011 = _at(r0, g1, b1);
    final c111 = _at(r1, g1, b1);

    return List<int>.generate(3, (channel) {
      final x00 = _lerp(c000[channel], c100[channel], tr);
      final x10 = _lerp(c010[channel], c110[channel], tr);
      final x01 = _lerp(c001[channel], c101[channel], tr);
      final x11 = _lerp(c011[channel], c111[channel], tr);
      final y0 = _lerp(x00, x10, tg);
      final y1 = _lerp(x01, x11, tg);
      return (_lerp(y0, y1, tb) * 255).round().clamp(0, 255).toInt();
    });
  }

  List<double> _at(int red, int green, int blue) {
    final index = ((blue * size * size) + (green * size) + red) * 3;
    return [data[index], data[index + 1], data[index + 2]];
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
