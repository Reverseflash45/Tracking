import 'package:flutter/widgets.dart';

/// Jalankan [buka] sekali setelah halaman pertama kali tampil — dipakai untuk
/// langsung membuka form saat halaman dibuka dari tombol widget
/// (`?catat=1`), tanpa membuat halamannya sendiri tahu soal widget.
class BukaSaatMuncul extends StatefulWidget {
  const BukaSaatMuncul({
    super.key,
    required this.aktif,
    required this.buka,
    required this.child,
  });

  final bool aktif;
  final void Function(BuildContext context) buka;
  final Widget child;

  @override
  State<BukaSaatMuncul> createState() => _BukaSaatMunculState();
}

class _BukaSaatMunculState extends State<BukaSaatMuncul> {
  @override
  void initState() {
    super.initState();
    if (widget.aktif) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.buka(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
