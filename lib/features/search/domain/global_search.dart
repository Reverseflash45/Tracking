/// Pencarian menyeluruh: satu kotak untuk seluruh catatanmu.
///
/// Semuanya dicari di HP dari data yang memang sudah dimuat — tidak ada query
/// baru ke server, jadi ini juga jalan tanpa sinyal.
///
/// Tiap kali ada bagian baru di app, sumbernya harus ditambahkan ke sini juga.
/// Tombol yang tampak berlaku sepanjang app tapi diam-diam cuma mencari di
/// sebagian tempat itu lebih menyesatkan daripada tidak ada tombolnya.
library;

import 'package:flutter/material.dart';

import '../../academic/data/models/course.dart';
import '../../academic/data/models/task.dart';
import '../../document/domain/document.dart';
import '../../finance/domain/transaction.dart';
import '../../goals/domain/goal.dart';
import '../../nutrition/domain/food_log.dart';
import '../../vehicle/domain/vehicle.dart';
import '../../watchlist/domain/watchlist.dart';
import '../../wishlist/domain/wishlist.dart';
import '../../workout/data/models/workout_session.dart';

/// Panjang minimal sebelum pencarian dijalankan.
///
/// Satu huruf cocok dengan hampir semua catatan, dan hasil sebanyak itu sama
/// tidak bergunanya dengan tidak ada hasil.
const int kMinQueryLength = 2;

/// Batas hasil per jenis, supaya satu jenis tidak menenggelamkan yang lain.
const int kMaxPerKind = 8;

enum SearchKind {
  tugas('Tugas', Icons.checklist, '/academic/tasks'),
  matkul('Mata Kuliah', Icons.menu_book_outlined, '/academic/schedule/grades'),
  latihan('Latihan', Icons.fitness_center, '/workout/history'),
  makanan('Makanan', Icons.restaurant_menu, '/workout/nutrition'),
  transaksi('Pengeluaran', Icons.savings_outlined, '/finance'),
  wishlist('Wishlist', Icons.favorite_outline, '/wishlist'),
  tontonan('Watchlist', Icons.movie_outlined, '/watchlist'),
  kendaraan('Kendaraan', Icons.two_wheeler, '/vehicle'),
  dokumen('Dokumen', Icons.badge_outlined, '/documents'),
  target('Target', Icons.flag_outlined, '/goals');

  const SearchKind(this.label, this.icon, this.route);

  final String label;
  final IconData icon;

  /// Halaman tujuan waktu hasilnya diketuk.
  final String route;
}

class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.date,
    this.route,
  });

  final SearchKind kind;
  final String title;
  final String subtitle;

  /// Tanggal yang paling menggambarkan catatan ini, dipakai mengurutkan yang
  /// terbaru ke atas. Null untuk yang memang tidak punya tanggal berarti —
  /// wishlist dan target hidup di masa depan, bukan di satu titik waktu.
  final DateTime? date;

  /// Tujuan yang lebih tepat daripada [SearchKind.route], kalau ada.
  final String? route;

  String get tujuan => route ?? kind.route;
}

bool _cocok(String? teks, String cari) =>
    teks != null && teks.toLowerCase().contains(cari);

