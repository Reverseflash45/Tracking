import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Tata letak bersama halaman masuk dan daftar.
///
/// Dulu keduanya memakai latar gradien penuh dengan ikon roket di kotak
/// kaca dan lembar putih melengkung di bawahnya — pola yang dipakai ribuan
/// templat. Sekarang cukup tipografi di atas latar polos: nama aplikasi
/// kecil sebagai penanda, judul besar yang menyatakan apa yang sedang
/// dilakukan, lalu formulirnya. Lebar dibatasi supaya tetap enak dibaca di
/// layar lebar (web).
class KerangkaAuth extends StatelessWidget {
  const KerangkaAuth({
    super.key,
    required this.judul,
    required this.subjudul,
    required this.formulir,
    required this.kaki,
    this.onKembali,
  });

  final String judul;
  final String subjudul;
  final Widget formulir;

  /// Tautan pindah halaman di bawah formulir ("Belum punya akun? Daftar").
  final Widget kaki;

  /// Kalau diisi, tombol kembali muncul di pojok kiri atas.
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (onKembali != null) ...[
                        IconButton(
                          onPressed: onKembali,
                          tooltip: 'Kembali',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Produktivitas Mahasiswa',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    judul,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subjudul,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  formulir,
                  const SizedBox(height: AppSpacing.md),
                  kaki,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
