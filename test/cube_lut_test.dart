import 'package:flutter_test/flutter_test.dart';
import 'package:lut_manager/services/cube_lut.dart';

void main() {
  test('samples identity 3D LUT with trilinear interpolation', () {
    final cube = CubeLut.parse('''
TITLE "Identity 2"
LUT_3D_SIZE 2
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
''');

    expect(cube.sample(0, 0, 0), [0, 0, 0]);
    expect(cube.sample(1, 1, 1), [255, 255, 255]);
    expect(cube.sample(0.5, 0.25, 0.75), [128, 64, 191]);
  });
}
