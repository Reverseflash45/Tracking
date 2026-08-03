/// Memutuskan pengingat apa saja yang perlu dipasang, dari data yang app ini
/// memang sudah punya.
///
/// Sebelumnya penjadwal notifikasi cuma dipakai untuk satu hal: deadline tugas.
/// Padahal app sudah tahu jadwal kuliahmu, streak olahragamu, jatah istirahat
/// yang tersisa, dan tanggal jatuh tempo tagihan bulanan — semuanya menganggur.
///
/// Berkas ini sengaja tidak menyentuh plugin notifikasi sama sekali: dia hanya
/// mengubah data jadi daftar rencana, supaya bisa diuji tanpa Android.
library;

import 'package:flutter/material.dart';

import '../../features/academic/data/models/class_schedule.dart';
import '../../features/academic/data/models/task.dart';
import '../../features/academic/domain/schedule_conflict.dart' show menitDariJam;
import '../../features/document/domain/document.dart';
import '../../features/finance/domain/finance_stats.dart';
import '../../features/vehicle/domain/vehicle.dart';

/// Berapa hari sebelum deadline pengingat dikirim. H-0 = hari-H.
const List<int> kReminderOffsetDays = [7, 3, 1, 0];

/// Android membatasi jumlah alarm terjadwal per aplikasi (±500). Batas-batas di
/// bawah menjaga totalnya tetap jauh di bawah itu.
const int kMaxTasksToSchedule = 50;
const int kMaxReminders = 180;

/// Jadwal kuliah dipasang untuk seminggu ke depan. Lebih panjang tidak berguna:
/// app dijadwalkan ulang tiap kali dibuka.
const int kHorizonKelasHari = 7;

/// Default jeda sebelum kelas dimulai.
const int kMenitSebelumKelasDefault = 30;

/// Pengingat yang isinya bergantung keadaan hari ini hanya bisa dipastikan
/// untuk hari ini. Untuk hari-hari sesudahnya app menjadwalkan versi ajakan
/// (yang selalu benar) sebanyak ini — supaya kamu tetap ditegur di hari kamu
/// tidak membuka app sama sekali, yang justru hari paling rawan.
const int kLookaheadHari = 3;

/// Jam 19.00 — masih ada waktu untuk push up sebelum tidur, dan sudah cukup
/// malam untuk yakin kamu memang belum bergerak hari itu.
const int kJamStreak = 19 * 60;

/// Jam 20.30 — makan malam sudah lewat, jadi catatannya bisa lengkap sehari.
const int kJamCatatMakan = 20 * 60 + 30;

/// Berapa hari sebelum masa berlaku dokumen habis pengingat dikirim.
///
/// Jauh lebih panjang daripada deadline tugas: mengurus dokumen berarti antre,
/// melengkapi berkas, dan kadang datang dua kali. H-14 sudah mepet, bukan awal.
const List<int> kOffsetDokumen = [60, 14, 0];

/// Paspor dapat satu pengingat tambahan enam bulan sebelum habis. Bukan karena
/// aturan Indonesia — paspornya masih sah — melainkan karena banyak negara
/// menolak paspor yang sisa berlakunya di bawah itu.
const int kOffsetPasporHari = 180;

/// Dokumen yang sudah telat masih ditegur sampai sekian hari sesudahnya.
/// Lewat dari itu kamu jelas sudah tahu, dan pengingatnya cuma jadi omelan.
const int kMaxHariTelatDokumen = 90;

/// Jarak pengingat per golongan tenggat kendaraan.
const List<int> kOffsetPajak = [30, 7, 0];
const List<int> kOffsetPlat = [60, 14, 0];
const List<int> kOffsetServis = [7, 0];

/// Berapa kali ajakan mencatat odometer dipasang ke depan, dan berapa hari
/// jaraknya. App menjadwalkan ulang tiap kali dibuka, jadi ini cuma jaring
/// pengaman untuk minggu-minggu kamu tidak membukanya sama sekali.
const int kJumlahAjakanOdometer = 3;
const int kJarakAjakanOdometerHari = 30;

enum ReminderKind {
  deadline('Deadline tugas', Icons.assignment_late_outlined),
  kelas('Jadwal kuliah', Icons.school_outlined),
  streak('Streak olahraga', Icons.local_fire_department_outlined),
  tagihan('Tagihan rutin', Icons.receipt_long_outlined),
  dokumen('Masa berlaku dokumen', Icons.badge_outlined),
  kendaraan('Servis & pajak kendaraan', Icons.two_wheeler),
  catatMakan('Catat makan', Icons.restaurant_outlined);

