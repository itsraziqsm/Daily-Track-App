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

## 3. Setelah itu

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

## Catatan perilaku

- Penjadwalan memakai mode **inexact** (`AndroidScheduleMode.inexactAllowWhileIdle`),
  jadi tidak butuh persetujuan "alarm & pengingat" khusus di Android 12+ dan
  aman dari penolakan Play Store. Konsekuensinya notifikasi bisa meleset
  beberapa menit saat perangkat sedang irit daya. Kalau kamu butuh presisi
  menit, ganti ke `AndroidScheduleMode.exactAllowWhileIdle` di
  `lib/services/notification_service.dart` — izin `SCHEDULE_EXACT_ALARM` sudah
  diminta oleh kode.
- Jam pengingat dihitung pada zona waktu yang dipilih di aplikasi (WIB/WITA/WIT),
  lalu dikonversi ke instan UTC. Jadi pengingat tetap jatuh pada jam yang benar
  meskipun zona waktu perangkat berbeda.
- Mengganti template, zona waktu, atau toggle akan menjadwal ulang semuanya.
