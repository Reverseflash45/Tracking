/// Rutinitas berkala: hal yang diulang tiap beberapa hari sejak terakhir
/// dilakukan — absen akun tiap 25 hari, ganti sprei tiap 14 hari.
///
/// Bedanya dengan rutinitas mingguan: jadwalnya tidak menempel ke nama hari.
/// Titik mulainya bergeser tiap kali kamu menandainya selesai, jadi telat tiga
/// hari berarti jatuh tempo berikutnya ikut mundur tiga hari — sama seperti
/// hitungan di layanan yang akunnya kamu jaga.
library;

import 'dart:math';

DateTime _hari(DateTime date) => DateTime(date.year, date.month, date.day);

/// Pilihan cepat di form. 25 ikut karena memang itu alasan fitur ini dibuat.
const List<int> kPilihanJarakHari = [7, 14, 25, 30, 90];

class RutinitasBerkala {
  const RutinitasBerkala({
    required this.id,
    required this.userId,
    required this.title,
    required this.intervalDays,
    required this.lastDoneOn,
    this.remindAt,
    this.note,
  });

  final String id;
  final String userId;
  final String title;

  /// Jarak antar pelaksanaan, dalam hari.
  final int intervalDays;

  /// Tanggal (tanpa jam) terakhir kali dilakukan.
  final DateTime lastDoneOn;

  /// 'HH:mm:ss'. Null berarti ikut jam pengingat umum.
  final String? remindAt;

  final String? note;

  /// Tanggal jatuh tempo berikutnya.
  DateTime get jatuhTempo => _hari(lastDoneOn).add(Duration(days: intervalDays));

  /// Hari tersisa sampai jatuh tempo. 0 = hari ini, negatif = sudah telat.
  int sisaHari(DateTime now) => jatuhTempo.difference(_hari(now)).inDays;

  /// Sudah waktunya dikerjakan: jatuh tempo hari ini atau sudah lewat.
  bool perluDikerjakan(DateTime now) => sisaHari(now) <= 0;

  /// Seberapa jauh dari terakhir dilakukan menuju jatuh tempo, 0..1.
  double kemajuan(DateTime now) {
    final berlalu = _hari(now).difference(_hari(lastDoneOn)).inDays;
    return (berlalu / intervalDays).clamp(0.0, 1.0);
  }

  RutinitasBerkala copyWith({DateTime? lastDoneOn}) => RutinitasBerkala(
        id: id,
        userId: userId,
        title: title,
        intervalDays: intervalDays,
        lastDoneOn: lastDoneOn ?? this.lastDoneOn,
        remindAt: remindAt,
        note: note,
      );

  factory RutinitasBerkala.fromMap(Map<String, dynamic> map) => RutinitasBerkala(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        intervalDays: map['interval_days'] as int,
        lastDoneOn: DateTime.parse(map['last_done_on'] as String),
        remindAt: map['remind_at'] as String?,
        note: map['note'] as String?,
      );
}

/// "Hari ini", "Besok", "3 hari lagi", "Telat 2 hari".
String labelSisaHari(int sisa) => switch (sisa) {
      0 => 'Hari ini',
      1 => 'Besok',
      < 0 => 'Telat ${-sisa} hari',
      _ => '$sisa hari lagi',
    };

/// Yang paling mendesak di atas: yang telat paling lama, lalu yang paling
/// dekat jatuh temponya. Judul jadi pemutus supaya urutannya tidak melompat
/// tiap kali dimuat ulang.
List<RutinitasBerkala> urutkanBerkala(List<RutinitasBerkala> semua) {
  return [...semua]..sort((a, b) {
      final tempo = a.jatuhTempo.compareTo(b.jatuhTempo);
      return tempo != 0 ? tempo : a.title.compareTo(b.title);
    });
}

/// Satu kali rutinitas berkala ditandai selesai.
class LogBerkala {
  const LogBerkala({
    required this.id,
    required this.routineId,
    required this.doneOn,
    this.dueOn,
  });

  final String id;
  final String routineId;
  final DateTime doneOn;

  /// Jatuh tempo saat itu. Null untuk catatan yang belum diproses server.
  final DateTime? dueOn;

