import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/features/document/domain/document.dart';

Document _doc({
  String id = 'd1',
  String name = 'SIM C',
  DocKind kind = DocKind.sim,
  String? number,
  DateTime? issuedOn,
  DateTime? expiresOn,
  bool noExpiry = false,
}) {
  return Document(
    id: id,
    name: name,
    kind: kind,
    number: number,
    issuedOn: issuedOn,
    expiresOn: expiresOn,
    noExpiry: noExpiry,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final now = DateTime(2026, 8, 3);

  group('status', () {
    test('tanpa masa berlaku dan belum diisi dibedakan', () {
      expect(_doc(noExpiry: true).status(now), StatusDokumen.tanpaTempo);
      expect(_doc().status(now), StatusDokumen.belumDiisi);
    });

    test('kedaluwarsa kemarin sudah dianggap lewat', () {
      final doc = _doc(expiresOn: DateTime(2026, 8, 2));
      expect(doc.status(now), StatusDokumen.lewat);
      expect(doc.sisaHari(now), -1);
    });

    test('habis hari ini belum dianggap lewat', () {
      final doc = _doc(expiresOn: DateTime(2026, 8, 3));
      expect(doc.sisaHari(now), 0);
      expect(doc.status(now), StatusDokumen.segera);
    });

    test('dua bulan lagi masih dianggap segera', () {
      expect(_doc(expiresOn: DateTime(2026, 9, 30)).status(now), StatusDokumen.segera);
    });

    test('lebih dari dua bulan berstatus aman', () {
      expect(_doc(expiresOn: DateTime(2026, 12, 1)).status(now), StatusDokumen.aman);
    });

    test('yang ditandai seumur hidup tidak punya sisa hari', () {
      final doc = _doc(noExpiry: true, expiresOn: DateTime(2027, 1, 1));
      expect(doc.sisaHari(now), isNull);
    });
  });

  group('paspor', () {
    test('sisa lima bulan ditandai mepet meski masih sah', () {
      final doc = _doc(kind: DocKind.paspor, expiresOn: DateTime(2026, 12, 20));
      expect(doc.status(now), StatusDokumen.aman);
      expect(doc.pasporMepet(now), isTrue);
    });

    test('sisa lebih dari enam bulan tidak ditandai', () {
      final doc = _doc(kind: DocKind.paspor, expiresOn: DateTime(2027, 6, 1));
      expect(doc.pasporMepet(now), isFalse);
    });

    test('yang sudah kedaluwarsa bukan urusan aturan enam bulan', () {
      final doc = _doc(kind: DocKind.paspor, expiresOn: DateTime(2026, 1, 1));
      expect(doc.pasporMepet(now), isFalse);
    });

    test('aturan ini tidak berlaku untuk jenis lain', () {
      final doc = _doc(kind: DocKind.sim, expiresOn: DateTime(2026, 12, 20));
      expect(doc.pasporMepet(now), isFalse);
    });
  });

  group('penyamaran nomor', () {
    test('menyisakan empat digit terakhir', () {
      expect(nomorTersamar('3578011234567890'), '••••••••••••7890');
    });

    test('nomor pendek ditutup seluruhnya', () {
      expect(nomorTersamar('1234'), '••••');
      expect(nomorTersamar('12'), '••');
    });

    test('spasi di ujung tidak ikut dihitung', () {
      expect(nomorTersamar('  1234567  '), '•••4567');
    });
  });

  group('perkiraan kedaluwarsa', () {
    test('SIM lima tahun dari tanggal terbit', () {
      expect(
        perkiraanKedaluwarsa(DocKind.sim, DateTime(2026, 3, 10)),
        DateTime(2031, 3, 10),
      );
    });

    test('jenis tanpa patokan tidak ditebak', () {
      expect(perkiraanKedaluwarsa(DocKind.ktp, DateTime(2026, 3, 10)), isNull);
      expect(perkiraanKedaluwarsa(DocKind.npwp, DateTime(2026, 3, 10)), isNull);
    });
  });

  group('urutan', () {
    test('yang kedaluwarsa di atas, yang tanpa masa berlaku di bawah', () {
      final hasil = sortDocuments([
        _doc(id: 'seumur', noExpiry: true),
        _doc(id: 'aman', expiresOn: DateTime(2027, 5, 1)),
        _doc(id: 'lewat', expiresOn: DateTime(2026, 1, 1)),
        _doc(id: 'segera', expiresOn: DateTime(2026, 9, 1)),
        _doc(id: 'kosong'),
      ], now: now);

      expect(
        hasil.map((d) => d.id).toList(),
        ['lewat', 'segera', 'aman', 'kosong', 'seumur'],
      );
    });

    test('di antara yang segera, yang paling dekat lebih dulu', () {
      final hasil = sortDocuments([
        _doc(id: 'nanti', expiresOn: DateTime(2026, 9, 25)),
        _doc(id: 'besok', expiresOn: DateTime(2026, 8, 4)),
      ], now: now);

      expect(hasil.first.id, 'besok');
    });
  });

  group('ringkasan', () {
    test('yang belum diisi dihitung terpisah, bukan dianggap aman', () {
      final hasil = ringkasDokumen([
        _doc(id: 'a', expiresOn: DateTime(2026, 1, 1)),
        _doc(id: 'b', expiresOn: DateTime(2026, 9, 1)),
        _doc(id: 'c'),
        _doc(id: 'd', noExpiry: true),
      ], now: now);

      expect(hasil.total, 4);
      expect(hasil.lewat, 1);
      expect(hasil.segera, 1);
      expect(hasil.belumDiisi, 1);
    });

    test('daftar kosong tidak menghasilkan apa-apa', () {
      final hasil = ringkasDokumen(const [], now: now);
      expect(hasil.total, 0);
      expect(hasil.lewat, 0);
    });
  });

  group('pembacaan dari database', () {
    test('jenis yang tidak dikenal jatuh ke lainnya', () {
      final doc = Document.fromMap({
        'id': 'x',
        'name': 'Entah',
        'kind': 'kartu_sakti',
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(doc.kind, DocKind.lainnya);
      expect(doc.noExpiry, isFalse);
      expect(doc.expiresOn, isNull);
    });
  });
}
