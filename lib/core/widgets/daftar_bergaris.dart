import 'package:flutter/material.dart';

/// Satu kartu berisi baris-baris yang dipisah garis rambut.
///
/// Pengganti "satu kartu per baris". Delapan tugas sebagai delapan kartu
/// berbingkai, berjarak, dan berbayang membuat layar penuh kotak — mata
/// membaca bingkainya dulu, baru isinya. Dikelompokkan dalam satu bidang,
/// barisnya terbaca sebagai satu daftar, seperti di Pengaturan iOS atau
/// Things.
class DaftarBergaris extends StatelessWidget {
  const DaftarBergaris({
    super.key,
    required this.children,
    this.indentGaris = 16,
  });

  final List<Widget> children;

  /// Jarak garis pemisah dari tepi kiri, biasanya disejajarkan dengan awal
  /// teks baris (melewati ikon atau kotak centang di depannya).
  final double indentGaris;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, anak) in children.indexed) ...[
            if (i > 0) Divider(height: 1, indent: indentGaris),
            anak,
          ],
        ],
      ),
    );
  }
}
