import '../models/activity.dart';

/// Kategori kegiatan.
class Categories {
  static const ibadahDiri = 'Ibadah & Diri';
  static const istirahatOlahraga = 'Istirahat/Olahraga';
  static const kerjaBelajar = 'Kerja/Belajar';
  static const tidur = 'Tidur';
}

/// Template jadwal harian tetap (hardcoded, satu-satunya template).
const List<Activity> seedActivities = [
  Activity(id: 1, startTime: '04.30', endTime: '04.40', title: 'Bangun tidur & membasuh diri', category: Categories.ibadahDiri),
  Activity(id: 2, startTime: '04.40', endTime: '05.00', title: 'Sholat Subuh / refleksi pagi', category: Categories.ibadahDiri),
  Activity(id: 3, startTime: '05.00', endTime: '05.50', title: 'Olahraga ringan', category: Categories.istirahatOlahraga),
  Activity(id: 4, startTime: '05.50', endTime: '06.10', title: 'Sarapan', category: Categories.ibadahDiri),
  Activity(id: 5, startTime: '06.10', endTime: '06.45', title: 'Mandi', category: Categories.ibadahDiri),
  Activity(id: 6, startTime: '06.45', endTime: '07.15', title: 'Bersiap diri (motor, periksa barang bawaan)', category: Categories.ibadahDiri),
  Activity(id: 7, startTime: '07.15', endTime: '07.35', title: 'Waktu luang', category: Categories.istirahatOlahraga),
  Activity(id: 8, startTime: '07.35', endTime: '08.00', title: 'Perjalanan ke kampus', category: Categories.kerjaBelajar),
  Activity(id: 9, startTime: '08.00', endTime: '12.30', title: 'Kuliah', category: Categories.kerjaBelajar),
  Activity(id: 10, startTime: '12.30', endTime: '13.00', title: 'Sholat Dzuhur & makan siang', category: Categories.ibadahDiri),
  Activity(id: 11, startTime: '13.00', endTime: '15.00', title: 'Sesi belajar mandiri / tugas', category: Categories.kerjaBelajar),
  Activity(id: 12, startTime: '15.00', endTime: '15.45', title: 'Sholat Ashar & waktu luang', category: Categories.ibadahDiri),
  Activity(id: 13, startTime: '15.45', endTime: '16.50', title: 'Lanjutan belajar / tugas', category: Categories.kerjaBelajar),
  Activity(id: 14, startTime: '16.50', endTime: '17.30', title: 'Olahraga sore', category: Categories.istirahatOlahraga),
  Activity(id: 15, startTime: '17.30', endTime: '18.00', title: 'Mandi', category: Categories.ibadahDiri),
  Activity(id: 16, startTime: '18.00', endTime: '18.15', title: 'Sholat Maghrib', category: Categories.ibadahDiri),
  Activity(id: 17, startTime: '18.15', endTime: '18.45', title: 'Family time', category: Categories.istirahatOlahraga),
  Activity(id: 18, startTime: '18.45', endTime: '19.15', title: 'Makan malam', category: Categories.ibadahDiri),
  Activity(id: 19, startTime: '19.15', endTime: '19.30', title: 'Sholat Isya', category: Categories.ibadahDiri),
  Activity(id: 20, startTime: '19.30', endTime: '20.30', title: 'Membaca buku', category: Categories.kerjaBelajar),
  Activity(id: 21, startTime: '20.30', endTime: '21.00', title: 'Evaluasi hari ini & rencana besok', category: Categories.kerjaBelajar),
  Activity(id: 22, startTime: '21.00', endTime: '22.00', title: 'Waktu tenang tanpa gadget, bersiap tidur', category: Categories.tidur),
  Activity(id: 23, startTime: '22.00', endTime: '04.30', title: 'Tidur', category: Categories.tidur),
];

/// Daftar alasan skip/batal yang bisa dipilih user.
const List<String> skipReasons = [
  'Sakit',
  'Darurat keluarga',
  'Tugas/deadline mendadak',
  'Kondisi di luar kendali (macet, listrik/air mati, dll)',
  'Mengejar pekerjaan lain',
  'Kegiatan pengganti (mis. olahraga non-rutin)',
  'Lainnya',
];