  const ReminderKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.aktif,
    required this.menitDalamHari,
    this.jenisAktif = const {
      ReminderKind.deadline,
      ReminderKind.kelas,
      ReminderKind.streak,
      ReminderKind.tagihan,
      ReminderKind.dokumen,
      ReminderKind.kendaraan,
    },
    this.menitSebelumKelas = kMenitSebelumKelasDefault,
  });

  /// Saklar utama. Kalau mati, tidak ada satu pun pengingat yang dipasang.
  final bool aktif;

  /// Menit dari tengah malam, mis. 480 = 08:00. Dipakai pengingat deadline dan
  /// tagihan — dua-duanya soal tenggat, bukan soal kejadian di jam tertentu.
  final int menitDalamHari;

  /// Jenis pengingat yang dinyalakan.
  ///
  /// "Catat makan" sengaja mati secara default: itu satu-satunya pengingat di
  /// daftar ini yang menegur soal kebiasaan mencatat, bukan soal kejadian nyata
  /// yang akan kamu lewatkan.
  final Set<ReminderKind> jenisAktif;

  /// Berapa menit sebelum kelas dimulai pengingatnya berbunyi.
  final int menitSebelumKelas;

  TimeOfDay get jam => TimeOfDay(hour: menitDalamHari ~/ 60, minute: menitDalamHari % 60);

  bool nyala(ReminderKind kind) => aktif && jenisAktif.contains(kind);

  NotificationSettings copyWith({
    bool? aktif,
    int? menitDalamHari,
    Set<ReminderKind>? jenisAktif,
    int? menitSebelumKelas,
  }) =>
      NotificationSettings(
        aktif: aktif ?? this.aktif,
        menitDalamHari: menitDalamHari ?? this.menitDalamHari,
        jenisAktif: jenisAktif ?? this.jenisAktif,
        menitSebelumKelas: menitSebelumKelas ?? this.menitSebelumKelas,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.aktif == aktif &&
      other.menitDalamHari == menitDalamHari &&
      other.menitSebelumKelas == menitSebelumKelas &&
      other.jenisAktif.length == jenisAktif.length &&
      other.jenisAktif.containsAll(jenisAktif);

  @override
  int get hashCode => Object.hash(
        aktif,
        menitDalamHari,
        menitSebelumKelas,
        Object.hashAllUnordered(jenisAktif),
      );
}

/// Satu pengingat yang siap dipasang.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.kind,
    required this.waktu,
    required this.judul,
    required this.isi,
  });

  final ReminderKind kind;
  final DateTime waktu;
  final String judul;
  final String isi;
}

/// Potret keadaan yang dibutuhkan untuk menyusun rencana.
///
/// Semuanya sudah ada di app; tidak ada satu pun yang perlu tabel baru.
class ReminderInput {
  const ReminderInput({
    this.tasks = const [],
    this.schedules = const [],
    this.recurring = const [],
    this.documents = const [],
    this.vehicles = const [],
    this.services = const [],
    this.streakHari = 0,
    this.bergerakHariIni = false,
    this.istirahatHariIni = false,
    this.pernahCatatMakan = false,
    this.sudahCatatMakanHariIni = false,
  });

  final List<AcademicTask> tasks;
  final List<ClassSchedule> schedules;
  final List<RecurringExpense> recurring;
  final List<Document> documents;
  final List<Vehicle> vehicles;

  /// Seluruh catatan servis, belum dipilah per kendaraan.
  final List<ServiceLog> services;

  /// Panjang streak berjalan. 0 berarti tidak ada yang bisa hilang malam ini.
  final int streakHari;

  final bool bergerakHariIni;

  /// Hari ini sudah kamu tandai sebagai hari istirahat — jangan ditegur.
  final bool istirahatHariIni;

  /// Pernah mencatat makanan belakangan ini. Kalau tidak, fitur ini memang
  /// tidak kamu pakai dan menegurnya cuma jadi gangguan.
  final bool pernahCatatMakan;

  final bool sudahCatatMakanHariIni;
}

DateTime _hari(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _padaJam(DateTime hari, int menitDalamHari) =>
    DateTime(hari.year, hari.month, hari.day, menitDalamHari ~/ 60, menitDalamHari % 60);

bool _tanggalSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Kemunculan [menitDalamHari] berikutnya yang masih di depan: hari ini kalau
/// jamnya belum lewat, kalau sudah besok.
///
/// Dipakai pengingat yang tidak punya tanggal sendiri — dokumen yang sudah
/// telat, dan ajakan mencatat odometer. Tanpa ini keduanya akan dijadwalkan di
/// masa lalu dan tidak pernah berbunyi.
DateTime _pertamaSetelah(DateTime now, int menitDalamHari) {
  final hariIni = _padaJam(_hari(now), menitDalamHari);
  return hariIni.isAfter(now) ? hariIni : hariIni.add(const Duration(days: 1));
}

String _rupiah(double amount) {
  final bulat = amount.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < bulat.length; i++) {
    if (i > 0 && (bulat.length - i) % 3 == 0) buffer.write('.');
    buffer.write(bulat[i]);
  }
  return 'Rp $buffer';
}

