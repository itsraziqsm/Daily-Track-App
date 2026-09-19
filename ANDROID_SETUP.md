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

## Izin sudah diberi, tapi tidak ada notifikasi yang masuk

Buka **Pengaturan → Pengingat → Tes notifikasi → Kirim**. Itu mengirim dua
notifikasi lewat dua jalur berbeda, dan bedanya menunjukkan di mana rantainya
putus:

| Yang muncul | Artinya | Perbaikannya |
|---|---|---|
| Tidak ada sama sekali | Izin atau channel bermasalah | Cek izin notifikasi aplikasi di pengaturan sistem |
| Hanya yang pertama (seketika) | Jalur alarm putus | Hampir pasti **receiver belum ada di AndroidManifest** — lihat bagian 1 di atas |
| Keduanya muncul | Rantainya sehat | Pengingatnya memang belum jatuh tempo, atau ditahan manajemen baterai |

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

**Jumlah terjadwal.** Baris "Tes notifikasi" menampilkan berapa notifikasi yang
benar-benar tersimpan di antrean sistem. Kalau angkanya 0 padahal toggle
menyala, penjadwalannya yang gagal, bukan pengirimannya.

**Waktu jatuh tempo.** Pengingat kegiatan muncul 10 menit sebelum jam mulai,
ringkasan pagi 06:00, ringkasan malam 21:30 — tidak ada yang langsung muncul
begitu toggle dinyalakan.

## Catatan perilaku

- Penjadwalan memakai **alarm presis** (`AndroidScheduleMode.exactAllowWhileIdle`),
  karena pengingat "10 menit sebelum mulai" kehilangan gunanya kalau digeser
  Doze berjam-jam. Kalau sistem menolak izin alarm presis, kode otomatis turun
  ke mode inexact alih-alih gagal seluruhnya, dan baris "Tes notifikasi" di
  Pengaturan menandainya.
- Jam pengingat dihitung pada zona waktu yang dipilih di aplikasi (WIB/WITA/WIT),
  lalu dikonversi ke instan UTC. Jadi pengingat tetap jatuh pada jam yang benar
  meskipun zona waktu perangkat berbeda.
- Mengganti template, zona waktu, atau toggle akan menjadwal ulang semuanya.
