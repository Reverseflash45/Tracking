import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/achievements.dart';
import '../../../core/offline/offline_banner.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/menu_list.dart';
import '../../academic/data/models/class_schedule.dart';
import '../../academic/data/models/task.dart';
import '../../academic/domain/schedule_conflict.dart';
import '../../academic/presentation/academic_providers.dart';
import '../../body/data/body_repository.dart';
import '../../body/domain/calorie_calculator.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/domain/finance_stats.dart';
import '../../finance/presentation/transaction_sheet.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../nutrition/presentation/food_form_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../routine/data/berkala_repository.dart';
import '../../routine/domain/berkala.dart';
import '../../routine/presentation/berkala_page.dart';
import '../../workout/presentation/workout_providers.dart';

part 'dashboard_sapaan.dart';
part 'dashboard_sorotan.dart';
part 'dashboard_cincin.dart';
part 'dashboard_minggu.dart';
part 'dashboard_tenggat.dart';
part 'dashboard_uang.dart';
part 'dashboard_pintasan.dart';

final _dayFormat = DateFormat('EEEE, d MMMM', 'id_ID');

/// Warna cincin asupan. Lima warna tab sudah terpakai untuk arti lain, dan
/// asupan butuh rona hangat yang tidak tertukar dengan koral tenggat.
const Color _warnaAsupan = Color(0xFFE8812C);

/// Target hari bergerak per minggu kalau belum ada target sendiri — batas
/// bawah anjuran aktivitas fisik orang dewasa (3–5 hari seminggu).
const int _targetLatihanMingguan = 4;

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaCatatCepat(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classSchedulesProvider);
          ref.invalidate(tasksProvider);
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(foodLogsProvider);
          ref.invalidate(waterLogsProvider);
          ref.invalidate(berkalaProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            MediaQuery.of(context).padding.top + 14,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: const [
            _Sapaan(),
            SizedBox(height: 18),
            // Ditaruh di atas: catatan yang tertahan harus terlihat sebelum
            // kamu menganggap semuanya sudah tersimpan.
            OfflineBanner(),
            _KartuSorotan(),
            _BerkalaJatuhTempo(),
            SizedBox(height: AppSpacing.md),
            _KartuCincin(),
            SizedBox(height: AppSpacing.md),
            _KartuMingguIni(),
            _AchievementsRow(),
            _Judul('Tenggat', aksi: 'Semua', tab: kTabTugas),
            _DaftarTenggat(),
            _Judul('Uang', aksi: 'Detail', rute: '/finance'),
            _KartuUang(),
            _Judul('Pintasan', aksi: 'Semua', tab: kTabLainnya),
            _PintasanLainnya(),
            SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}

/// Pindah ke tab lain, bukan menumpuk halamannya di atas Beranda.
///
/// Kalau di-push, bar bawah tetap menunjuk Beranda padahal kamu sudah ada di
/// Jadwal, dan tombol kembali jadi satu-satunya jalan keluar.
void _keTab(BuildContext context, int tab) {
  StatefulNavigationShell.of(context).goBranch(tab);
}

bool _hariSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _awalMinggu(DateTime t) {
  final hari = DateTime(t.year, t.month, t.day);
  return hari.subtract(Duration(days: hari.weekday - 1));
}

// ---------------------------------------------------------------------------
// Sapaan
// ---------------------------------------------------------------------------

class _Judul extends StatelessWidget {
  const _Judul(this.teks, {this.aksi, this.tab, this.rute});

  final String teks;
  final String? aksi;

  /// Tujuan tombol [aksi]: pindah tab, atau buka halaman di [rute].
  final int? tab;
  final String? rute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (aksi != null && (tab != null || rute != null))
            TextButton(
              onPressed: () =>
                  rute != null ? context.push(rute!) : _keTab(context, tab!),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(aksi!),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rutinitas berkala yang sudah waktunya
// ---------------------------------------------------------------------------

class _KartuKosong extends StatelessWidget {
  const _KartuKosong({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final redup = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(ikon, size: 20, color: redup),
            const SizedBox(width: 12),
            Expanded(
              child: Text(teks, style: TextStyle(fontSize: 13.5, color: redup)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uang
// ---------------------------------------------------------------------------