/// Susun seluruh pengingat yang perlu dipasang, urut dari yang paling dekat.
///
/// Hasilnya selalu utuh: pemanggilnya membatalkan semua jadwal lama lalu
/// memasang daftar ini apa adanya. Tidak ada diff yang perlu dilacak.
List<PlannedReminder> planReminders({
  required ReminderInput data,
  required NotificationSettings settings,
  required DateTime now,
}) {
  if (!settings.aktif) return const [];

  final hasil = <PlannedReminder>[
    if (settings.nyala(ReminderKind.deadline)) ..._deadlineReminders(data, settings, now),
    if (settings.nyala(ReminderKind.kelas)) ..._kelasReminders(data, settings, now),
    if (settings.nyala(ReminderKind.streak)) ..._streakReminders(data, now),
    if (settings.nyala(ReminderKind.tagihan)) ..._tagihanReminders(data, settings, now),
    if (settings.nyala(ReminderKind.dokumen)) ..._dokumenReminders(data, settings, now),
    if (settings.nyala(ReminderKind.kendaraan)) ..._kendaraanReminders(data, settings, now),
    if (settings.nyala(ReminderKind.catatMakan)) ..._catatMakanReminders(data, now),
  ]..sort((a, b) => a.waktu.compareTo(b.waktu));

  return hasil.length > kMaxReminders ? hasil.sublist(0, kMaxReminders) : hasil;
}

List<PlannedReminder> _deadlineReminders(
  ReminderInput data,
  NotificationSettings settings,
  DateTime now,
) {
  final pending = data.tasks
      .where((task) => !task.isDone && task.deadline.isAfter(now))
      .toList()
    ..sort((a, b) => a.deadline.compareTo(b.deadline));

  final hasil = <PlannedReminder>[];
  for (final task in pending.take(kMaxTasksToSchedule)) {
    for (final offset in kReminderOffsetDays) {
      final hari = _hari(task.deadline).subtract(Duration(days: offset));
      final waktu = _padaJam(hari, settings.menitDalamHari);
      if (!waktu.isAfter(now)) continue;

      final matkul = task.courseName;
      final suffix = (matkul != null && matkul.trim().isNotEmpty) ? ' ($matkul)' : '';

      hasil.add(PlannedReminder(
        kind: ReminderKind.deadline,
        waktu: waktu,
        judul: switch (offset) {
          0 => 'Deadline hari ini!',
          1 => 'Deadline besok',
          _ => 'Deadline $offset hari lagi',
        },
        isi: switch (offset) {
          0 => '${task.title}$suffix jatuh tempo hari ini.',
          _ => '${task.title}$suffix menunggu diselesaikan.',
        },
      ));
    }
  }
  return hasil;
}

List<PlannedReminder> _kelasReminders(
  ReminderInput data,
  NotificationSettings settings,
  DateTime now,
) {
  final hasil = <PlannedReminder>[];
  final hariIni = _hari(now);

  for (var offset = 0; offset < kHorizonKelasHari; offset++) {
    final hari = hariIni.add(Duration(days: offset));

    for (final schedule in data.schedules) {
      if (schedule.isPhl) {
        final tanggal = schedule.specificDate;
        if (tanggal == null || !_tanggalSama(tanggal, hari)) continue;
      } else if (schedule.dayOfWeek != hari.weekday) {
        continue;
      }

      final mulai = menitDariJam(schedule.startTime);
      if (mulai == null) continue;

      final waktu = _padaJam(hari, mulai).subtract(
        Duration(minutes: settings.menitSebelumKelas),
      );
      if (!waktu.isAfter(now)) continue;

      final ruang = schedule.room;
      final tempat = (ruang != null && ruang.trim().isNotEmpty) ? ' di $ruang' : '';

      hasil.add(PlannedReminder(
        kind: ReminderKind.kelas,
        waktu: waktu,
        judul: '${schedule.courseName} sebentar lagi',
        isi: 'Mulai ${schedule.startTime.substring(0, 5)}$tempat.',
      ));
    }
  }
  return hasil;
}

