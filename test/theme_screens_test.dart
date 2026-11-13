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
import 'package:grou/models/agenda_item.dart';
import 'package:grou/models/daily_log.dart';
import 'package:grou/models/finance.dart';
import 'package:grou/providers/finance_provider.dart';
import 'package:grou/screens/finance_tab.dart';
import 'package:grou/widgets/finance_sheets.dart';
import 'package:grou/models/target.dart';
import 'package:grou/providers/agenda_provider.dart';
import 'package:grou/providers/target_provider.dart';
import 'package:grou/providers/schedule_provider.dart';
import 'package:grou/screens/cancellation_log_screen.dart';
import 'package:grou/screens/manage_templates_screen.dart';
import 'package:grou/screens/notification_feed_screen.dart';
import 'package:grou/screens/settings_screen.dart';
import 'package:grou/screens/shell_screen.dart';
import 'package:grou/screens/stats_screen.dart';
import 'package:grou/screens/target_detail_screen.dart';
import 'package:grou/screens/target_tab.dart';
import 'package:grou/widgets/target_sheets.dart';
import 'package:grou/screens/template_editor_screen.dart';
import 'package:grou/theme/app_theme.dart';
import 'package:grou/utils/app_time.dart';
import 'package:grou/widgets/skip_reason_dialog.dart';
import 'package:grou/widgets/theme_mode_sheet.dart';
import 'package:intl/date_symbol_data_local.dart';
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

/// Agenda contoh di sekitar hari ini: satu berjam dengan catatan, satu
/// sepanjang hari, satu berulang yang sudah selesai, dan satu di hari lain.
Future<void> _seedAgenda(AgendaProvider agenda) async {
  final now = AppTime.now();
  final today = DateTime(now.year, now.month, now.day);
  await agenda.save(AgendaItem(title: 'Kumpul tugas akhir', date: today));
  await agenda.save(AgendaItem(
    title: 'Rapat proyek',
    note: 'Bawa laptop dan draf laporan minggu ini',
    date: today,
    startTime: '13.00',
    endTime: '14.00',
    reminderMinutes: 15,
  ));
  await agenda.save(AgendaItem(
    title: 'Gym',
    date: today,
    startTime: '18.00',
    endTime: '19.30',
    repeat: AgendaRepeat.weekly,
    repeatDays: [today.weekday, (today.weekday + 1) % 7 + 1],
    reminderMinutes: 30,
  ));
  await agenda.save(AgendaItem(title: 'Bayar kos', date: today.add(const Duration(days: 3)), repeat: AgendaRepeat.monthly));
  await agenda.toggleDone(agenda.items.firstWhere((i) => i.title == 'Gym'), today);
}

/// Target contoh: streak, angka (berat badan dengan riwayat beberapa minggu),
/// dan dua hitungan (mingguan dan per tahun).
Future<void> _seedTargets(TargetProvider targets) async {
  final now = AppTime.now();
  final today = DateTime(now.year, now.month, now.day);
  await targets.save(Target(kind: TargetKind.streak, title: 'Konsisten 2 minggu', targetValue: 14, createdAt: today));
  await targets.save(Target(
    kind: TargetKind.value,
    title: 'Berat badan',
    unit: 'kg',
    startValue: 80,
    targetValue: 72,
    deadline: today.add(const Duration(days: 60)),
    createdAt: today.subtract(const Duration(days: 42)),
  ));
  await targets.save(Target(kind: TargetKind.count, title: 'Gym', unit: 'sesi', targetValue: 3, period: TargetPeriod.week, createdAt: today.subtract(const Duration(days: 30))));
  await targets.save(Target(kind: TargetKind.count, title: 'Baca buku', unit: 'buku', targetValue: 12, period: TargetPeriod.year, createdAt: today.subtract(const Duration(days: 90))));
  final [_, weight, gym, books] = targets.active;
  for (final (i, kg) in [79.2, 78.1, 78.4, 76.9, 76.2, 75.4].indexed) {
    await targets.addEntry(TargetEntry(targetId: weight.id, date: today.subtract(Duration(days: 35 - i * 7)), value: kg, note: i == 5 ? 'Pagi, sebelum sarapan' : null));
  }
  for (var d = 1; d < 30; d += 3) {
    await targets.addEntry(TargetEntry(targetId: gym.id, date: today.subtract(Duration(days: d)), value: 1));
  }
  for (final (i, title) in ['Atomic Habits', 'Laskar Pelangi', 'Deep Work'].indexed) {
    await targets.addEntry(TargetEntry(targetId: books.id, date: today.subtract(Duration(days: 60 - i * 25)), value: 1, note: title));
  }
}

