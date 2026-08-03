import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/watchlist/domain/watchlist.dart';

MediaItem _item({
  String id = '1',
  String title = 'Judul',
  MediaKind kind = MediaKind.series,
  MediaOrigin origin = MediaOrigin.anime,
  WatchStatus status = WatchStatus.rencana,
  int progress = 0,
  int? total,
  int? rating,
  DateTime? finishedOn,
  DateTime? createdAt,
}) {
  return MediaItem(
    id: id,
    title: title,
    kind: kind,
    origin: origin,
    status: status,
    progress: progress,
    total: total,
    rating: rating,
    finishedOn: finishedOn,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('progres', () {
    test('film tidak punya progres bertahap', () {
      final film = _item(kind: MediaKind.film, progress: 1, total: 1);
      expect(film.persen, isNull);
      expect(film.progresLabel, isNull);
      expect(film.sisa, isNull);
    });

    test('tanpa total, persennya null bukan nol', () {
      final series = _item(progress: 12);
      expect(series.persen, isNull);
      expect(series.progresLabel, 'Ep 12');
      expect(series.sisa, isNull);
    });

    test('dengan total, persen dan sisa dihitung', () {
      final series = _item(progress: 6, total: 24);
      expect(series.persen, closeTo(0.25, 0.001));
      expect(series.progresLabel, 'Ep 6 / 24');
      expect(series.sisa, 18);
    });

    test('progres melebihi total tidak membuat persen lebih dari satu', () {
      final series = _item(progress: 30, total: 24);
      expect(series.persen, 1.0);
      expect(series.sisa, 0);
    });

    test('satuan mengikuti bentuk medianya', () {
      expect(_item(kind: MediaKind.buku, progress: 130).progresLabel, 'Hal 130');
      expect(_item(kind: MediaKind.komik, progress: 45).progresLabel, 'Ch 45');
    });

    test('belum mulai dan total belum diisi berarti tidak ada label sama sekali', () {
      expect(_item().progresLabel, isNull);
    });
  });

  group('majuSatu', () {
    final now = DateTime(2026, 8, 3);

    test('rencana berubah jadi jalan begitu episode pertama ditonton', () {
      final hasil = majuSatu(_item(), now: now);
      expect(hasil.progress, 1);
      expect(hasil.status, WatchStatus.jalan);
      expect(hasil.finishedOn, isNull);
    });

    test('episode terakhir menandai selesai sekaligus mencatat tanggalnya', () {
      final hasil = majuSatu(
        _item(status: WatchStatus.jalan, progress: 11, total: 12),
        now: now,
      );
      expect(hasil.progress, 12);
      expect(hasil.status, WatchStatus.selesai);
      expect(hasil.finishedOn, DateTime(2026, 8, 3));
    });

    test('tanpa total, tidak pernah menganggap dirinya selesai', () {
      final hasil = majuSatu(_item(status: WatchStatus.jalan, progress: 999), now: now);
      expect(hasil.progress, 1000);
      expect(hasil.status, WatchStatus.jalan);
    });

    test('film tidak berubah sama sekali', () {
      final film = _item(kind: MediaKind.film);
      expect(majuSatu(film, now: now).progress, 0);
    });

    test('yang sudah berhenti tetap berhenti, bukan otomatis jalan lagi', () {
      final hasil = majuSatu(_item(status: WatchStatus.berhenti, progress: 3), now: now);
      expect(hasil.status, WatchStatus.berhenti);
      expect(hasil.progress, 4);
    });
  });

  group('urutan', () {
    test('yang sedang jalan selalu di atas yang lain', () {
      final hasil = sortWatchlist([
        _item(id: 'a', status: WatchStatus.selesai),
        _item(id: 'b', status: WatchStatus.rencana),
        _item(id: 'c', status: WatchStatus.jalan),
        _item(id: 'd', status: WatchStatus.berhenti),
      ]);

      expect(hasil.map((e) => e.id).toList(), ['c', 'b', 'a', 'd']);
    });

    test('di antara yang jalan, yang tinggal sedikit lebih dulu', () {
      final hasil = sortWatchlist([
        _item(id: 'jauh', status: WatchStatus.jalan, progress: 2, total: 24),
        _item(id: 'dekat', status: WatchStatus.jalan, progress: 22, total: 24),
      ]);

      expect(hasil.first.id, 'dekat');
    });

    test('yang totalnya belum diketahui tidak dianggap hampir selesai', () {
      final hasil = sortWatchlist([
        _item(id: 'tanpa-total', status: WatchStatus.jalan, progress: 100),
        _item(id: 'sisa-dua', status: WatchStatus.jalan, progress: 10, total: 12),
      ]);

      expect(hasil.first.id, 'sisa-dua');
    });

    test('yang selesai diurutkan dari yang paling baru ditamatkan', () {
      final hasil = sortWatchlist([
        _item(id: 'lama', status: WatchStatus.selesai, finishedOn: DateTime(2026, 1, 5)),
        _item(id: 'baru', status: WatchStatus.selesai, finishedOn: DateTime(2026, 7, 30)),
      ]);

      expect(hasil.first.id, 'baru');
    });

    test('urutannya stabil, tidak berubah tiap kali dipanggil ulang', () {
      final daftar = [
        _item(id: 'a', title: 'Alfa', createdAt: DateTime(2026, 1, 1)),
        _item(id: 'b', title: 'Beta', createdAt: DateTime(2026, 1, 1)),
      ];

      expect(
        sortWatchlist(daftar).map((e) => e.id),
        sortWatchlist(sortWatchlist(daftar)).map((e) => e.id),
      );
    });
  });

  group('penyaring', () {
    final daftar = [
      _item(id: 'a', title: 'Frieren', kind: MediaKind.series, origin: MediaOrigin.anime),
      _item(id: 'b', title: 'Oppenheimer', kind: MediaKind.film, origin: MediaOrigin.hollywood),
      _item(
        id: 'c',
        title: 'Solo Leveling',
        kind: MediaKind.komik,
        origin: MediaOrigin.korea,
        status: WatchStatus.jalan,
      ),
    ];

    test('tanpa saringan, semuanya lolos', () {
      expect(filterWatchlist(daftar, const WatchFilter()).length, 3);
    });

    test('menyaring per bentuk', () {
      final hasil = filterWatchlist(daftar, const WatchFilter(kind: MediaKind.film));
      expect(hasil.single.id, 'b');
    });

    test('menyaring per asal', () {
      final hasil = filterWatchlist(daftar, const WatchFilter(origin: MediaOrigin.korea));
      expect(hasil.single.id, 'c');
    });

    test('bentuk dan asal berlaku bersamaan, bukan salah satu', () {
      final hasil = filterWatchlist(
        daftar,
        const WatchFilter(kind: MediaKind.film, origin: MediaOrigin.korea),
      );
      expect(hasil, isEmpty);
    });

    test('pencarian judul tidak peduli huruf besar-kecil', () {
      final hasil = filterWatchlist(daftar, const WatchFilter(query: 'frier'));
      expect(hasil.single.id, 'a');
    });

    test('penyaring kosong tahu dirinya kosong', () {
      expect(const WatchFilter().kosong, isTrue);
      expect(const WatchFilter(query: '   ').kosong, isTrue);
      expect(const WatchFilter(kind: MediaKind.buku).kosong, isFalse);
    });
  });

  group('ringkasan', () {
    final now = DateTime(2026, 8, 3);

    test('menghitung jumlah per status', () {
      final hasil = summarizeWatchlist([
        _item(id: 'a', status: WatchStatus.jalan),
        _item(id: 'b', status: WatchStatus.jalan),
        _item(id: 'c', status: WatchStatus.rencana),
      ], now: now);

      expect(hasil.jumlah(WatchStatus.jalan), 2);
      expect(hasil.jumlah(WatchStatus.rencana), 1);
      expect(hasil.jumlah(WatchStatus.selesai), 0);
      expect(hasil.total, 3);
    });

    test('selesai tahun lalu tidak ikut dihitung sebagai tahun ini', () {
      final hasil = summarizeWatchlist([
        _item(id: 'a', status: WatchStatus.selesai, finishedOn: DateTime(2025, 12, 31)),
        _item(id: 'b', status: WatchStatus.selesai, finishedOn: DateTime(2026, 1, 1)),
      ], now: now);

      expect(hasil.selesaiTahunIni, 1);
    });

    test('selesai tanpa tanggal tidak ditebak masuk tahun ini', () {
      final hasil = summarizeWatchlist([
        _item(id: 'a', status: WatchStatus.selesai),
      ], now: now);

      expect(hasil.selesaiTahunIni, 0);
    });

    test('rata-rata hanya dari yang dinilai, dan jumlahnya ikut dilaporkan', () {
      final hasil = summarizeWatchlist([
        _item(id: 'a', rating: 9),
        _item(id: 'b', rating: 7),
        _item(id: 'c'),
      ], now: now);

      expect(hasil.rataNilai, 8.0);
      expect(hasil.jumlahDinilai, 2);
    });

    test('belum ada yang dinilai berarti null, bukan nol', () {
      final hasil = summarizeWatchlist([_item()], now: now);
      expect(hasil.rataNilai, isNull);
      expect(hasil.jumlahDinilai, 0);
    });

    test('daftar kosong tidak membagi dengan nol', () {
      final hasil = summarizeWatchlist(const [], now: now);
      expect(hasil.kosong, isTrue);
      expect(hasil.rataNilai, isNull);
    });
  });

  group('label', () {
    test('kata kerjanya menyesuaikan bentuk media', () {
      expect(WatchStatus.rencana.labelUntuk(MediaKind.series), 'Mau Ditonton');
      expect(WatchStatus.rencana.labelUntuk(MediaKind.buku), 'Mau Dibaca');
      expect(WatchStatus.jalan.labelUntuk(MediaKind.komik), 'Sedang Dibaca');
    });
  });

  group('copyWith', () {
    test('nilai dan tanggal selesai bisa dikosongkan lagi', () {
      final item = _item(rating: 8, total: 12, finishedOn: DateTime(2026, 5, 5));

      final bersih = item.copyWith(hapusNilai: true, hapusSelesai: true, hapusTotal: true);
      expect(bersih.rating, isNull);
      expect(bersih.finishedOn, isNull);
      expect(bersih.total, isNull);
    });

    test('tanpa penanda hapus, nilai lama dipertahankan', () {
      final item = _item(rating: 8);
      expect(item.copyWith(progress: 3).rating, 8);
    });
  });

  group('pembacaan dari database', () {
    test('nilai yang tidak dikenal jatuh ke bawaan, bukan melempar galat', () {
      final item = MediaItem.fromMap({
        'id': 'x',
        'title': 'Entah',
        'kind': 'podcast',
        'origin': 'mars',
        'status': 'entahlah',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(item.kind, MediaKind.film);
      expect(item.origin, MediaOrigin.lainnya);
      expect(item.status, WatchStatus.rencana);
      expect(item.progress, 0);
      expect(item.total, isNull);
    });
  });
}
