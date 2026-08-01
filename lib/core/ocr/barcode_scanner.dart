/// Pembaca barcode dari foto, berjalan di perangkat.
///
/// Sengaja memakai foto, bukan pratinjau kamera langsung. Barcode kemasan itu
/// cetakan diam — satu jepretan sudah cukup, dan itu menghemat satu layar
/// kamera penuh beserta seluruh penanganan orientasi dan izin yang menyertainya.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

bool get barcodeScanSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class BarcodeResult {
  const BarcodeResult({this.code, this.error});

  final String? code;
  final String? error;

  bool get gagal => error != null;
}

/// Format yang dipakai kemasan makanan. Membatasi daftarnya membuat
/// pembacaannya lebih cepat dan mengurangi salah tangkap dari teks di sekitar.
const List<BarcodeFormat> _formatMakanan = [
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upca,
  BarcodeFormat.upce,
];

Future<BarcodeResult> scanBarcodeFromPhoto({bool fromCamera = true}) async {
  if (!barcodeScanSupported) {
    return const BarcodeResult(error: 'Scan barcode hanya tersedia di HP.');
  }

  BarcodeScanner? scanner;
  try {
    final photo = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // Barcode butuh garis yang tajam. Turun terlalu jauh membuat batang
      // tipisnya menyatu dan tidak terbaca sama sekali.
      maxWidth: 1600,
      imageQuality: 95,
    );
    if (photo == null) return const BarcodeResult(error: 'Batal');

    scanner = BarcodeScanner(formats: _formatMakanan);
    final hasil = await scanner.processImage(
      InputImage.fromFilePath(photo.path),
    );

    for (final barcode in hasil) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        return BarcodeResult(code: value.trim());
      }
    }

    return const BarcodeResult(
      error: 'Barcode tidak terbaca. Coba lebih dekat, pastikan seluruh '
          'batangnya masuk, dan cahayanya cukup.',
    );
  } catch (e) {
    return BarcodeResult(error: 'Gagal membaca barcode: $e');
  } finally {
    await scanner?.close();
  }
}
