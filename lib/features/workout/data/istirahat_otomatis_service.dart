import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/istirahat_otomatis.dart';
import 'rest_day_repository.dart';

const _aktifKey = 'istirahat_otomatis';
const _sampaiKey = 'istirahat_otomatis_sampai';

/// Setelan "hari tanpa latihan otomatis jadi istirahat". Menyala secara
/// bawaan.
class IstirahatOtomatisController extends Notifier<bool> {
  @override
  bool build() {
    _muat();
    return true;
  }

  Future<void> _muat() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_aktifKey) ?? true;
  }

  Future<void> setAktif(bool aktif) async {
    state = aktif;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aktifKey, aktif);
  }
}

final istirahatOtomatisProvider =
    NotifierProvider<IstirahatOtomatisController, bool>(IstirahatOtomatisController.new);

/// Tandai hari-hari yang lewat tanpa latihan sebagai istirahat. Dipanggil saat
/// app dibuka; mengembalikan jumlah hari yang ditandai.
///
/// Tiap hari hanya diproses sekali: tanggal terakhir yang sudah diperiksa
/// disimpan. Jadi kalau kamu menghapus satu istirahat otomatis karena memang
/// tidak mau hari itu dihitung, app tidak menambahkannya lagi besok.
Future<int> jalankanIstirahatOtomatis({
  required RestDayRepository repo,
  required String userId,
  required Iterable<DateTime> aktif,
  required Iterable<DateTime> istirahat,
  DateTime? now,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(_aktifKey) ?? true)) return 0;

  final sekarang = now ?? DateTime.now();
  final kemarin = DateTime(sekarang.year, sekarang.month, sekarang.day - 1);
  final sampai = DateTime.tryParse(prefs.getString(_sampaiKey) ?? '');
  if (sampai != null && !sampai.isBefore(kemarin)) return 0;

  final hari = hariIstirahatOtomatis(
    aktif: aktif,
    istirahat: istirahat,
    now: sekarang,
    sejak: sampai?.add(const Duration(days: 1)),
  );
  await repo.addRestDaysOtomatis(userId: userId, dates: hari);
  // Disimpan setelah berhasil saja: kalau gagal (offline), dicoba lagi nanti.
  await prefs.setString(_sampaiKey, kemarin.toIso8601String().substring(0, 10));
  return hari.length;
}
