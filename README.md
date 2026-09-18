# Jadwal Harian (Daily Track)

Aplikasi Flutter personal untuk melacak kedisiplinan menjalankan jadwal harian (format 24 jam).
Tampilan mengikuti desain "Daily Track" (handoff dari claude.ai/design); isi kontennya (template
23 kegiatan & daftar alasan pembatalan) sesuai spesifikasi tertulis.

## Fitur

- **Hari Ini** — timeline vertikal dari satu template kegiatan tetap (di-*seed* statis di
  `lib/data/seed_activities.dart`), dengan chip hari beruntun dan kartu progres (selesai /
  terlambat / dibatalkan).
- **Tampilan default polos** — kartu kegiatan tampil apa adanya. Tombol **Batalkan** dan **Tandai
  selesai** hanya muncul pada kegiatan yang jam WIB-nya sedang berjalan (di dalam rentang
  mulai–selesai); kegiatan lain tetap bisa ditandai lewat lingkaran centang di kanan kartu.
- **Tandai selesai** — status ditentukan otomatis: *selesai tepat waktu*, atau *terlambat* bila
  ditandai lebih dari 35 menit (`ScheduleProvider.toleranceMinutes`) setelah rentang waktunya
  **usai**.
- **Waktu Indonesia Barat** — seluruh perhitungan (jendela aktif, keterlambatan, tanggal log,
  streak, statistik) memakai WIB/UTC+7 lewat `lib/utils/wib.dart`, bukan zona waktu perangkat.
- **Batalkan kegiatan** — bottom sheet memilih alasan singkat (chip) termasuk opsi teks bebas
  ("Lainnya"), tercatat ke riwayat dengan tanggal & jam.
- **Kalender** — grid bulanan dengan titik status per hari (sempurna / ada terlambat / ada
  pembatalan) plus log pembatalan terakhir per hari.
- **Statistik** — ring disiplin mingguan, grafik batang per hari, peringkat alasan pembatalan
  paling sering, dan catatan otomatis (kegiatan yang paling sering dibatalkan).
- **Pengaturan** — info template (tetap, tidak diedit lewat UI sesuai spesifikasi), info jendela
  toleransi terlambat, dan preferensi pengingat (toggle lokal, belum terhubung ke notifikasi push
  sungguhan).
- **Notifikasi** — feed dibangun dari log aktivitas nyata (bukan data contoh).
- Data disimpan lokal dengan `sqflite`, tanpa backend.

## Struktur kode

```
lib/
  data/seed_activities.dart      # template 23 kegiatan tetap (hardcoded) + daftar alasan batal
  models/                        # Activity, DailyLog (status: done/late/cancelled)
  db/database_helper.dart        # akses sqflite
  providers/schedule_provider.dart   # state management (Provider/ChangeNotifier), statistik & kalender
  screens/
    shell_screen.dart            # app bar + bottom nav 4 tab
    home_tab.dart                # Hari Ini
    calendar_tab.dart            # Kalender
    stats_tab.dart                # Statistik
    settings_tab.dart            # Pengaturan
    notification_feed_screen.dart
  widgets/                       # ActivityTile, dialog alasan batal, ring chart
  theme/app_theme.dart           # palet & tema persis dari desain
  utils/wib.dart                 # helper waktu WIB (UTC+7)
```

## Menjalankan

Repo ini berisi kode Dart/Flutter (`lib/`, `pubspec.yaml`) tanpa folder platform native
(`android/`, `ios/`), karena dibuat tanpa Flutter SDK terpasang di lingkungan pengembangan ini.
Untuk menjalankan di perangkat:

```bash
flutter create .        # membangkitkan folder android/ dan ios/ di sekitar lib/ yang sudah ada
flutter pub get
flutter run
```

Locale tanggal Indonesia (`id_ID`) diinisialisasi otomatis saat aplikasi start.
