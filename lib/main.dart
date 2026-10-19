import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/schedule_provider.dart';
import 'screens/shell_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await NotificationService.instance.init();
  final themeMode = await ScheduleProvider.readThemeMode();
  runApp(GroUApp(themeMode: themeMode));
}

class GroUApp extends StatelessWidget {
  final ThemeMode themeMode;
  const GroUApp({super.key, this.themeMode = ThemeMode.system});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScheduleProvider(themeMode: themeMode),
      child: Selector<ScheduleProvider, ThemeMode>(
        selector: (_, provider) => provider.themeMode,
        builder: (context, mode, home) => MaterialApp(
          title: 'GroU',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppColors.light),
          darkTheme: buildAppTheme(AppColors.dark),
          themeMode: mode,
          home: home,
        ),
        child: const ShellScreen(),
      ),
    );
  }
}
