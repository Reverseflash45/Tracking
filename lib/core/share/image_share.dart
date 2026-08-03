import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Ubah widget yang dibungkus [RepaintBoundary] jadi PNG lalu serahkan ke share
/// sheet sistem.
///
/// Gambarnya dirender ulang pada [pixelRatio] 3, bukan mengikuti kerapatan layar
/// perangkat. Tanpa itu, kartu yang tajam di HP kelas atas akan pecah saat
/// dibuat di HP dengan layar biasa — dan hasilnya sama-sama diunggah ke tempat
/// yang sama.
Future<bool> captureAndShare({
  required GlobalKey boundaryKey,
  required String fileName,
  String? text,
  double pixelRatio = 3,
}) async {
  final context = boundaryKey.currentContext;
  if (context == null) return false;

  final boundary = context.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return false;

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) return false;

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          data.buffer.asUint8List(),
          mimeType: 'image/png',
          name: fileName,
        ),
      ],
      // Nama di XFile.fromData diabaikan di luar web; ini yang menentukan nama
      // berkas yang diterima aplikasi tujuan.
      fileNameOverrides: [fileName],
      text: text,
      downloadFallbackEnabled: true,
    ),
  );

  return true;
}

/// Halaman pratinjau: kamu melihat persis apa yang akan dibagikan sebelum
/// menekan tombolnya.
class SharePreviewPage extends StatefulWidget {
  const SharePreviewPage({
    super.key,
    required this.title,
    required this.card,
    required this.fileName,
    required this.accent,
    this.text,
  });

  final String title;

  /// Kartu yang akan dijadikan gambar.
  final Widget card;

  final String fileName;
  final Color accent;
  final String? text;

  @override
  State<SharePreviewPage> createState() => _SharePreviewPageState();
}

class _SharePreviewPageState extends State<SharePreviewPage> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final berhasil = await captureAndShare(
        boundaryKey: _boundaryKey,
        fileName: widget.fileName,
        text: widget.text,
      );
      if (!berhasil && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat gambar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RepaintBoundary(
            key: _boundaryKey,
            child: widget.card,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _sharing ? null : _share,
            style: FilledButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _sharing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share),
            label: Text(_sharing ? 'Menyiapkan...' : 'Bagikan'),
          ),
        ),
      ),
    );
  }
}
