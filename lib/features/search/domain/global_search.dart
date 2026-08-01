/// Pencarian menyeluruh: satu kotak untuk tugas, latihan, makanan, dan
/// pengeluaran.
///
/// Semuanya dicari di HP dari data yang memang sudah dimuat — tidak ada query
/// baru ke server, jadi ini juga jalan tanpa sinyal.
library;

import 'package:flutter/material.dart';

import '../../academic/data/models/task.dart';
import '../../finance/domain/transaction.dart';
import '../../nutrition/domain/food_log.dart';
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
  latihan('Latihan', Icons.fitness_center, '/workout/history'),
  makanan('Makanan', Icons.restaurant_menu, '/workout/nutrition'),
  transaksi('Pengeluaran', Icons.savings_outlined, '/finance');

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
    required this.date,
    this.route,
  });

  final SearchKind kind;
  final String title;
  final String subtitle;
  final DateTime date;

  /// Tujuan yang lebih tepat daripada [SearchKind.route], kalau ada.
  final String? route;

  String get tujuan => route ?? kind.route;
}

bool _cocok(String? teks, String cari) =>
    teks != null && teks.toLowerCase().contains(cari);

String _tanggalPendek(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

/// Cari [query] di semua data yang diberikan.
///
/// Hasilnya diurutkan per jenis dulu (mengikuti urutan enum), baru terbaru di
/// dalam tiap jenis — bukan tercampur satu daftar panjang. Waktu mencari
/// "protein", kamu biasanya sudah tahu sedang mencari makanan atau latihan.
List<SearchHit> searchAll({
  required String query,
  List<AcademicTask> tasks = const [],
  List<WorkoutSession> sessions = const [],
  List<FoodLog> foods = const [],
  List<Transaction> transactions = const [],
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

  final gabungan = <SearchHit>[];
  for (final kind in SearchKind.values) {
    final daftar = hasil[kind]!..sort((a, b) => b.date.compareTo(a.date));
    gabungan.addAll(daftar.take(kMaxPerKind));
  }
  return gabungan;
}

/// Berapa hasil per jenis, untuk ditampilkan sebagai judul kelompok.
Map<SearchKind, List<SearchHit>> groupHits(List<SearchHit> hits) {
  final grouped = <SearchKind, List<SearchHit>>{};
  for (final hit in hits) {
    grouped.putIfAbsent(hit.kind, () => []).add(hit);
  }
  return grouped;
}