/// Pengingat streak.
///
/// Hari ini memakai keadaan sebenarnya — app tahu persis kamu sudah bergerak
/// atau belum. Hari-hari sesudahnya memakai kalimat ajakan, karena keadaannya
/// belum terjadi: pengingat yang mengaku tahu sesuatu yang tidak diketahuinya
/// akan salah sesekali, dan sekali salah cukup untuk membuatmu mematikannya.
List<PlannedReminder> _streakReminders(ReminderInput data, DateTime now) {
  if (data.streakHari <= 0) return const [];

  final hasil = <PlannedReminder>[];
  final hariIni = _hari(now);

  final malamIni = _padaJam(hariIni, kJamStreak);
  if (malamIni.isAfter(now) && !data.bergerakHariIni && !data.istirahatHariIni) {
    hasil.add(PlannedReminder(
      kind: ReminderKind.streak,
      waktu: malamIni,
      judul: 'Streak ${data.streakHari} hari belum aman',
      isi: 'Hari ini belum ada catatan olahraga. Masih ada waktu — atau '
          'tandai hari istirahat supaya apinya tetap menyala.',
    ));
  }

  for (var offset = 1; offset <= kLookaheadHari; offset++) {
    hasil.add(PlannedReminder(
      kind: ReminderKind.streak,
      waktu: _padaJam(hariIni.add(Duration(days: offset)), kJamStreak),
      judul: 'Jaga streak-mu',
      isi: 'Sempatkan bergerak hari ini, atau tandai hari istirahat.',
    ));
  }
  return hasil;
}

List<PlannedReminder> _tagihanReminders(
  ReminderInput data,
  NotificationSettings settings,
  DateTime now,
) {
  final hasil = <PlannedReminder>[];
  final hariIni = _hari(now);

  for (final expense in data.recurring) {
    if (!expense.active) continue;

    // Jatuh tempo berikutnya, dihitung dari hari ini.
    final jatuhTempo = dueDateIn(expense, hariIni);
    final waktu = _padaJam(jatuhTempo.subtract(const Duration(days: 1)), settings.menitDalamHari);
    if (!waktu.isAfter(now)) continue;

    hasil.add(PlannedReminder(
      kind: ReminderKind.tagihan,
      waktu: waktu,
      judul: '${expense.name} jatuh tempo besok',
      isi: '${_rupiah(expense.amount)} — siapkan dari sekarang.',
    ));
  }
  return hasil;
}

/// Pengingat masa berlaku dokumen.
///
/// Dokumen tanpa tanggal kedaluwarsa dilewati sepenuhnya — termasuk yang
/// ditandai seumur hidup maupun yang tanggalnya memang belum kamu isi. Yang
/// kedua memang perlu ditagih, tapi bukan lewat notifikasi: menegur soal kolom
/// kosong tiap hari itu gangguan, dan halaman Dokumen sudah menghitungnya di
/// header.
List<PlannedReminder> _dokumenReminders(
  ReminderInput data,
  NotificationSettings settings,
  DateTime now,
) {
  final hasil = <PlannedReminder>[];

  for (final doc in data.documents) {
    final tempo = doc.expiresOn;
    if (doc.noExpiry || tempo == null) continue;

    final sisa = doc.sisaHari(now)!;

    // Yang sudah telat ditegur sekali, bukan diberi jadwal H-minus yang
    // seluruhnya sudah lewat dan karena itu tidak akan pernah berbunyi.
    if (sisa < 0) {
      if (sisa < -kMaxHariTelatDokumen) continue;

      final waktu = _pertamaSetelah(now, settings.menitDalamHari);
      hasil.add(PlannedReminder(
        kind: ReminderKind.dokumen,
        waktu: waktu,
        judul: '${doc.name} sudah kedaluwarsa',
        isi: 'Habis ${-sisa} hari lalu. Makin lama diurus, makin panjang '
            'antreannya.',
      ));
      continue;
    }

    final offsets = <int>[
      ...kOffsetDokumen,
      if (doc.kind == DocKind.paspor) kOffsetPasporHari,
    ];

    for (final offset in offsets) {
      final waktu = _padaJam(
        _hari(tempo).subtract(Duration(days: offset)),
        settings.menitDalamHari,
      );
      if (!waktu.isAfter(now)) continue;

      hasil.add(PlannedReminder(
        kind: ReminderKind.dokumen,
        waktu: waktu,
        judul: switch (offset) {
          0 => '${doc.name} habis hari ini',
          kOffsetPasporHari => '${doc.name} tinggal 6 bulan',
          _ => '${doc.name} habis $offset hari lagi',
        },
        isi: switch (offset) {
          kOffsetPasporHari => 'Masih sah, tapi banyak negara menolak paspor '
              'dengan sisa berlaku di bawah $kBulanPasporAman bulan.',
          0 => 'Masa berlakunya habis hari ini.',
          _ => 'Siapkan berkas perpanjangannya dari sekarang.',
        },
      ));
    }
  }

  return hasil;
}

