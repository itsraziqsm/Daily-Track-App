# Jadwal Harian

Aplikasi Flutter personal untuk melacak kedisiplinan menjalankan jadwal harian (format 24 jam).

## Fitur

- **Jadwal Harian (Home)** — timeline vertikal ala agenda kertas dari satu template kegiatan tetap (di-*seed* statis di `lib/data/seed_activities.dart`), dengan progres selesai/total di bagian atas.
- **Tandai selesai / lewati** — setiap kegiatan bisa ditandai selesai, atau dilewati dengan memilih alasan singkat (chip) termasuk opsi teks bebas ("Lainnya").
- **Riwayat** — daftar kegiatan yang pernah dilewati, terbaru dulu, dengan filter per kegiatan dan per alasan, plus ringkasan kegiatan & alasan yang paling sering muncul.
- Data disimpan lokal dengan `sqflite`, tanpa backend.

## Struktur kode

```
lib/
  data/seed_activities.dart     # template 23 kegiatan tetap (hardcoded) + daftar alasan skip
  models/                       # Activity, DailyLog
  db/database_helper.dart       # akses sqflite
  providers/schedule_provider.dart  # state management (Provider/ChangeNotifier)
  screens/                      # HomeScreen, HistoryScreen
  widgets/                      # ActivityTile, dialog alasan skip
  theme/app_theme.dart          # palet & tema minimalis
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
