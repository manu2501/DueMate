// Exports the DueMate mark (AppLogoPainter) to the PNGs that can't be vectors:
// legacy launcher icons for Android < 8 and assets/images/app_logo.png.
//
//   flutter test test_screens/logo_export_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/widgets/app_logo.dart';

const _res = '../android/app/src/main/res';

void main() {
  const targets = {
    '$_res/mipmap-mdpi/ic_launcher.png': 48.0,
    '$_res/mipmap-hdpi/ic_launcher.png': 72.0,
    '$_res/mipmap-xhdpi/ic_launcher.png': 96.0,
    '$_res/mipmap-xxhdpi/ic_launcher.png': 144.0,
    '$_res/mipmap-xxxhdpi/ic_launcher.png': 192.0,
    '../assets/images/app_logo.png': 512.0,
  };

  for (final entry in targets.entries) {
    testWidgets('export ${entry.key}', (tester) async {
      final px = entry.value;
      tester.view.physicalSize = Size(px, px);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            child: CustomPaint(size: Size.square(px), painter: const AppLogoPainter()),
          ),
        ),
      );
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile(entry.key));
    });
  }
}
