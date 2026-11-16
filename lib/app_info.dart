/// Versi aplikasi, disalin dari `version:` di pubspec.yaml (test
/// `app_info_test.dart` memastikan keduanya sama).
///
/// Ditulis di kode Dart, bukan dibaca dari paket Android, supaya angka yang
/// tampil di Pengaturan membuktikan kode Dart terbaru benar-benar ikut
/// terkompilasi ke APK.
const appVersion = '1.2.2';
const appBuild = 4;
