import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/services/app_lock.dart';
import 'package:grou/theme/app_theme.dart';
import 'package:grou/widgets/lock_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeBiometrics extends BiometricAuth {
  bool available;
  bool succeeds;
  int prompts = 0;
  FakeBiometrics({this.available = true, this.succeeds = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeeds;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
    await DatabaseHelper.instance.resetForTest();
  });

  group('AppLock', () {
    test('bawaan tidak mengunci apa pun', () async {
      final lock = AppLock();
      await lock.load();
      expect(lock.scope, LockScope.none);
      expect(lock.enabled, isFalse);
      expect(lock.lockedAtLaunch, isFalse);
      for (final a in LockArea.values) {
        expect(lock.requiresAuth(a), isFalse);
      }
    });

    test('cakupan: semua vs bagian terpilih', () async {
      final lock = AppLock();
      await lock.load();
      await lock.setPin('123456');
      await lock.setAreas({LockArea.finance, LockArea.wallet});
      await lock.setScope(LockScope.selected);
      lock.lockNow();

      expect(lock.requiresAuth(LockArea.finance), isTrue);
      expect(lock.requiresAuth(LockArea.wallet), isTrue);
      expect(lock.requiresAuth(LockArea.agenda), isFalse);
      expect(lock.lockedAtLaunch, isFalse, reason: 'hanya cakupan Semua yang menutup seluruh aplikasi');

      await lock.setScope(LockScope.all);
      expect(lock.lockedAtLaunch, isTrue);
      expect(lock.requiresAuth(LockArea.agenda), isTrue);

      await lock.verifyPin('123456');
      expect(lock.lockedAtLaunch, isFalse);
      expect(lock.requiresAuth(LockArea.finance), isFalse, reason: 'sekali dibuka, terbuka untuk sesi ini');
    });

    test('kode disimpan sebagai hash bergaram dan tetap berlaku setelah dimuat ulang', () async {
      final lock = AppLock();
      await lock.load();
      await lock.setPin('482910');
      final db = DatabaseHelper.instance;
      final hash = await db.getSetting('auth.pinHash');
      expect(hash, isNot(contains('482910')));
      expect(await db.getSetting('auth.pinSalt'), isNotEmpty);

      final reloaded = AppLock();
      await reloaded.load();
      expect(await reloaded.verifyPin('000000'), isFalse);
      expect(await reloaded.verifyPin('482910'), isTrue);
    });

    test('lima kali salah mengunci kode sementara, makin lama tiap kesalahan berikutnya', () async {
      var now = DateTime(2026, 11, 15, 10);
      final lock = AppLock()..clock = () => now;
      await lock.load();
      await lock.setPin('111111');

      for (var i = 0; i < 4; i++) {
        expect(await lock.verifyPin('999999'), isFalse);
      }
      expect(lock.attemptsLeft, 1);
      expect(lock.lockoutRemaining, isNull);

      expect(await lock.verifyPin('999999'), isFalse);
      expect(lock.lockoutRemaining, AppLock.lockoutStep);
      expect(await lock.verifyPin('111111'), isFalse, reason: 'kode benar pun ditolak selama dikunci');

      now = now.add(const Duration(seconds: 31));
      expect(await lock.verifyPin('999999'), isFalse);
      expect(lock.lockoutRemaining, AppLock.lockoutStep * 2);

      now = now.add(const Duration(minutes: 2));
      expect(await lock.verifyPin('111111'), isTrue);
      expect(lock.attemptsLeft, AppLock.maxAttempts, reason: 'hitungan salah direset');
    });

    test('terkunci lagi hanya bila ditinggal lebih dari batas waktu', () async {
      var now = DateTime(2026, 11, 15, 10);
      final lock = AppLock()..clock = () => now;
      await lock.load();
      await lock.setPin('111111');
      await lock.setScope(LockScope.all);
      expect(lock.isUnlocked, isTrue);

      lock.onBackgrounded();
      now = now.add(const Duration(seconds: 30));
      lock.onResumed();
      expect(lock.isUnlocked, isTrue);

      lock.onBackgrounded();
      now = now.add(AppLock.relockAfter);
      lock.onResumed();
      expect(lock.isUnlocked, isFalse);
    });

    test('biometrik hanya dipakai bila diaktifkan', () async {
      final bio = FakeBiometrics();
      final lock = AppLock(biometrics: bio);
      await lock.load();
      await lock.setPin('111111');
      await lock.setScope(LockScope.all);
      lock.lockNow();

      expect(await lock.unlockWithBiometrics('uji'), isFalse);
      expect(bio.prompts, 0);

      await lock.setBiometric(true);
      bio.succeeds = false;
      expect(await lock.unlockWithBiometrics('uji'), isFalse);
      expect(lock.isUnlocked, isFalse);
      bio.succeeds = true;
      expect(await lock.unlockWithBiometrics('uji'), isTrue);
      expect(lock.isUnlocked, isTrue);
    });
  });

  group('layar kunci', () {
    Future<AppLock> lockWith(WidgetTester tester, LockScope scope, {Set<LockArea> areas = const {}, BiometricAuth? bio}) async {
      late AppLock lock;
      await tester.runAsync(() async {
        lock = AppLock(biometrics: bio ?? FakeBiometrics(available: false));
        await lock.load();
        await lock.setPin('246810');
        await lock.setAreas(areas);
        await lock.setScope(scope);
        lock.lockNow();
      });
      return lock;
    }

    Future<void> typePin(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      // Kode diperiksa sesaat setelah digit terakhir; pemeriksaannya membaca
      // database, jadi perlu waktu nyata.
      await tester.pump(const Duration(milliseconds: 150));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Widget app(AppLock lock, Widget home) => ChangeNotifierProvider.value(
          value: lock,
          child: MaterialApp(theme: buildAppTheme(AppColors.light), builder: (context, child) => AppLockOverlay(child: child!), home: home),
        );

    testWidgets('cakupan Semua menutup aplikasi sampai kode benar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final lock = await lockWith(tester, LockScope.all);
      await tester.pumpWidget(app(lock, const Scaffold(body: Text('isi aplikasi'))));

      expect(find.text('GroU terkunci'), findsOneWidget);
      expect(find.text('isi aplikasi').hitTestable(), findsNothing, reason: 'isi tidak bisa disentuh selama terkunci');

      await typePin(tester, '111111');
      expect(find.textContaining('Kode salah'), findsOneWidget);
      expect(find.text('GroU terkunci'), findsOneWidget);

      await typePin(tester, '246810');
      expect(find.text('GroU terkunci'), findsNothing);
      expect(find.text('isi aplikasi').hitTestable(), findsOneWidget);
    });

    testWidgets('biometrik ditawarkan otomatis dan membuka kunci', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final bio = FakeBiometrics();
      final lock = await lockWith(tester, LockScope.all, bio: bio);
      await tester.runAsync(() => lock.setBiometric(true));
      await tester.pumpWidget(app(lock, const Scaffold(body: Text('isi aplikasi'))));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(bio.prompts, 1);
      expect(find.text('GroU terkunci'), findsNothing);
    });

    testWidgets('bagian terpilih: hanya bagian itu yang tertutup, lalu dibuka dengan kode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final lock = await lockWith(tester, LockScope.selected, areas: {LockArea.agenda});
      await tester.pumpWidget(app(
        lock,
        const Scaffold(
          body: Column(children: [
            Expanded(child: LockedArea(area: LockArea.agenda, child: Text('isi agenda'))),
            Expanded(child: LockedArea(area: LockArea.target, child: Text('isi target'))),
          ]),
        ),
      ));

      expect(find.text('GroU terkunci'), findsNothing);
      expect(find.text('Agenda terkunci'), findsOneWidget);
      expect(find.text('isi target'), findsOneWidget, reason: 'Target tidak dipilih');

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      await typePin(tester, '246810');
      expect(find.text('isi agenda'), findsOneWidget);
    });

    testWidgets('membuat kode: harus diketik sama dua kali', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppLock lock;
      await tester.runAsync(() async {
        lock = AppLock();
        await lock.load();
      });
      bool? created;
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: lock,
        child: MaterialApp(
          theme: buildAppTheme(AppColors.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () async => created = await showCreatePinScreen(context), child: const Text('mulai')),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mulai'));
      await tester.pumpAndSettle();

      await typePin(tester, '135790');
      expect(find.text('Ketik ulang kode'), findsOneWidget);
      await typePin(tester, '135799');
      expect(find.textContaining('tidak sama'), findsOneWidget);
      expect(lock.hasPin, isFalse);

      await typePin(tester, '135790');
      await typePin(tester, '135790');
      expect(created, isTrue);
      expect(lock.hasPin, isTrue);
      expect(await tester.runAsync(() => lock.verifyPin('135790')), isTrue);
    });
  });
}
