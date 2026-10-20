# GroU

Aplikasi Flutter personal untuk melacak kedisiplinan menjalankan jadwal harian (format 24 jam).
Tampilan mengikuti desain "Daily Track" (handoff dari claude.ai/design); isi template bawaan
(23 kegiatan) dan daftar alasan pembatalan sesuai spesifikasi tertulis.

## Fitur

- **Hari Ini** — timeline vertikal dari template yang berlaku untuk hari itu. Headernya menempel
  (`SliverPersistentHeader`): saat daftar digulung, tanggal dan chip hari beruntun melipat hingga
  tersisa kartu progresnya saja, dan kegiatan lewat di belakangnya dengan bayangan tipis.
- **Navigasi** — empat tab ikon di bawah (Hari Ini, Agenda, Target, Pengaturan), bisa diketuk
  atau digeser kanan-kiri.
- **Tampilan default polos** — kartu kegiatan tampil apa adanya. Tombol **Batalkan** dan **Tandai
  selesai** hanya muncul pada kegiatan yang jamnya sedang berjalan (di dalam rentang
  mulai–selesai); kegiatan lain tetap bisa ditandai lewat lingkaran centang di kanan kartu.
- **Tandai selesai** — status ditentukan otomatis: *selesai tepat waktu*, atau *terlambat* bila
  ditandai lebih lama dari jendela toleransi setelah rentang waktunya **usai**. Toleransinya
  bisa diatur di Pengaturan → Aturan pelacakan (0 mnt–2 jam, bawaan 35 mnt) dan tersimpan di
  database; status yang sudah tercatat tidak dihitung ulang.
- **Ikon & layar pembuka GroU** — ikon launcher (termasuk adaptif Android) dan splash native
  dibangkitkan dari `assets/branding/` lewat `flutter_launcher_icons` dan
  `flutter_native_splash`. Begitu Flutter siap, `LaunchSplash` melanjutkan dari frame yang sama:
  logo melambung kecil lalu memudar ke layar Hari Ini (dipersingkat bila animasi sistem
  dimatikan).
- **Mode terang & gelap** — Pengaturan → Tampilan → Tema: *Ikuti sistem*, *Terang*, atau
  *Gelap*, tersimpan di database dan dibaca sebelum frame pertama supaya tidak berkedip. Palet
  (`AppColors` di `lib/theme/app_theme.dart`) adalah `ThemeExtension` dengan varian `light`
  (persis desain) dan `dark` (cokelat hangat gelap, aksen kuning/oranye tetap); widget
  mengambilnya lewat `AppColors.of(context)`, jadi tidak ada warna hex yang ditulis langsung di
  layar.
- **Zona waktu bisa dipilih** — WIB / WITA / WIT, diatur lewat Pengaturan → Zona waktu dan
  tersimpan di database. Seluruh perhitungan (jendela aktif, keterlambatan, tanggal log, streak,
  statistik) memakai zona itu lewat `lib/utils/app_time.dart`, bukan zona waktu perangkat.
  Ketiganya offset tetap dan Indonesia tanpa DST, jadi tidak perlu basis data zona waktu IANA.
- **Guard status** — kegiatan yang jam mulainya belum tiba tidak bisa dicentang; kegiatan
  berstatus *terlambat* langsung final (tanpa ini, mencabut centang lalu menandai ulang akan
  menghapus keterlambatannya); dan catatan yang sudah lewat jendela toleransi dari akhir rentang juga
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
- **Agenda** *(in development)* — grid bulanan dengan titik status per hari (sempurna / ada
  terlambat / ada pembatalan) dipertahankan sebagai kerangka; fitur agendanya sendiri belum ada.
- **Target** *(in development)* — baru berupa halaman penanda.
- **Pengaturan → Lainnya**
  - **Statistik** — ring disiplin mingguan, grafik batang per hari, peringkat alasan pembatalan
    paling sering, dan catatan otomatis (kegiatan yang paling sering dibatalkan).
  - **Log pembatalan** — semua pembatalan dalam daftar, dikelompokkan per hari: hari terbaru
    terbuka, sisanya terlipat.
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
    agenda_tab.dart              # Agenda (in development, grid kalender)
    target_tab.dart              # Target (in development)
    stats_screen.dart            # Pengaturan → Lainnya → Statistik
    cancellation_log_screen.dart # Pengaturan → Lainnya → Log pembatalan
    settings_tab.dart            # Pengaturan
    notification_feed_screen.dart
  widgets/                       # ActivityTile, sheet alasan batal / zona waktu / tema, ring chart
  theme/app_theme.dart           # palet terang & gelap (ThemeExtension) dan ThemeData
  services/notification_service.dart  # notifikasi lokal terjadwal
  utils/app_time.dart            # zona waktu aktif (WIB/WITA/WIT) & helper waktu
assets/branding/                 # logo GroU + turunannya untuk ikon & splash
tool/brand_assets.py             # membangkitkan turunan logo dari grou_source.png
```

## Menjalankan

Repo ini berisi kode Dart/Flutter (`lib/`, `pubspec.yaml`) tanpa folder platform native
(`android/`), karena dibuat tanpa Flutter SDK terpasang di lingkungan pengembangan ini.
Untuk menjalankan di perangkat:

```bash
flutter create --platforms=android .   # membangkitkan folder android/ di sekitar lib/ yang sudah ada
flutter pub get
flutter run
```

Nama yang tampil di launcher diatur di proyek native; lihat bagian "Nama aplikasi" di
`ANDROID_SETUP.md`, termasuk cara memberi nama file APK `GroU.apk`.

### Test

```bash
flutter test                                                   # semua layar, terang & gelap
flutter test --update-goldens --dart-define=SCREENSHOTS=true   # + tangkapan layar ke test/screenshots/
```

`test/theme_screens_test.dart` menggambar tiap layar dan sheet dengan data nyata (sqflite lewat
FFI) di kedua mode dan gagal bila ada overflow atau exception layout.

Locale tanggal Indonesia (`id_ID`) diinisialisasi otomatis saat aplikasi start.
