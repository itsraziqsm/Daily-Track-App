// Menggambar setiap layar dengan data nyata (sqflite lewat FFI) dalam mode
// terang dan gelap, lalu memastikan tidak ada exception layout seperti
// overflow. Jalankan dengan
//
//   flutter test --update-goldens --dart-define=SCREENSHOTS=true
//
// untuk sekaligus menyimpan tangkapan layar tiap layar ke test/screenshots/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grou/data/seed_activities.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/models/daily_log.dart';
import 'package:grou/providers/schedule_provider.dart';
import 'package:grou/screens/manage_templates_screen.dart';
import 'package:grou/screens/notification_feed_screen.dart';
import 'package:grou/screens/shell_screen.dart';
import 'package:grou/screens/template_editor_screen.dart';
import 'package:grou/theme/app_theme.dart';
import 'package:grou/utils/app_time.dart';
import 'package:grou/widgets/skip_reason_dialog.dart';
import 'package:grou/widgets/theme_mode_sheet.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _screenshots = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFonts() async {
  final families = {
    AppFonts.body: ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'].map((w) => 'assets/fonts/Onest-$w.ttf'),
    AppFonts.subtitle: ['SemiBold', 'Bold'].map((w) => 'assets/fonts/SchibstedGrotesk-$w.ttf'),
    AppFonts.title: ['Bold', 'ExtraBold'].map((w) => 'assets/fonts/BricolageGrotesque-$w.ttf'),
    'packages/lucide_icons_flutter/Lucide': ['packages/lucide_icons_flutter/assets/lucide.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

/// Mengisi log hari ini (selesai, terlambat, dibatalkan) dan beberapa hari
/// sebelumnya, supaya kalender, statistik, dan feed punya isi.
Future<void> _seedLogs(ScheduleProvider provider) async {
  final db = DatabaseHelper.instance;
  final activities = provider.activities;
  final today = AppTime.now();
  for (var back = 0; back < 5; back++) {
    final day = today.subtract(Duration(days: back));
    final key = AppTime.dateKey(day);
    for (var i = 0; i < 4; i++) {
      final status = [LogStatus.done, LogStatus.late, LogStatus.cancelled, LogStatus.done][(i + back) % 4];
      await db.upsertLog(DailyLog(
        activityId: activities[i].id,
        date: key,
        status: status,
        reason: status == LogStatus.cancelled ? skipReasons[back % skipReasons.length] : null,
        timestamp: day,
      ));
    }
  }
  await provider.load();
}

void main() {
  late ScheduleProvider provider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), 'jadwal_harian.db'));
    await initializeDateFormatting('id_ID', null);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('semua layar tergambar rapi dalam mode ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await _loadFonts();
        provider = ScheduleProvider(themeMode: mode);
        await provider.load();
        if (provider.allLogs.isEmpty) await _seedLogs(provider);
      });
      addTearDown(provider.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(AppColors.light),
            darkTheme: buildAppTheme(AppColors.dark),
            themeMode: mode,
            home: const ShellScreen(),
          ),
        ),
      );
      // ShellScreen memuat ulang data setelah frame pertama.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      Future<void> shot(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name (${mode.name})');
        if (_screenshots) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/${mode.name}_$name.png'));
        }
      }

      await shot('1_hari_ini');
      for (final (i, tab) in ['Kalender', 'Statistik', 'Pengaturan'].indexed) {
        await tester.tap(find.byTooltip(tab));
        await shot('${i + 2}_${tab.toLowerCase()}');
      }

      final nav = navigatorKey.currentState!;
      final context = navigatorKey.currentContext!;

      showThemeModeSheet(context, mode);
      await shot('5_sheet_tema');
      nav.pop();

      showSkipReasonDialog(context, '${provider.activities.first.startTime} · ${provider.activities.first.title}');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lainnya'));
      await shot('6_sheet_batal');
      nav.pop();

      nav.push(MaterialPageRoute(builder: (_) => const NotificationFeedScreen()));
      await shot('7_notifikasi');
      nav.pop();

      nav.push(MaterialPageRoute(builder: (_) => const ManageTemplatesScreen()));
      await shot('8_kelola_template');
      nav.pop();

      nav.push(MaterialPageRoute(builder: (_) => TemplateEditorScreen(template: provider.templates.first)));
      await shot('9_edit_template');
      nav.pop();
      await tester.pumpAndSettle();
    });
  }
}
