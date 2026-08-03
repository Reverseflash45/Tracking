/// Daftar tontonan dan bacaan: apa yang mau ditonton, sedang jalan, dan sudah
/// selesai.
///
/// Dua sumbu sengaja dipisah — **bentuk** (film, series, buku, komik) dan
/// **asal** (anime, Hollywood, Korea, dan seterusnya) — karena keduanya
/// memang tidak saling menggantikan. Anime bisa berupa film maupun series, dan
/// komik asal Jepang, Korea, atau China punya nama sendiri-sendiri di
/// kepalamu. Satu daftar campuran tidak bisa menyatakan itu tanpa jadi dua
/// puluh pilihan yang saling tumpang tindih.
library;

import 'package:flutter/material.dart';

/// Nilai tertinggi. Sepuluh, bukan lima, karena selisih "7 dan 8" itu yang
/// biasanya ingin kamu bedakan.
const int kNilaiMaks = 10;

enum MediaKind {
  film('Film', 'menit', Icons.movie_outlined),
  series('Series', 'episode', Icons.live_tv_outlined),
  buku('Buku', 'halaman', Icons.menu_book_outlined),
  komik('Komik', 'chapter', Icons.auto_stories_outlined);

  const MediaKind(this.label, this.satuan, this.icon);

  final String label;

  /// Satuan progresnya. Dipakai di label form dan kartu, supaya "Ep 12" tidak
  /// muncul untuk buku.
  final String satuan;

  final IconData icon;

  /// Film selesai sekali duduk — tidak ada progres bertahap yang berarti.
  bool get berprogres => this != MediaKind.film;

  /// Ditonton atau dibaca. Menentukan kata kerja di seluruh UI.
  bool get ditonton => this == MediaKind.film || this == MediaKind.series;

  static MediaKind fromDb(String? value) => MediaKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => MediaKind.film,
      );
}

/// Asal tontonan. Digabung dengan [MediaKind] inilah yang membentuk sebutan
/// sehari-hari: komik + Jepang = manga, komik + Korea = manhwa, komik + China
/// = manhua.
enum MediaOrigin {
  anime('Anime'),
  hollywood('Hollywood'),
  korea('Korea'),
  jepang('Jepang'),
  china('China'),
  indonesia('Indonesia'),
  barat('Barat Lain'),
  lainnya('Lainnya');

  const MediaOrigin(this.label);

  final String label;

  static MediaOrigin fromDb(String? value) => MediaOrigin.values.firstWhere(
        (origin) => origin.name == value,
        orElse: () => MediaOrigin.lainnya,
      );
}

enum WatchStatus {
  rencana('Rencana'),
  jalan('Jalan'),
  selesai('Selesai'),
  berhenti('Berhenti');

  const WatchStatus(this.label);

  /// Label pendek untuk chip penyaring, di mana ruangnya sempit dan bentuk
  /// medianya sedang bercampur.
  final String label;

  /// Label panjang yang menyesuaikan bentuk medianya. "Mau Ditonton" untuk
  /// film, "Mau Dibaca" untuk buku — kalimat yang salah kata kerjanya terbaca
  /// seperti terjemahan mesin.
  String labelUntuk(MediaKind kind) {
    final kerja = kind.ditonton ? 'Ditonton' : 'Dibaca';
    return switch (this) {
      WatchStatus.rencana => 'Mau $kerja',
      WatchStatus.jalan => kind.ditonton ? 'Sedang Ditonton' : 'Sedang Dibaca',
      WatchStatus.selesai => 'Selesai',
      WatchStatus.berhenti => 'Berhenti di Tengah',
    };
  }