/// Pengingat servis, pajak, dan plat — plus ajakan mencatat odometer.
///
/// Jadwalnya tidak dihitung ulang di sini: yang dipakai [daftarPengingat] yang
/// sama persis dengan yang kamu lihat di halaman Kendaraan. Kalau notifikasi
/// dan layar bisa berbeda pendapat soal kapan oli harus diganti, keduanya
/// berhenti dipercaya.
List<PlannedReminder> _kendaraanReminders(
  ReminderInput data,
  NotificationSettings settings,
  DateTime now,
) {
  final hasil = <PlannedReminder>[];

  for (final vehicle in data.vehicles) {
    final logs = [
      for (final log in data.services)
        if (log.vehicleId == vehicle.id) log,
    ];

    for (final pengingat in daftarPengingat(vehicle: vehicle, logs: logs, now: now)) {
      final tanggal = pengingat.tanggal;

      // Jadwal yang cuma berbasis km tidak punya tanggal, jadi tidak bisa
      // dipasang sebagai alarm. Itulah yang ditutup ajakan odometer di bawah.
      if (tanggal == null) continue;

      final offsets = switch (pengingat.jenis) {
        JenisTempo.pajak => kOffsetPajak,
        JenisTempo.plat => kOffsetPlat,
        JenisTempo.servis => kOffsetServis,
      };

      for (final offset in offsets) {
        final waktu = _padaJam(
          tanggal.subtract(Duration(days: offset)),
          settings.menitDalamHari,
        );
        if (!waktu.isAfter(now)) continue;

        hasil.add(PlannedReminder(
          kind: ReminderKind.kendaraan,
          waktu: waktu,
          judul: offset == 0
              ? '${pengingat.judul} ${vehicle.name} hari ini'
              : '${pengingat.judul} ${vehicle.name} $offset hari lagi',
          isi: pengingat.jenis == JenisTempo.pajak
              ? 'Telat bayar pajak kena denda, dan dendanya menumpuk per bulan.'
              : pengingat.dasar,
        ));
      }
    }

    if (perluCatatOdometer(vehicle, logs, now: now)) {
      final terakhir = odometerTerakhirPada(vehicle, logs)!;
      final umur = _hari(now).difference(terakhir).inDays;

      for (var i = 0; i < kJumlahAjakanOdometer; i++) {
        final waktu = _pertamaSetelah(now, settings.menitDalamHari)
            .add(Duration(days: i * kJarakAjakanOdometerHari));

        hasil.add(PlannedReminder(
          kind: ReminderKind.kendaraan,
          waktu: waktu,
          judul: 'Odometer ${vehicle.name} sudah lama tidak dicatat',
          isi: i == 0
              ? 'Terakhir $umur hari lalu. Jadwal servis berbasis km dihitung '
                  'dari angka itu, jadi sekarang perkiraannya sudah melenceng.'
              : 'Perbarui angkanya sebentar supaya jadwal servisnya tetap '
                  'benar.',
        ));
      }
    }
  }

  return hasil;
}

List<PlannedReminder> _catatMakanReminders(ReminderInput data, DateTime now) {
  // Menegur orang yang memang tidak memakai fitur catatan makan itu gangguan
  // murni, bukan pengingat.
  if (!data.pernahCatatMakan) return const [];

  final hasil = <PlannedReminder>[];
  final hariIni = _hari(now);

  final malamIni = _padaJam(hariIni, kJamCatatMakan);
  if (malamIni.isAfter(now) && !data.sudahCatatMakanHariIni) {
    hasil.add(PlannedReminder(
      kind: ReminderKind.catatMakan,
      waktu: malamIni,
      judul: 'Belum ada catatan makan hari ini',
      isi: 'Catat sekarang selagi masih ingat.',
    ));
  }

  for (var offset = 1; offset <= kLookaheadHari; offset++) {
    hasil.add(PlannedReminder(
      kind: ReminderKind.catatMakan,
      waktu: _padaJam(hariIni.add(Duration(days: offset)), kJamCatatMakan),
      judul: 'Catat makan hari ini',
      isi: 'Sebelum lupa apa saja yang masuk hari ini.',
    ));
  }
  return hasil;
}