/// Data keuangan contoh: gaji dan pengeluaran tetap sejak tiga bulan lalu,
/// transaksi tiap bulan, dan pemasukan tambahan bulan ini.
Future<void> _seedFinance(FinanceProvider finance) async {
  final db = DatabaseHelper.instance;
  final now = finance.currentMonth;
  final start = now.plus(-3);
  await db.setSalary(start, 6500000);
  await db.setSetting('savings.opening', '12000000');
  await db.setSetting('savings.openingMonth', start.key);
  await db.saveRecurringExpense(RecurringExpense(title: 'Kos', category: 'Tempat tinggal', amount: 1500000, from: start));
  await db.saveRecurringExpense(RecurringExpense(title: 'Internet', category: 'Tagihan & utilitas', amount: 350000, from: start));
  await db.saveRecurringExpense(RecurringExpense(title: 'Cicilan motor', category: 'Cicilan & utang', amount: 900000, from: now.plus(-2)));
  for (var i = 0; i <= 3; i++) {
    final m = start.plus(i);
    final spends = [
      (3, 85000.0 + i * 10000, 'Makan & minum', 'Belanja mingguan'),
      (9, 420000.0, 'Makan & minum', null),
      (12, 150000.0, 'Transportasi', 'Bensin'),
      (18, 275000.0 - i * 20000, 'Hiburan', 'Nonton'),
      (22, 310000.0, 'Belanja', null),
    ];
    for (final (day, amount, cat, note) in spends) {
      if (m == now && day > finance.today.day) continue;
      await db.addFinanceEntry(FinanceEntry(kind: FinanceEntryKind.expense, date: DateTime(m.year, m.month, day), amount: amount, category: cat, note: note));
    }
  }
  await db.addFinanceEntry(FinanceEntry(kind: FinanceEntryKind.income, date: now.start, amount: 750000, note: 'Freelance desain'));
  await finance.load();
}

