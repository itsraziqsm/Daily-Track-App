# Jadwal Harian (Daily Track)

Aplikasi Flutter personal untuk melacak kedisiplinan menjalankan jadwal harian (format 24 jam).
Tampilan mengikuti desain "Daily Track" (handoff dari claude.ai/design); isi template bawaan
(23 kegiatan) dan daftar alasan pembatalan sesuai spesifikasi tertulis.

## Fitur

- **Hari Ini** — timeline vertikal dari template yang berlaku untuk hari itu, dengan chip hari
  beruntun dan kartu progres (selesai / terlambat / dibatalkan). Header dan kartu progres diam;
  hanya daftar kegiatan yang bergulir.
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
- **Guard status** — kegiatan yang jam mulainya belum tiba tidak bisa dicentang; kegiatan
  berstatus *terlambat* langsung final (tanpa ini, mencabut centang lalu menandai ulang akan
  menghapus keterlambatannya); dan catatan yang sudah lewat 35 menit dari akhir rentang juga
  terkunci. Ketukan yang terblokir menjelaskan alasannya lewat snackbar.
- **Batalkan lebih awal** — tahan (long-press) kartu mana pun yang belum terkunci untuk membuka
  sheet alasan, termasuk kegiatan yang belum dimulai.
- **Animasi centang** — cincin menyapu melingkar, lingkaran terisi, lalu centang digambar
  (`lib/widgets/animated_check_circle.dart`). Irama dan proporsinya diambil dari aset animasi
  yang disediakan, tapi digambar sebagai vektor agar transparan, tajam, dan ikut warna palet.
- **Data lokal** — sqflite dengan skema v3: `daily_logs`, `app_settings`, `templates`,
  `template_activities`, `day_assignments`. Migrasi dari skema lama menjaga log yang sudah ada.
- **Batalkan kegiatan** — bottom sheet memilih alasan singkat (chip) termasuk opsi teks bebas
  ("Lainnya"), tercatat ke riwayat dengan tanggal & jam.
- **Kalender** — grid bulanan dengan titik status per hari (sempurna / ada terlambat / ada
  pembatalan) plus log pembatalan terakhir per hari.
- **Statistik** — ring disiplin mingguan, grafik batang per hari, peringkat alasan pembatalan
  paling sering, dan catatan otomatis (kegiatan yang paling sering dibatalkan).
- **Template & Kelola Template** — Pengaturan menampilkan template yang aktif hari ini, dan kartu
  **Kelola Template** membuka layar untuk menyunting template, membuat yang baru, menghapus, serta
  menentukan template mana yang dipakai pada hari apa (Senin–Minggu).
- **Notifikasi sungguhan** — pengingat tiap kegiatan (10 menit sebelum mulai), ringkasan pagi
  06:00, dan ringkasan malam 21:30, lewat `flutter_local_notifications`. Izin sistem diminta saat
  toggle dinyalakan. Lihat `ANDROID_SETUP.md` untuk penyesuaian manifest yang perlu ditambahkan.
- **Feed notifikasi** — dibangun dari log aktivitas nyata (bukan data contoh). App bar hanya
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
  data/seed_activities.dart      # isi template bawaan (23 kegiatan) + daftar alasan batal
  models/                        # Activity, Template, DailyLog (status: done/late/cancelled)
  db/database_helper.dart        # akses sqflite
  providers/schedule_provider.dart   # state management (Provider/ChangeNotifier), statistik & kalender
  screens/
    shell_screen.dart            # app bar + bottom nav 4 tab (swipe antar halaman)
    manage_templates_screen.dart # daftar template + penugasan per hari
    template_editor_screen.dart  # sunting/buat template
    home_tab.dart                # Hari Ini
    calendar_tab.dart            # Kalender
    stats_tab.dart                # Statistik
    settings_tab.dart            # Pengaturan
    notification_feed_screen.dart
  widgets/                       # ActivityTile, dialog alasan batal, ring chart
  theme/app_theme.dart           # palet & tema persis dari desain
  services/notification_service.dart  # notifikasi lokal terjadwal
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
