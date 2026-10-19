# Setup Android untuk notifikasi

Folder `android/` tidak ikut di repo ini (dibangkitkan lokal lewat `flutter create .`),
jadi tiga penyesuaian di bawah perlu ditambahkan sekali di proyek Android kamu agar
notifikasi terjadwal benar-benar jalan. Tanpa ini aplikasi tetap bisa dibuka, tapi
izin tidak akan diminta dan pengingat tidak muncul.

## 1. `android/app/src/main/AndroidManifest.xml`

Tambahkan izin di dalam `<manifest>`, **di luar** `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

Lalu tambahkan dua receiver di dalam `<application>`, supaya jadwal dipasang ulang
setelah perangkat dinyalakan ulang atau aplikasi diperbarui:

```xml
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

## 2. `android/app/build.gradle` (atau `build.gradle.kts`)

`flutter_local_notifications` memerlukan *core library desugaring*:

```gradle
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

Versi Kotlin DSL (`build.gradle.kts`):

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Pastikan `minSdk` minimal 21.

## 3. Nama aplikasi "GroU"

Nama paket Dart sudah `grou`, jadi `flutter create .` pada folder kosong membuat
`applicationId` `com.example.grou`. Ganti `--org` kalau mau ID sendiri:

```bash
flutter create --org com.namakamu --platforms=android,ios .
```

Nama di bawah ikon launcher diatur terpisah. Di
`android/app/src/main/AndroidManifest.xml`, ubah atribut `android:label` pada
`<application>`:

```xml
<application
    android:label="GroU"
    ...>
```

(iOS: `CFBundleDisplayName` di `ios/Runner/Info.plist` → `GroU`.)

Kalau folder `android/` sudah pernah dibangkitkan dengan nama lama, cukup ganti
label di atas — `applicationId` lama boleh dibiarkan supaya aplikasi yang sudah
terpasang (beserta datanya) diperbarui, bukan dipasang sebagai aplikasi baru.

### Ikon dan layar pembuka

Ikon launcher dan splash native dibangkitkan dari logo GroU di
`assets/branding/` (konfigurasinya di bagian bawah `pubspec.yaml`). Jalankan
sekali setelah `flutter create .`, dan ulangi kalau logonya diganti:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Yang dihasilkan:

- **Ikon**: ilustrasi tanpa tulisan (huruf "GroU" tidak terbaca di ukuran ikon)
  di atas latar krem, termasuk ikon adaptif Android 8+ dan ikon iOS.
- **Splash native**: logo lengkap di tengah dengan latar sewarna aplikasi, versi
  terang dan gelap mengikuti mode sistem. Di Android 12+ sistem hanya
  mengizinkan ikon dalam lingkaran, jadi yang tampil ilustrasinya saja.

Setelah splash native, `LaunchSplash` di aplikasi melanjutkan dari frame yang
sama: logonya melambung kecil lalu memudar ke layar Hari Ini.

Kalau logo sumbernya diganti, simpan di `assets/branding/grou_source.png` lalu
bangkitkan ulang turunannya (butuh Pillow, numpy, scipy) sebelum dua perintah
di atas:

```bash
python3 tool/brand_assets.py assets/branding/grou_source.png assets/branding
```

### Nama file APK

File APK hasil build Flutter selalu bernama `app-release.apk`. Untuk installer
bernama GroU, salin setelah build:

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk GroU.apk
```

## 4. Setelah itu

```bash
flutter clean
flutter pub get
flutter run
```

Dialog izin muncul saat pertama kali menyalakan salah satu toggle di
**Pengaturan → Pengingat**, bukan saat aplikasi dibuka.

## Kalau muncul `MissingPluginException`

```
MissingPluginException(No implementation found for method initialize
on channel dexterous.com/flutter/local_notifications)
```

Artinya sisi native plugin belum ikut terpasang di aplikasi yang sedang berjalan.
Hampir selalu penyebabnya **hot reload/hot restart setelah menambah plugin baru** —
keduanya hanya menukar kode Dart, sedangkan plugin butuh build ulang penuh.

Hentikan aplikasi sepenuhnya (bukan hot restart), lalu:

```bash
flutter clean
flutter pub get
flutter run
```

Kalau masih muncul setelah build bersih, periksa `android/app/src/main/AndroidManifest.xml`
sudah memuat kedua `<receiver>` di atas, dan `flutter doctor` tidak melaporkan masalah
pada toolchain Android.

Aplikasi sendiri tidak ikut gagal kalau ini terjadi: notifikasi dimatikan diam-diam,
sisanya (jadwal, template, statistik) tetap berjalan, dan toggle pengingat akan
memberi tahu bahwa notifikasi belum aktif di build tersebut.

## Izin sudah diberi, tapi tidak ada notifikasi yang masuk

**Receiver adalah penyebab paling sering.** Manifest milik plugin hanya
mendeklarasikan izin, **bukan** receiver-nya — jadi `ScheduledNotificationReceiver`
wajib ditulis sendiri di `android/app/src/main/AndroidManifest.xml`. Tanpa itu
alarm tetap menyala tapi tidak ada yang memasang notifikasinya, dan tidak ada
pesan error apa pun. Pastikan kedua `<receiver>` di bagian 1 benar-benar ada di
dalam `<application>`.

**Manajemen baterai pabrikan.** Xiaomi/POCO (MIUI), Oppo/Realme (ColorOS),
Vivo (Funtouch), dan Samsung (One UI) mematikan alarm terjadwal secara agresif.
Di pengaturan sistem, untuk aplikasi ini aktifkan **Autostart** dan setel
baterai ke **Tidak dibatasi / No restrictions**.

**Waktu jatuh tempo.** Pengingat kegiatan muncul 10 menit sebelum jam mulai,
ringkasan pagi 06:00, ringkasan malam 21:30 — tidak ada yang langsung muncul
begitu toggle dinyalakan.

## Catatan perilaku

- Penjadwalan memakai **alarm presis** (`AndroidScheduleMode.exactAllowWhileIdle`),
  karena pengingat "10 menit sebelum mulai" kehilangan gunanya kalau digeser
  Doze berjam-jam. Kalau sistem menolak izin alarm presis, kode otomatis turun
  ke mode inexact alih-alih gagal seluruhnya.
- Jam pengingat dihitung pada zona waktu yang dipilih di aplikasi (WIB/WITA/WIT),
  lalu dikonversi ke instan UTC. Jadi pengingat tetap jatuh pada jam yang benar
  meskipun zona waktu perangkat berbeda.
- Mengganti template, zona waktu, atau toggle akan menjadwal ulang semuanya.