  static WatchStatus fromDb(String? value) => WatchStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => WatchStatus.rencana,
      );
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    this.kind = MediaKind.film,
    this.origin = MediaOrigin.lainnya,
    this.status = WatchStatus.rencana,
    this.year,
    this.progress = 0,
    this.total,
    this.rating,
    this.url,
    this.note,
    this.finishedOn,
    required this.createdAt,
  });

  final String id;
  final String title;
  final MediaKind kind;
  final MediaOrigin origin;
  final WatchStatus status;

  /// Tahun rilis. Berguna membedakan dua judul yang sama (banyak sekali film
  /// yang di-remake).
  final int? year;

  /// Episode/halaman/chapter yang sudah dilewati.
  final int progress;

  /// Total episode/halaman. Null berarti kamu belum tahu — dan itu beda dari
  /// nol. Series yang masih tayang memang belum punya angka ini.
  final int? total;

  /// 1–[kNilaiMaks]. Null berarti belum dinilai, bukan nol.
  final int? rating;

  final String? url;
  final String? note;
  final DateTime? finishedOn;
  final DateTime createdAt;

  bool get selesai => status == WatchStatus.selesai;
  bool get dinilai => rating != null;

  /// 0–1 untuk bilah progres. Null kalau tidak bisa dihitung dengan jujur:
  /// film tidak punya progres bertahap, dan tanpa total tidak ada penyebutnya.
  double? get persen {
    if (!kind.berprogres) return null;
    final akhir = total;
    if (akhir == null || akhir <= 0) return null;
    return (progress / akhir).clamp(0.0, 1.0);
  }

  /// "Ep 12 / 24", "Ep 12", "Hal 130 / 320". Null untuk film dan untuk yang
  /// belum dimulai sama sekali.
  String? get progresLabel {
    if (!kind.berprogres) return null;
    if (progress <= 0 && total == null) return null;

    final awalan = switch (kind) {
      MediaKind.series => 'Ep',
      MediaKind.buku => 'Hal',
      MediaKind.komik => 'Ch',
      MediaKind.film => '',
    };

    return total == null ? '$awalan $progress' : '$awalan $progress / $total';
  }

  /// Sisa episode/halaman. Null kalau totalnya belum diketahui.
  int? get sisa {
    final akhir = total;
    if (!kind.berprogres || akhir == null) return null;
    final kurang = akhir - progress;
    return kurang < 0 ? 0 : kurang;
  }

  /// [hapusSelesai], [hapusTotal], dan [hapusNilai] ada karena null di
  /// parameter biasa berarti "tidak diubah", jadi tanpa penanda terpisah
  /// tanggal selesai dan nilai tidak akan pernah bisa dikosongkan lagi.
  MediaItem copyWith({
    String? title,
    MediaKind? kind,
    MediaOrigin? origin,
    WatchStatus? status,
    int? year,
    int? progress,
    int? total,
    int? rating,
    DateTime? finishedOn,
    bool hapusSelesai = false,
    bool hapusTotal = false,
    bool hapusNilai = false,
  }) {
    return MediaItem(
      id: id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      origin: origin ?? this.origin,
      status: status ?? this.status,
      year: year ?? this.year,
      progress: progress ?? this.progress,
      total: hapusTotal ? null : (total ?? this.total),
      rating: hapusNilai ? null : (rating ?? this.rating),
      url: url,
      note: note,
      finishedOn: hapusSelesai ? null : (finishedOn ?? this.finishedOn),
      createdAt: createdAt,
    );
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) => MediaItem(
        id: map['id'] as String,
        title: map['title'] as String,
        kind: MediaKind.fromDb(map['kind'] as String?),
        origin: MediaOrigin.fromDb(map['origin'] as String?),
        status: WatchStatus.fromDb(map['status'] as String?),
        year: (map['year'] as num?)?.toInt(),
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt(),
        rating: (map['rating'] as num?)?.toInt(),
        url: map['url'] as String?,
        note: map['note'] as String?,
        finishedOn: map['finished_on'] == null
            ? null
            : DateTime.parse(map['finished_on'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Penyaring daftar. Semua null berarti tidak menyaring apa pun.
class WatchFilter {
  const WatchFilter({this.kind, this.origin, this.status, this.query});

  final MediaKind? kind;
  final MediaOrigin? origin;
  final WatchStatus? status;
  final String? query;

  bool get kosong => kind == null && origin == null && status == null && (query ?? '').trim().isEmpty;

  WatchFilter copyWith({
    MediaKind? kind,
    MediaOrigin? origin,
    WatchStatus? status,
    String? query,
    bool hapusKind = false,
    bool hapusOrigin = false,
    bool hapusStatus = false,
  }) {
    return WatchFilter(
      kind: hapusKind ? null : (kind ?? this.kind),
      origin: hapusOrigin ? null : (origin ?? this.origin),
      status: hapusStatus ? null : (status ?? this.status),
      query: query ?? this.query,
    );
  }
}

List<MediaItem> filterWatchlist(List<MediaItem> items, WatchFilter filter) {
  final cari = (filter.query ?? '').trim().toLowerCase();

  return [
    for (final item in items)
      if ((filter.kind == null || item.kind == filter.kind) &&
          (filter.origin == null || item.origin == filter.origin) &&
          (filter.status == null || item.status == filter.status) &&
          (cari.isEmpty ||
              item.title.toLowerCase().contains(cari) ||
              (item.note ?? '').toLowerCase().contains(cari)))
        item,
  ];
}

/// Urutan tampil: yang sedang jalan paling atas.
///
/// Bukan yang paling baru ditambahkan — daftar tontonan gampang tumbuh sampai
/// ratusan judul, dan yang benar-benar kamu butuhkan tiap membuka halaman ini
/// cuma "tadi aku sampai episode berapa".
List<MediaItem> sortWatchlist(List<MediaItem> items) {
  const urutanStatus = {
    WatchStatus.jalan: 0,
    WatchStatus.rencana: 1,
    WatchStatus.selesai: 2,
    WatchStatus.berhenti: 3,
  };

  final hasil = [...items];

  hasil.sort((a, b) {
    final status = urutanStatus[a.status]!.compareTo(urutanStatus[b.status]!);
    if (status != 0) return status;

    switch (a.status) {
      case WatchStatus.jalan:
        // Yang tinggal sedikit lagi didahulukan: itu yang paling mungkin
        // kamu selesaikan malam ini.
        final sisaA = a.sisa;
        final sisaB = b.sisa;
        if (sisaA != null && sisaB != null && sisaA != sisaB) {
          return sisaA.compareTo(sisaB);
        }
        // Yang totalnya belum diketahui tidak dianggap "hampir selesai".
        if ((sisaA == null) != (sisaB == null)) return sisaA == null ? 1 : -1;

      case WatchStatus.selesai:
        final aSelesai = a.finishedOn;
        final bSelesai = b.finishedOn;
        if (aSelesai != null && bSelesai != null && aSelesai != bSelesai) {
          return bSelesai.compareTo(aSelesai);
        }
        if ((aSelesai == null) != (bSelesai == null)) return aSelesai == null ? 1 : -1;

      case WatchStatus.rencana:
      case WatchStatus.berhenti:
        break;
    }

    // Terbaru ditambahkan di atas, lalu judul supaya urutannya tidak berubah
    // sendiri tiap kali daftarnya dimuat ulang.
    final dibuat = b.createdAt.compareTo(a.createdAt);
    if (dibuat != 0) return dibuat;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return hasil;
}

class WatchSummary {
  const WatchSummary({
    required this.perStatus,
    required this.selesaiTahunIni,
    required this.rataNilai,
    required this.jumlahDinilai,
    required this.total,
  });

  final Map<WatchStatus, int> perStatus;

  /// Berapa yang diselesaikan di tahun berjalan. Yang tanpa tanggal selesai
  /// tidak ikut — tidak ada cara jujur menebak kapan itu terjadi.
  final int selesaiTahunIni;

  /// Null kalau belum ada satu pun yang kamu nilai.
  final double? rataNilai;

  /// Dari berapa judul rata-ratanya dihitung. Ditampilkan bersama angkanya,
  /// supaya "9,0" dari satu judul tidak terbaca seperti kesimpulan.
  final int jumlahDinilai;

  final int total;

  int jumlah(WatchStatus status) => perStatus[status] ?? 0;

  bool get kosong => total == 0;
}

WatchSummary summarizeWatchlist(List<MediaItem> items, {required DateTime now}) {
  final perStatus = <WatchStatus, int>{};
  var selesaiTahunIni = 0;
  var totalNilai = 0;
  var dinilai = 0;

  for (final item in items) {
    perStatus.update(item.status, (v) => v + 1, ifAbsent: () => 1);

    final selesai = item.finishedOn;
    if (item.selesai && selesai != null && selesai.year == now.year) {
      selesaiTahunIni++;
    }

    final nilai = item.rating;
    if (nilai != null) {
      totalNilai += nilai;
      dinilai++;
    }
  }

  return WatchSummary(
    perStatus: perStatus,
    selesaiTahunIni: selesaiTahunIni,
    rataNilai: dinilai == 0 ? null : totalNilai / dinilai,
    jumlahDinilai: dinilai,
    total: items.length,
  );
}

/// Kemajuan setelah menonton/membaca satu satuan lagi.
///
/// Mengembalikan salinan yang sudah disesuaikan, termasuk perpindahan status:
/// yang tadinya "rencana" jadi "jalan" begitu episode pertama ditonton, dan
/// jadi "selesai" begitu menyentuh total. Tanpa ini kamu harus mengubah status
/// sendiri tiap kali, dan pada akhirnya tidak ada yang statusnya benar.
MediaItem majuSatu(MediaItem item, {required DateTime now}) {
  if (!item.kind.berprogres) return item;

  final berikutnya = item.progress + 1;
  final akhir = item.total;

  if (akhir != null && berikutnya >= akhir) {
    return item.copyWith(
      progress: akhir,
      status: WatchStatus.selesai,
      finishedOn: DateTime(now.year, now.month, now.day),
    );
  }

  return item.copyWith(
    progress: berikutnya,
    status: item.status == WatchStatus.rencana ? WatchStatus.jalan : item.status,
  );
}
