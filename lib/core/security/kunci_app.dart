import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'app_lock.dart';

/// Lapisan kunci di atas seluruh app (dipasang di `MaterialApp.builder`).
///
/// Isi app tetap hidup di bawahnya — halaman yang sedang dibuka, form yang
/// setengah diisi — jadi membuka kunci mengembalikanmu persis ke tempat tadi.
class KunciApp extends ConsumerStatefulWidget {
  const KunciApp({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KunciApp> createState() => _KunciAppState();
}

class _KunciAppState extends ConsumerState<KunciApp> with WidgetsBindingObserver {
  DateTime? _keLatar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Yang dihitung hanya `paused` dan `hidden` — benar-benar pindah ke app
  /// lain. `inactive` tidak: itu juga terjadi saat menarik panel notifikasi
  /// atau saat dialog sidik jari sendiri muncul.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final kunci = ref.read(kunciProvider.notifier);
    if (!ref.read(kunciProvider).aktif || kunci.sedangAuth) return;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _keLatar ??= DateTime.now();
      case AppLifecycleState.resumed:
        final keLatar = _keLatar;
        _keLatar = null;
        if (keLatar != null) kunci.kembaliDariLatar(keLatar);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kunci = ref.watch(kunciProvider);
    final tampilkanKunci = kunci.siap && kunci.terkunci;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Isi app tidak bisa disentuh atau difokus selama terkunci.
        ExcludeFocus(
          excluding: tampilkanKunci,
          child: IgnorePointer(ignoring: tampilkanKunci, child: widget.child),
        ),
        if (tampilkanKunci) const _LayarKunci(),
        // Setelan belum terbaca (hanya sesaat saat app dibuka): tutup polos
        // supaya isinya tidak sempat terlihat sebelum kuncinya muncul.
        if (!kunci.siap) ColoredBox(color: Theme.of(context).colorScheme.surface),
      ],
    );
  }
}

class _LayarKunci extends ConsumerStatefulWidget {
  const _LayarKunci();

  @override
  ConsumerState<_LayarKunci> createState() => _LayarKunciState();
}

class _LayarKunciState extends ConsumerState<_LayarKunci> with WidgetsBindingObserver {
  String? _galat;
  bool _sibuk = false;
  bool _keLatar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Langsung minta sidik jari begitu layar kunci muncul; tombolnya hanya
    // untuk mencoba lagi setelah dibatalkan.
    WidgetsBinding.instance.addPostFrameCallback((_) => _buka());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Kembali ke app yang masih terkunci: minta sidik jari lagi. Hanya setelah
  /// benar-benar ke latar, bukan setelah dialog sidik jari ditutup —
  /// kalau tidak, membatalkan dialog langsung memunculkannya lagi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(kunciProvider.notifier).sedangAuth) return;
    if (state == AppLifecycleState.paused) _keLatar = true;
    if (state == AppLifecycleState.resumed && _keLatar) {
      _keLatar = false;
      _buka();
    }
  }

  Future<void> _buka() async {
    if (_sibuk) return;
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    final galat = await ref.read(kunciProvider.notifier).buka();
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _galat = galat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.profile.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 40, color: AppColors.profile),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tracking terkunci',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Buka dengan sidik jari, wajah, atau PIN layar HP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              if (_galat != null) ...[
                const SizedBox(height: 16),
                Text(
                  _galat!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: colorScheme.error),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sibuk ? null : _buka,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.profile,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Buka kunci'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
