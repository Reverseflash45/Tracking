import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Pembaca teks dari foto, berjalan sepenuhnya di perangkat.
///
/// Dipakai bersama oleh pembaca struk dan pembaca KRS. Sama seperti deteksi
/// pose: tidak ada gambar yang dikirim ke server, tidak perlu API key, dan
/// tetap jalan tanpa internet.
bool get textScanSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class ScanResult {
  const ScanResult({required this.text, this.error});

  /// Teks mentah hasil pembacaan, baris demi baris.
  final String text;

  /// Terisi kalau pembacaan gagal atau dibatalkan.
  final String? error;

  bool get gagal => error != null;
  bool get kosong => text.trim().isEmpty;
}

/// Ambil foto lalu baca teksnya.
///
/// [fromCamera] false berarti memilih dari galeri — berguna untuk struk yang
/// terlanjur difoto sebelumnya.
Future<ScanResult> scanTextFromPhoto({bool fromCamera = true}) async {
  if (!textScanSupported) {
    return const ScanResult(
      text: '',
      error: 'Pembacaan foto hanya tersedia di HP.',
    );
  }

  TextRecognizer? recognizer;
  try {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // Struk itu tinggi dan sempit; menurunkan resolusi terlalu jauh membuat
      // angka kecil tidak terbaca. Batas ini kompromi antara ketelitian dan
      // waktu proses.
      maxWidth: 1600,
      imageQuality: 90,
    );

    if (photo == null) {
      return const ScanResult(text: '', error: 'Batal');
    }

    recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(photo.path),
    );

    if (recognized.text.trim().isEmpty) {
      return const ScanResult(
        text: '',
        error: 'Tidak ada teks yang terbaca. Coba foto lebih dekat dan '
            'pastikan cahayanya cukup.',
      );
    }

    return ScanResult(text: recognized.text);
  } catch (e) {
    return ScanResult(text: '', error: 'Gagal membaca foto: $e');
  } finally {
    await recognizer?.close();
  }
}
