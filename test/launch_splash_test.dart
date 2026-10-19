import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grou/widgets/launch_splash.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('layar pembuka memakai logo ${brightness.name} lalu menghilang', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const MaterialApp(home: LaunchSplash(child: Text('isi aplikasi'))));

      final logo = tester.widget<Image>(find.byType(Image));
      final asset = (logo.image as AssetImage).assetName;
      expect(asset, brightness == Brightness.dark ? 'assets/branding/logo_dark.png' : 'assets/branding/logo.png');
      expect(logo.width, LaunchSplash.logoSize);

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('isi aplikasi'), findsOneWidget);
    });
  }
}
