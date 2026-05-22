import 'dart:typed_data';

class CubeLut {
  const CubeLut({
    required this.title,
    required this.size,
    required this.data,
  });

  final String title;
  final int size;
  final Float32List data;

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
        values.addAll(rgb.cast<double>().map((value) => value.clamp(0, 1).toDouble()));
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
    );
  }
}
