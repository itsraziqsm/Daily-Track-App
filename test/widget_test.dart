// Smoke test aplikasi utuh: GroUApp dirakit persis seperti di main.dart
// (semua provider, layar pembuka, lalu shell) dan harus sampai ke Hari Ini.
//
// Berkas ini sengaja ada di repo: `flutter create .` membangkitkan
// test/widget_test.dart berisi contoh penghitung untuk aplikasi lain bila
// berkasnya belum ada.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/main.dart';
import 'package:grou/widgets/launch_splash.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('GroU terbuka dari layar pembuka sampai Hari Ini', (tester) async {
    await tester.pumpWidget(const GroUApp());
    expect(find.byType(LaunchSplash), findsOneWidget);
    expect(find.bySemanticsLabel('GroU'), findsOneWidget);

    // Data dimuat dari database setelah frame pertama; tiap langkahnya butuh
    // waktu nyata, dan satu pump untuk melanjutkan ke langkah berikutnya.
    // Database baru juga membuat tabel dan mengisi template bawaan dulu.
    Future<void> settleDatabase() async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
    }

    await settleDatabase();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('GroU'), findsNothing, reason: 'layar pembuka sudah memudar');
    expect(find.text('Hari Ini'), findsOneWidget);
    expect(find.text('Bangun tidur & membasuh diri'), findsOneWidget, reason: 'template bawaan termuat');
    for (final tab in ['Agenda', 'Target', 'Keuangan', 'Pengaturan']) {
      expect(find.byTooltip(tab), findsOneWidget);
    }

    // Membongkar aplikasi supaya provider dibuang dan timer-nya berhenti.
    await tester.pumpWidget(const SizedBox());
    await settleDatabase();
  });
}
