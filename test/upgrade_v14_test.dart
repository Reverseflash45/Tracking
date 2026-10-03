import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/core/notifications/reminder_sync.dart';
import 'package:tracking/core/notifications/smart_reminders.dart';
import 'package:tracking/core/security/app_lock.dart';
import 'package:tracking/features/academic/domain/krs_ai.dart';
import 'package:tracking/features/finance/domain/transaction.dart';
import 'package:tracking/features/health/domain/kesehatan.dart';
import 'package:tracking/features/nutrition/data/catat_cepat_widget.dart';
import 'package:tracking/features/profile/data/cadangan_lokal.dart';
import 'package:tracking/features/profile/domain/cadangan.dart';
import 'package:tracking/features/routine/domain/berkala.dart';
import 'package:tracking/features/sleep/data/sleep_repository.dart';

void main() {
  group('Baca KRS dengan AI', () {
    Map<String, dynamic> baris({
      String nama = 'Basis Data',
      Object hari = 1,
      String mulai = '07:30',
      String selesai = '10:00',
      Object sks = 3,
    }) =>
        {
          'nama': nama,
          'kode': 'sic204',
          'kelas': 'TI-B2',
          'sks': sks,
          'hari': hari,
          'mulai': mulai,
          'selesai': selesai,
          'ruang': '',
          'dosen': '  Dr. Ani,   M.Kom ',
        };

    test('baris sah dibaca, kolom kosong jadi null, kode huruf besar', () {
      final hasil = HasilBacaKrs.fromJson({
        'jadwal': [baris()],
        'catatan': ' Periksa ruangannya. ',
      });
      final e = hasil.entries.single;
      expect(e.courseName, 'Basis Data');
      expect(e.courseCode, 'SIC204');
      expect(e.classCode, 'TI-B2');
      expect(e.sks, 3);
      expect(e.dayOfWeek, 1);
      expect(e.room, isNull);
      expect(e.lecturer, 'Dr. Ani, M.Kom');
      expect(hasil.catatan, 'Periksa ruangannya.');
    });

    test('jam dinormalkan: 7.30 dan 13:00:00', () {
      final e = krsEntryDariJson(baris(mulai: '7.30', selesai: '13:00:00'))!;
      expect(e.startTime, '07:30');
      expect(e.endTime, '13:00');
    });

    test('baris yang tidak bisa disimpan dibuang', () {
      expect(krsEntryDariJson(baris(hari: 0)), isNull);
      expect(krsEntryDariJson(baris(hari: 8)), isNull);
      expect(krsEntryDariJson(baris(mulai: '10:00', selesai: '09:00')), isNull);
      expect(krsEntryDariJson(baris(mulai: '25:00')), isNull);
      expect(krsEntryDariJson(baris(mulai: 'pagi')), isNull);
      expect(krsEntryDariJson(baris(nama: ' ')), isNull);
    });

    test('SKS di luar batas kolom database (1-12) tidak ikut', () {
      expect(krsEntryDariJson(baris(sks: 0))!.sks, isNull);
      expect(krsEntryDariJson(baris(sks: 20))!.sks, isNull);
      expect(krsEntryDariJson(baris(sks: 12))!.sks, 12);
    });

    test('jawaban tanpa daftar jadwal tidak meledak', () {
      expect(HasilBacaKrs.fromJson({'catatan': 'Bukan KRS'}).entries, isEmpty);
      expect(HasilBacaKrs.fromJson({'jadwal': 'aneh'}).entries, isEmpty);
    });
  });

  group('Kunci app', () {
    final keLatar = DateTime(2026, 10, 3, 10, 0, 0);

    test('terkunci lagi setelah jedanya lewat, tidak sebelumnya', () {
      bool kunci(Duration lama) => perluKunciLagi(
            aktif: true,
            keLatar: keLatar,
            sekarang: keLatar.add(lama),
            jeda: const Duration(minutes: 1),
          );
      expect(kunci(const Duration(seconds: 30)), isFalse);
      expect(kunci(const Duration(minutes: 1)), isTrue);
      expect(kunci(const Duration(hours: 2)), isTrue);
    });

    test('jam HP yang dimundurkan tetap mengunci', () {
      expect(
        perluKunciLagi(
          aktif: true,
          keLatar: keLatar,
          sekarang: keLatar.subtract(const Duration(hours: 1)),
          jeda: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('mati berarti tidak pernah mengunci', () {
      expect(
        perluKunciLagi(
          aktif: false,
          keLatar: keLatar,
          sekarang: keLatar.add(const Duration(days: 1)),
          jeda: Duration.zero,
        ),
        isFalse,
      );
    });

    test('label jeda', () {
      expect(kPilihanJeda.map(labelJeda), ['Segera', '30 detik', '1 menit', '5 menit']);
    });
  });

  group('Cadangan', () {
    test('semua tabel di migrasi ikut dicadangkan, kecuali crash_reports', () {
      final tabel = <String>{};
      for (final f in Directory('supabase/migrations').listSync().whereType<File>()) {
        final isi = f.readAsStringSync();
        for (final m in RegExp(r'create table (?:if not exists )?(?:public\.)?(\w+)', caseSensitive: false)
            .allMatches(isi)) {
          tabel.add(m.group(1)!.toLowerCase());
        }
      }
      expect(tabel, isNotEmpty);
      final terlewat = tabel.difference({...kTabelCadangan.keys, 'crash_reports'});
      expect(terlewat, isEmpty, reason: 'Tabel baru belum masuk kTabelCadangan');
    });

    test('induk dipulihkan sebelum anak', () {
      final urutan = kTabelCadangan.keys.toList();
      void sebelum(String induk, String anak) =>
          expect(urutan.indexOf(induk), lessThan(urutan.indexOf(anak)), reason: '$induk → $anak');
      sebelum('courses', 'class_schedules');
      sebelum('courses', 'tasks');
      sebelum('recurring_tasks', 'tasks');
      sebelum('class_schedules', 'attendance');
      sebelum('courses', 'grade_components');
      sebelum('workout_sessions', 'workout_exercises');
      sebelum('workout_templates', 'workout_template_exercises');
      sebelum('vehicles', 'vehicle_services');
      sebelum('periodic_routines', 'periodic_routine_logs');
    });

    Map<String, dynamic> berkas({int versi = 2, Map<String, dynamic>? data}) => {
          'format_version': versi,
          'exported_at': '2026-10-01T08:00:00.000',
          'app': 'tracking',
          'account_email': 'lama@contoh.id',
          'data': data ??
              {
                'profiles': [
                  {'id': 'akun-lama', 'full_name': 'Rafi'},
                ],
                'finance_settings': [
                  {'user_id': 'akun-lama', 'monthly_budget': 1500000},
                ],
                'courses': [
                  {'id': 'c1', 'user_id': 'akun-lama', 'name': 'Basis Data'},
                ],
                'workout_exercises': [
                  {'id': 'e1', 'session_id': 's1', 'exercise_name': 'Squat'},
                ],
                'tabel_masa_depan': [
                  {'id': 'x'},
                ],
              },
        };

    test('pemilik ditulis ulang ke akun yang login', () {
      final r = siapkanPulihkan(jsonDecode(jsonEncode(berkas())), userId: 'akun-baru');
      expect(r.perTabel['profiles']!.single['id'], 'akun-baru');
      expect(r.perTabel['finance_settings']!.single['user_id'], 'akun-baru');
      expect(r.perTabel['courses']!.single['user_id'], 'akun-baru');
      // Tabel tanpa user_id tidak diberi kolom baru.
      expect(r.perTabel['workout_exercises']!.single.containsKey('user_id'), isFalse);
      expect(r.tabelTakDikenal, ['tabel_masa_depan']);
      expect(r.totalBaris, 4);
      expect(r.email, 'lama@contoh.id');
      expect(r.exportedAt, DateTime(2026, 10, 1, 8));
    });

    test('urutan rencana mengikuti urutan pemulihan', () {
      final r = siapkanPulihkan(berkas(), userId: 'u');
      final urutan = kTabelCadangan.keys.toList();
      final keys = r.perTabel.keys.map(urutan.indexOf).toList();
      expect(keys, [...keys]..sort());
    });

    test('berkas versi 1 tetap bisa dipulihkan', () {
      expect(siapkanPulihkan(berkas(versi: 1), userId: 'u').totalBaris, 4);
    });

    test('berkas yang bukan cadangan ditolak dengan pesan jelas', () {
      expect(() => siapkanPulihkan([1, 2], userId: 'u'), throwsA(isA<CadanganTidakSah>()));
      expect(() => siapkanPulihkan({'app': 'lain', 'data': {}}, userId: 'u'),
          throwsA(isA<CadanganTidakSah>()));
      expect(() => siapkanPulihkan(berkas(versi: 99), userId: 'u'),
          throwsA(isA<CadanganTidakSah>().having((e) => e.pesan, 'pesan', contains('lebih baru'))));
    });

    test('cadangan otomatis: seminggu sekali, dan tidak mencoba ulang terus saat gagal', () {
      final sekarang = DateTime(2026, 10, 10, 9);
      bool perlu({DateTime? terakhir, DateTime? coba, bool aktif = true}) => perluCadanganOtomatis(
            aktif: aktif,
            terakhir: terakhir,
            percobaanTerakhir: coba,
            sekarang: sekarang,
          );
      expect(perlu(), isTrue);
      expect(perlu(aktif: false), isFalse);
      expect(perlu(terakhir: sekarang.subtract(const Duration(days: 6))), isFalse);
      expect(perlu(terakhir: sekarang.subtract(const Duration(days: 7))), isTrue);
      expect(perlu(coba: sekarang.subtract(const Duration(hours: 1))), isFalse);
      expect(perlu(coba: sekarang.subtract(const Duration(hours: 7))), isTrue);
      expect(perlu(terakhir: sekarang.add(const Duration(days: 3))), isTrue);
    });

    test('tanggal dibaca dari nama berkas', () {
      expect(tanggalDariNama('tracking-backup-2026-10-03-0915.json'), DateTime(2026, 10, 3, 9, 15));
      expect(tanggalDariNama('lain.json'), isNull);
    });
  });

  group('Health Connect', () {
    DateTime t(int hari, int jam, [int menit = 0]) => DateTime(2026, 10, hari, jam, menit);

    test('tidur dicatat di tanggal bangun, tidur terpecah dijumlahkan', () {
      final hasil = tidurPerHari([
        SesiTidur(mulai: t(1, 23), selesai: t(2, 5)),
        // Bangun sebentar, lalu tidur lagi 1,5 jam: tetap tidur malam.
        SesiTidur(mulai: t(2, 5, 30), selesai: t(2, 7)),
      ]);
      expect(hasil, {DateTime(2026, 10, 2): 7.5});
    });

    test('tidur siang tidak dihitung, sesi tumpang tindih hanya sekali', () {
      final hasil = tidurPerHari([
        SesiTidur(mulai: t(2, 13), selesai: t(2, 14)),
        SesiTidur(mulai: t(2, 23), selesai: t(3, 6)),
        // Jam tangan kedua mencatat malam yang sama.
        SesiTidur(mulai: t(3, 0), selesai: t(3, 7)),
      ]);
      expect(hasil, {DateTime(2026, 10, 3): 8.0});
    });

    test('catatan yang kamu isi sendiri tidak ditimpa', () {
      final rencana = rencanaImporTidur(
        dariHealthConnect: {
          DateTime(2026, 10, 1): 7.0,
          DateTime(2026, 10, 2): 6.5,
          DateTime(2026, 10, 3): 8.0,
        },
        tercatat: [
          TidurTercatat(tanggal: DateTime(2026, 10, 1), jam: 5, catatan: 'Begadang tugas'),
          TidurTercatat(
            tanggal: DateTime(2026, 10, 2),
            jam: 6,
            kualitas: 4,
            catatan: kPenandaHealthConnect,
          ),
        ],
      );
      expect(rencana.map((r) => (r.tanggal.day, r.jam, r.kualitas)), [
        (2, 6.5, 4),
        (3, 8.0, null),
      ]);
    });

    test('impor dari Health Connect yang angkanya sama tidak ditulis ulang', () {
      expect(
        rencanaImporTidur(
          dariHealthConnect: {DateTime(2026, 10, 2): 6.5},
          tercatat: [TidurTercatat(tanggal: DateTime(2026, 10, 2), jam: 6.5, catatan: kPenandaHealthConnect)],
        ),
        isEmpty,
      );
    });

    test('rata-rata langkah mengabaikan hari tanpa jam tangan', () {
      final hari = [
        LangkahHarian(tanggal: DateTime(2026, 10, 1), langkah: 0),
        LangkahHarian(tanggal: DateTime(2026, 10, 2), langkah: 6000),
        LangkahHarian(tanggal: DateTime(2026, 10, 3), langkah: 9000),
      ];
      expect(rataRataLangkah(hari), 7500);
      expect(rataRataLangkah([LangkahHarian(tanggal: DateTime(2026, 10, 1), langkah: 0)]), isNull);
    });
  });

  group('Widget catat cepat', () {
    test('data widget: belum login tanpa u', () {
      final data = jsonDecode(dataWidgetCatat(userId: null, hariIni: DateTime(2026, 10, 3), ml: 0)) as Map;
      expect(data.containsKey('u'), isFalse);
    });

    test('tombol air menambah angka hari ini, dan mulai dari nol di hari baru', () {
      final awal = dataWidgetCatat(userId: 'u1', hariIni: DateTime(2026, 10, 3), ml: 500);
      final sama = jsonDecode(tambahAirDiWidget(awal, 250, DateTime(2026, 10, 3, 21))) as Map;
      expect(sama['ml'], 750);
      expect(sama['u'], 'u1');
      final besok = jsonDecode(tambahAirDiWidget(awal, 250, DateTime(2026, 10, 4, 7))) as Map;
      expect(besok['ml'], 250);
      expect(besok['tanggal'], '2026-10-04');
    });
  });

  group('Rekap mingguan', () {
    // 3 Oktober 2026 hari Sabtu.
    final sabtu = DateTime(2026, 10, 3, 10);

    test('isi hanya memuat angka yang ada', () {
      expect(
        teksRekap(const RingkasanMinggu(sesiLatihan: 3, rataTidurJam: 6.75, pengeluaran: 450000)),
        '3x latihan · tidur rata-rata 6,8 jam · keluar Rp 450.000.',
      );
      expect(teksRekap(const RingkasanMinggu()), contains('Belum ada'));
      expect(
        teksRekap(const RingkasanMinggu(berkalaTerlewat: 2)),
        '2 rutinitas terlewat.',
      );
    });

    List<PlannedReminder> rencana(DateTime now, RingkasanMinggu? r) => planReminders(
          data: ReminderInput(mingguIni: r),
          settings: const NotificationSettings(
            aktif: true,
            menitDalamHari: 8 * 60,
            jenisAktif: {ReminderKind.rekapMingguan},
          ),
          now: now,
        );

    test('dijadwalkan Minggu jam 19.00 dan membuka Wrapped', () {
      final r = rencana(sabtu, const RingkasanMinggu(sesiLatihan: 2)).single;
      expect(r.waktu, DateTime(2026, 10, 4, 19));
      expect(r.isi, '2x latihan.');
      expect(r.payload, kPayloadRekap);
    });

    test('Minggu malam setelah jam 7: minggu depan, isinya umum', () {
      final r = rencana(DateTime(2026, 10, 4, 20), const RingkasanMinggu(sesiLatihan: 2)).single;
      expect(r.waktu, DateTime(2026, 10, 11, 19));
      expect(r.isi, isNot(contains('latihan')));
    });

    test('ringkasan hanya menghitung Senin sampai sekarang', () {
      final r = ringkasMinggu(
        now: sabtu,
        sleeps: [
          SleepLog(id: '1', loggedOn: DateTime(2026, 9, 28), hours: 6),
          SleepLog(id: '2', loggedOn: DateTime(2026, 10, 2), hours: 8),
          // Minggu lalu.
          SleepLog(id: '3', loggedOn: DateTime(2026, 9, 27), hours: 3),
        ],
        transactions: [
          Transaction(
            id: 't1',
            occurredOn: DateTime(2026, 9, 29),
            kind: TxKind.pengeluaran,
            category: TxCategory.makan,
            amount: 25000,
          ),
          Transaction(
            id: 't2',
            occurredOn: DateTime(2026, 9, 30),
            kind: TxKind.pemasukan,
            category: TxCategory.lainnya,
            amount: 1000000,
          ),
        ],
        berkala: [
          RutinitasBerkala(
            id: 'b1',
            userId: 'u',
            title: 'Absen akun',
            intervalDays: 25,
            lastDoneOn: DateTime(2026, 9, 1),
          ),
        ],
      );
      expect(r.rataTidurJam, 7);
      expect(r.pengeluaran, 25000);
      expect(r.berkalaTerlewat, 1);
    });
  });
}