void main() {
  late ScheduleProvider provider;
  late FinanceProvider finance;
  late AgendaProvider agenda;
  late TargetProvider targets;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
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
        agenda = AgendaProvider();
        await agenda.load();
        if (agenda.items.isEmpty) await _seedAgenda(agenda);
        finance = FinanceProvider();
        await finance.load();
        if (finance.firstMonth == null) await _seedFinance(finance);
        targets = TargetProvider()
          ..schedule = provider
          ..finance = finance;
        await targets.load();
        if (targets.active.isEmpty) {
          await _seedTargets(targets);
          final now = finance.today;
          await targets.save(Target(kind: TargetKind.finance, title: 'Laptop kerja', targetValue: 15000000, createdAt: now));
          await targets.save(Target(
            kind: TargetKind.finance,
            title: 'Dana darurat',
            targetValue: 60000000,
            deadline: DateTime(now.year + 1, now.month, 28),
            createdAt: now,
          ));
          await targets.save(Target(kind: TargetKind.finance, title: 'Headphone', targetValue: 1500000, createdAt: now));
        }
      });
      addTearDown(targets.dispose);
      addTearDown(finance.dispose);
      addTearDown(provider.dispose);
      addTearDown(agenda.dispose);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: agenda),
            ChangeNotifierProvider.value(value: targets),
            ChangeNotifierProvider.value(value: finance),
          ],
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
      // ShellScreen memuat ulang data setelah frame pertama, di dalam waktu
      // palsu test. Tiap langkah database butuh waktu nyata untuk selesai dan
      // satu pump untuk melanjutkan ke langkah berikutnya; panggilan yang
      // tertinggal akan mengunci database untuk test berikutnya.
      Future<void> settleDatabase() async {
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
        }
      }

      await settleDatabase();
      await tester.pumpAndSettle();

      Future<void> shot(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name (${mode.name})');
        if (_screenshots) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/${mode.name}_$name.png'));
        }
      }

      await shot('1_hari_ini');
      await tester.tap(find.byTooltip('Agenda'));
      await shot('2_agenda');
      expect(find.text('Rapat proyek'), findsOneWidget);
      await tester.ensureVisible(find.text('Gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gym'));
      await shot('2b_sheet_agenda');
      expect(find.text('Edit agenda'), findsOneWidget);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Target'));
      await shot('3_target');
      expect(find.text('Berat badan'), findsOneWidget);
      final targetList = find.descendant(of: find.byType(TargetTab), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Headphone'), 300, scrollable: targetList);
      await shot('3a_target_finansial');
      expect(find.text('Dana sangat mencukupi'), findsOneWidget);
      expect(find.text('Dana cukup'), findsOneWidget);
      for (final (name, title) in [('3b_detail_angka', 'Berat badan'), ('3c_detail_hitungan', 'Gym'), ('3d_detail_streak', 'Konsisten 2 minggu'), ('3g_detail_finansial', 'Laptop kerja'), ('3h_detail_finansial_kurang', 'Dana darurat')]) {
        // Kembali ke atas daftar lalu gulir turun sampai kartunya terlihat;
        // kartu yang jauh dari layar belum dibangun oleh ListView.
        await tester.drag(targetList, const Offset(0, 4000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(title), 200, scrollable: targetList);
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await shot(name);
        expect(find.byType(TargetDetailScreen), findsOneWidget);
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
      }
      showTargetSheet(navigatorKey.currentContext!);
      await shot('3e_sheet_target_baru');
      navigatorKey.currentState!.pop();
      showTargetEntrySheet(navigatorKey.currentContext!, targets.active.firstWhere((t) => t.title == 'Berat badan'));
      await shot('3f_sheet_catat');
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Keuangan'));
      await shot('4_keuangan');
      final financeList = find.descendant(of: find.byType(FinanceTab), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Freelance desain'), 300, scrollable: financeList);
      await shot('4a_keuangan_transaksi');
      await tester.scrollUntilVisible(find.text('PROYEKSI AKHIR TAHUN'), 300, scrollable: financeList);
      await tester.drag(financeList, const Offset(0, -400));
      await shot('4b_keuangan_tabungan');
      showFinanceEntrySheet(navigatorKey.currentContext!, kind: FinanceEntryKind.expense, date: finance.today);
      await shot('4c_sheet_pengeluaran');
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // Pengaturan dibuka dari tombol profil di app bar.
      await tester.tap(find.byTooltip('Pengaturan'));
      await shot('4d_pengaturan');
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Toleransi terlambat bisa diubah dari Pengaturan dan langsung berlaku.
      final settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
      await tester.tap(find.text('Toleransi terlambat'));
      await shot('5_sheet_toleransi');
      await tester.tap(find.text('45 mnt'));
      await tester.pumpAndSettle();
      expect(provider.toleranceMinutes, 45);
      expect(find.text('45 mnt'), findsOneWidget);
      await tester.runAsync(() => provider.setToleranceMinutes(ScheduleProvider.defaultToleranceMinutes));
      await tester.pumpAndSettle();

      // Pengaturan → Lainnya: Statistik dan Log pembatalan.
      await tester.scrollUntilVisible(find.text('Log pembatalan'), 200, scrollable: settingsList);
      await shot('6_pengaturan_lainnya');
      await tester.tap(find.text('Statistik'));
      await shot('7_statistik');
      expect(find.byType(StatsScreen), findsOneWidget);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log pembatalan'));
      await shot('8_log_pembatalan');
      expect(find.byType(CancellationLogScreen), findsOneWidget);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      final nav = navigatorKey.currentState!;
      final context = navigatorKey.currentContext!;

      showThemeModeSheet(context, mode);
      await shot('9_sheet_tema');
      nav.pop();

      showSkipReasonDialog(context, '${provider.activities.first.startTime} · ${provider.activities.first.title}');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lainnya'));
      await shot('10_sheet_batal');
      nav.pop();

      nav.push(MaterialPageRoute(builder: (_) => const NotificationFeedScreen()));
      await shot('11_notifikasi');
      nav.pop();

      nav.push(MaterialPageRoute(builder: (_) => const ManageTemplatesScreen()));
      await shot('12_kelola_template');
      nav.pop();

      nav.push(MaterialPageRoute(builder: (_) => TemplateEditorScreen(template: provider.templates.first)));
      await shot('13_edit_template');
      nav.pop();
      await tester.pumpAndSettle();
      await settleDatabase();
    });
  }
}
