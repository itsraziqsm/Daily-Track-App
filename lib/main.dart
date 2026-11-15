import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/agenda_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/target_provider.dart';
import 'screens/shell_screen.dart';
import 'services/app_lock.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/launch_splash.dart';
import 'widgets/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await NotificationService.instance.init();
  final themeMode = await ScheduleProvider.readThemeMode();
  // Dibaca sebelum frame pertama, supaya isi yang dikunci tidak sempat tampil.
  final lock = AppLock();
  await lock.load();
  runApp(GroUApp(themeMode: themeMode, lock: lock));
}

class GroUApp extends StatelessWidget {
  final ThemeMode themeMode;
  final AppLock? lock;
  const GroUApp({super.key, this.themeMode = ThemeMode.system, this.lock});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => lock ?? AppLock()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider(themeMode: themeMode)),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        // Pengingat agenda dihitung pada zona waktu aplikasi, jadi ikut
        // dijadwal ulang saat zona di Pengaturan berubah.
        ChangeNotifierProxyProvider<ScheduleProvider, AgendaProvider>(
          create: (_) => AgendaProvider(),
          update: (_, schedule, agenda) => agenda!..onTimeZone(schedule.timeZone),
        ),
        // Target streak dihitung dari log harian, target finansial dari
        // saldo tabungan.
        ChangeNotifierProxyProvider2<ScheduleProvider, FinanceProvider, TargetProvider>(
          create: (_) => TargetProvider(),
          update: (_, schedule, finance, targets) => targets!
            ..schedule = schedule
            ..finance = finance,
        ),
      ],
      child: Selector<ScheduleProvider, ThemeMode>(
        selector: (_, provider) => provider.themeMode,
        builder: (context, mode, home) => MaterialApp(
          title: 'GroU',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppColors.light),
          darkTheme: buildAppTheme(AppColors.dark),
          themeMode: mode,
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // Di atas Navigator, supaya layar kunci juga menutup halaman yang
          // sedang dibuka.
          builder: (context, child) => AppLockOverlay(child: child!),
          home: home,
        ),
        child: const LaunchSplash(child: ShellScreen()),
      ),
    );
  }
}
