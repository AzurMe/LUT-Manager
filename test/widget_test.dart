import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:lut_manager/main.dart';

void main() {
  testWidgets('LUT Manager home renders sample library', (tester) async {
    _setDesktopViewport(tester);
    await tester.pumpWidget(const LutManagerApp());

    expect(find.text('LUT Manager'), findsOneWidget);
    expect(find.text('Eterna Soft Contrast'), findsWidgets);
    expect(find.text('Tag 筛选'), findsOneWidget);
    expect(find.text('生成 LUT'), findsOneWidget);
  });

  testWidgets('Theme toggle is available', (tester) async {
    _setDesktopViewport(tester);
    await tester.pumpWidget(const LutManagerApp());

    expect(find.byTooltip('切换浅色'), findsOneWidget);
    await tester.tap(find.byTooltip('切换浅色'));
    await tester.pump();

    expect(find.byTooltip('切换深色'), findsOneWidget);
  });
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