  /// Hari telat; 0 kalau tepat waktu atau lebih awal.
  int get telatHari {
    final tempo = dueOn;
    if (tempo == null) return 0;
    final selisih = _hari(doneOn).difference(_hari(tempo)).inDays;
    return selisih > 0 ? selisih : 0;
  }

  factory LogBerkala.fromMap(Map<String, dynamic> map) => LogBerkala(
        id: map['id'] as String,
        routineId: map['routine_id'] as String,
        doneOn: DateTime.parse(map['done_on'] as String),
        dueOn: map['due_on'] == null ? null : DateTime.parse(map['due_on'] as String),
      );
}

/// UUID v4 acak. Dibuat di HP supaya catatan yang masih di antrean offline
/// sudah punya id — dan karena itu bisa dibatalkan sebelum terkirim.
String uuidBaru([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Nama tabel riwayat, dipakai juga untuk mengenali isi antrean offline.
const String kTabelLogBerkala = 'periodic_routine_logs';

/// Majukan tanggal terakhir dengan catatan yang masih tertahan di antrean
/// offline.
///
/// Tanpa ini, menekan "Sudah" tanpa sinyal tidak mengubah apa pun di layar,
/// dan pengingat telatnya tetap berbunyi — padahal kamu sudah mengerjakannya.
/// Hanya memajukan, tidak pernah memundurkan: sama dengan trigger di server.
List<RutinitasBerkala> terapkanAntrean(
  List<RutinitasBerkala> semua,
  Iterable<Map<String, dynamic>> payloadTertunda,
) {
  final terbaru = <String, DateTime>{};
  for (final p in payloadTertunda) {
    final id = p['routine_id'] as String?;
    final tanggal = DateTime.tryParse(p['done_on'] as String? ?? '');
    if (id == null || tanggal == null) continue;
    final ada = terbaru[id];
    if (ada == null || tanggal.isAfter(ada)) terbaru[id] = tanggal;
  }
  if (terbaru.isEmpty) return semua;

  return [
    for (final r in semua)
      if (terbaru[r.id] case final t? when t.isAfter(r.lastDoneOn))
        r.copyWith(lastDoneOn: t)
      else
        r,
  ];
}

/// Ringkasan riwayat untuk ditampilkan di form: berapa kali tepat waktu.
({int total, int tepat}) ringkasRiwayat(List<LogBerkala> logs) => (
      total: logs.length,
      tepat: logs.where((l) => l.telatHari == 0).length,
    );

/// Isi payload notifikasi rutinitas berkala.
///
/// Tombol "Sudah" di notifikasi berjalan tanpa membuka app — bisa jadi tanpa
/// sesi login yang siap dan tanpa data apa pun termuat. Jadi semua yang
/// dibutuhkan untuk mencatat selesai dan memasang pengingat siklus berikutnya
/// ikut dibawa di sini.
class PayloadBerkala {
  const PayloadBerkala({
    required this.routineId,
    required this.userId,
    required this.title,
    required this.intervalDays,
    required this.menitPengingat,
  });

  static const _awalan = 'berkala|';

  final String routineId;
  final String userId;
  final String title;
  final int intervalDays;

  /// Jam pengingat untuk siklus berikutnya, menit sejak tengah malam.
  final int menitPengingat;

  String encode() =>
      '$_awalan$routineId|$userId|$intervalDays|$menitPengingat|$title';

  /// Null kalau payload-nya bukan milik rutinitas berkala.
  static PayloadBerkala? decode(String? payload) {
    if (payload == null || !payload.startsWith(_awalan)) return null;
    // Judul di belakang dan diambil utuh, supaya "|" di dalam judul aman.
    final bagian = payload.substring(_awalan.length).split('|');
    if (bagian.length < 5) return null;
    final jarak = int.tryParse(bagian[2]);
    final menit = int.tryParse(bagian[3]);
    if (jarak == null || menit == null) return null;
    return PayloadBerkala(
      routineId: bagian[0],
      userId: bagian[1],
      intervalDays: jarak,
      menitPengingat: menit,
      title: bagian.sublist(4).join('|'),
    );
  }

  /// Awalan payload semua pengingat milik rutinitas [routineId].
  static String awalanUntuk(String routineId) => '$_awalan$routineId|';
}