String _tanggalPendek(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

String _rupiahPendek(double nilai) {
  if (nilai >= 1000000) return 'Rp ${(nilai / 1000000).toStringAsFixed(1)}jt';
  if (nilai >= 1000) return 'Rp ${(nilai / 1000).round()}rb';
  return 'Rp ${nilai.round()}';
}

/// Cari [query] di semua data yang diberikan.
///
/// Hasilnya diurutkan per jenis dulu (mengikuti urutan enum), baru terbaru di
/// dalam tiap jenis — bukan tercampur satu daftar panjang. Waktu mencari
/// "protein", kamu biasanya sudah tahu sedang mencari makanan atau latihan.
List<SearchHit> searchAll({
  required String query,
  List<AcademicTask> tasks = const [],
  List<Course> courses = const [],
  List<WorkoutSession> sessions = const [],
  List<FoodLog> foods = const [],
  List<Transaction> transactions = const [],
  List<WishlistItem> wishlist = const [],
  List<MediaItem> media = const [],
  List<Vehicle> vehicles = const [],
  List<ServiceLog> services = const [],
  List<Document> documents = const [],
  List<Goal> goals = const [],
}) {
  final cari = query.trim().toLowerCase();
  if (cari.length < kMinQueryLength) return const [];

  final hasil = <SearchKind, List<SearchHit>>{
    for (final kind in SearchKind.values) kind: [],
  };

  for (final task in tasks) {
    if (!_cocok(task.title, cari) && !_cocok(task.description, cari)) continue;
    hasil[SearchKind.tugas]!.add(SearchHit(
      kind: SearchKind.tugas,
      title: task.title,
      subtitle: task.completedAt != null
          ? 'Selesai'
          : 'Deadline ${_tanggalPendek(task.deadline)}',
      date: task.deadline,
      route: '/academic/tasks/${task.id}',
    ));
  }

  for (final session in sessions) {
    // Sesi dicocokkan lewat nama latihan di dalamnya, bukan lewat tanggal —
    // yang dicari orang itu "bench press", bukan "12 Agustus".
    final cocok = session.exercises
        .where((e) => _cocok(e.exerciseName, cari))
        .map((e) => e.exerciseName)
        .toSet();
    if (cocok.isEmpty && !_cocok(session.notes, cari)) continue;

    hasil[SearchKind.latihan]!.add(SearchHit(
      kind: SearchKind.latihan,
      title: cocok.isEmpty ? 'Catatan sesi' : cocok.join(', '),
      subtitle: _tanggalPendek(session.sessionDate),
      date: session.sessionDate,
    ));
  }

  for (final food in foods) {
    if (!_cocok(food.name, cari)) continue;
    hasil[SearchKind.makanan]!.add(SearchHit(
      kind: SearchKind.makanan,
      title: food.name,
      subtitle: '${food.calories.round()} kkal  ·  '
          '${_tanggalPendek(food.loggedOn)}',
      date: food.loggedOn,
    ));
  }

  for (final tx in transactions) {
    if (!_cocok(tx.product, cari) &&
        !_cocok(tx.merchant, cari) &&
        !_cocok(tx.note, cari)) {
      continue;
    }
    hasil[SearchKind.transaksi]!.add(SearchHit(
      kind: SearchKind.transaksi,
      title: tx.product ?? tx.merchant ?? tx.category.label,
      subtitle: [
        if (tx.product != null && tx.merchant != null) tx.merchant!,
        _tanggalPendek(tx.occurredOn),
      ].join('  ·  '),
      date: tx.occurredOn,
    ));
  }

  for (final course in courses) {
    if (!_cocok(course.name, cari) && !_cocok(course.lecturer, cari)) continue;
    hasil[SearchKind.matkul]!.add(SearchHit(
      kind: SearchKind.matkul,
      title: course.name,
      subtitle: [
        if (course.lecturer case final dosen? when dosen.trim().isNotEmpty) dosen.trim(),
        if (course.sks case final sks?) '$sks sks',
        if (course.semester case final semester? when semester.trim().isNotEmpty)
          semester.trim(),
      ].join('  ·  '),
      date: course.createdAt,
    ));
  }

  for (final item in wishlist) {
    if (!_cocok(item.name, cari) && !_cocok(item.note, cari)) continue;
    hasil[SearchKind.wishlist]!.add(SearchHit(
      kind: SearchKind.wishlist,
      title: item.name,
      subtitle: item.dibeli
          ? 'Sudah dibeli'
          : (item.adaHarga ? _rupiahPendek(item.price!) : 'Harga belum diisi'),
      // Sengaja tanpa tanggal: barang yang diincar tidak terjadi di satu titik
      // waktu, jadi mengurutkannya "terbaru dulu" tidak berarti apa-apa.
      date: item.boughtOn,
    ));
  }

  for (final item in media) {
    if (!_cocok(item.title, cari) && !_cocok(item.note, cari)) continue;
    hasil[SearchKind.tontonan]!.add(SearchHit(
      kind: SearchKind.tontonan,
      title: item.title,
      subtitle: [
        item.origin.label,
        item.kind.label,
        if (item.progresLabel case final progres?) progres else item.status.label,
      ].join('  ·  '),
      date: item.finishedOn ?? item.createdAt,
    ));
  }

  for (final vehicle in vehicles) {
    if (!_cocok(vehicle.name, cari) && !_cocok(vehicle.plate, cari)) continue;
    hasil[SearchKind.kendaraan]!.add(SearchHit(
      kind: SearchKind.kendaraan,
      title: vehicle.name,
      subtitle: [
        vehicle.type.label,
        if (vehicle.plate case final nopol? when nopol.trim().isNotEmpty)
          nopol.trim().toUpperCase(),
      ].join('  ·  '),
      date: vehicle.createdAt,
      route: '/vehicle/${vehicle.id}',
    ));
  }

  // Catatan servis dicari lewat catatannya — "bengkel Pak Slamet" ada di sana,
  // bukan di nama kendaraannya.
  final namaKendaraan = {for (final v in vehicles) v.id: v.name};
  for (final log in services) {
    if (!_cocok(log.note, cari) && !_cocok(log.kind.label, cari)) continue;
    hasil[SearchKind.kendaraan]!.add(SearchHit(
      kind: SearchKind.kendaraan,
      title: '${log.kind.label} ${namaKendaraan[log.vehicleId] ?? ''}'.trim(),
      subtitle: [
        _tanggalPendek(log.doneOn),
        if (log.note case final catatan? when catatan.trim().isNotEmpty) catatan.trim(),
      ].join('  ·  '),
      date: log.doneOn,
      route: '/vehicle/${log.vehicleId}',
    ));
  }

  for (final doc in documents) {
    if (!_cocok(doc.name, cari) &&
        !_cocok(doc.kind.label, cari) &&
        !_cocok(doc.note, cari)) {
      continue;
    }
    // Nomornya sengaja tidak ikut dicari dan tidak ikut ditampilkan. Hasil
    // pencarian muncul di layar penuh sambil kamu mengetik; nomor KTP tidak
    // pantas ada di sana.
    hasil[SearchKind.dokumen]!.add(SearchHit(
      kind: SearchKind.dokumen,
      title: doc.name,
      subtitle: doc.kind.label,
      date: doc.expiresOn,
    ));
  }

  for (final goal in goals) {
    if (goal.archived) continue;
    if (!_cocok(goal.title, cari) && !_cocok(goal.metric.label, cari)) continue;
    hasil[SearchKind.target]!.add(SearchHit(
      kind: SearchKind.target,
      title: goal.title,
      subtitle: '${goal.metric.label}  ·  ${goal.period.label}',
      date: goal.endDate,
    ));
  }

  final gabungan = <SearchHit>[];
  for (final kind in SearchKind.values) {
    final daftar = hasil[kind]!..sort(_bandingkan);
    gabungan.addAll(daftar.take(kMaxPerKind));
  }
  return gabungan;
}

/// Terbaru di atas; yang tidak punya tanggal jatuh ke bawah dan diurut abjad,
/// supaya urutannya tetap sama tiap kali dicari.
int _bandingkan(SearchHit a, SearchHit b) {
  final tanggalA = a.date;
  final tanggalB = b.date;

  if (tanggalA != null && tanggalB != null) {
    final selisih = tanggalB.compareTo(tanggalA);
    if (selisih != 0) return selisih;
  } else if ((tanggalA == null) != (tanggalB == null)) {
    return tanggalA == null ? 1 : -1;
  }

  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Berapa hasil per jenis, untuk ditampilkan sebagai judul kelompok.
Map<SearchKind, List<SearchHit>> groupHits(List<SearchHit> hits) {
  final grouped = <SearchKind, List<SearchHit>>{};
  for (final hit in hits) {
    grouped.putIfAbsent(hit.kind, () => []).add(hit);
  }
  return grouped;
}
