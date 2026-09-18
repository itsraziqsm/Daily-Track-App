# Jadwal Harian (Daily Track)

Aplikasi Flutter personal untuk melacak kedisiplinan menjalankan jadwal harian (format 24 jam).
Tampilan mengikuti desain "Daily Track" (handoff dari claude.ai/design); isi kontennya (template
23 kegiatan & daftar alasan pembatalan) sesuai spesifikasi tertulis.

## Fitur

- **Hari Ini** — timeline vertikal dari satu template kegiatan tetap (di-*seed* statis di
  `lib/data/seed_activities.dart`), dengan chip hari beruntun dan kartu progres (selesai /
  terlambat / dibatalkan). Header dan kartu progres diam; hanya daftar kegiatan yang bergulir.
- **Navigasi** — empat tab ikon di bawah, bisa diketuk atau digeser kanan-kiri.
- **Tampilan default polos** — kartu kegiatan tampil apa adanya. Tombol **Batalkan** dan **Tandai
  selesai** hanya muncul pada kegiatan yang jamnya sedang berjalan (di dalam rentang
  mulai–selesai); kegiatan lain tetap bisa ditandai lewat lingkaran centang di kanan kartu.
- **Tandai selesai** — status ditentukan otomatis: *selesai tepat waktu*, atau *terlambat* bila
  ditandai lebih dari 35 menit (`ScheduleProvider.toleranceMinutes`) setelah rentang waktunya
  **usai**.
- **Zona waktu bisa dipilih** — WIB / WITA / WIT, diatur lewat Pengaturan → Zona waktu dan
  tersimpan di database. Seluruh perhitungan (jendela aktif, keterlambatan, tanggal log, streak,
  statistik) memakai zona itu lewat `lib/utils/app_time.dart`, bukan zona waktu perangkat.
  Ketiganya offset tetap dan Indonesia tanpa DST, jadi tidak perlu basis data zona waktu IANA.
- **Catatan terkunci** — kegiatan yang sudah ditandai dan sudah lewat 35 menit setelah rentangnya
  usai tidak bisa diubah lagi.
- **Batalkan kegiatan** — bottom sheet memilih alasan singkat (chip) termasuk opsi teks bebas
  ("Lainnya"), tercatat ke riwayat dengan tanggal & jam.
- **Kalender** — grid bulanan dengan titik status per hari (sempurna / ada terlambat / ada
  pembatalan) plus log pembatalan terakhir per hari.
- **Statistik** — ring disiplin mingguan, grafik batang per hari, peringkat alasan pembatalan
  paling sering, dan catatan otomatis (kegiatan yang paling sering dibatalkan).
- **Pengaturan** — info template (tetap, tidak diedit lewat UI sesuai spesifikasi), info jendela
  toleransi terlambat, dan preferensi pengingat (toggle lokal, belum terhubung ke notifikasi push
  sungguhan).
- **Notifikasi** — feed dibangun dari log aktivitas nyata (bukan data contoh). App bar hanya
  memuat tombol lonceng ini, tanpa border.
- **Ikon Lucide** — seluruh ikon memakai `lucide_icons_flutter`, yang membundel `lucide.ttf`
  sebagai aset paket sehingga tidak ada pengambilan dari CDN saat aplikasi berjalan.
- **Tipografi tanpa CDN** — tiga famili huruf dibundel lokal di `assets/fonts/`: **Bricolage
  Grotesque** untuk judul, **Schibsted Grotesk** untuk label & keterangan, dan **Onest** untuk
  sisanya (lihat `AppFonts` di `lib/theme/app_theme.dart`). Paket `google_fonts` sudah dilepas
  karena mengunduh font saat runtime.
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
  utils/app_time.dart            # zona waktu aktif (WIB/WITA/WIT) & helper waktu
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
