import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Nama berkas memakai tanggal dan jam supaya beberapa cadangan bisa hidup
/// berdampingan di folder yang sama tanpa saling menimpa.
String exportFileName(DateTime moment) {
  final tanggal = moment.toIso8601String().substring(0, 10);
  final jam = '${_two(moment.hour)}${_two(moment.minute)}';
  return 'tracking-backup-$tanggal-$jam.json';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Serahkan berkas cadangan ke share sheet sistem, tempat user memilih sendiri
/// mau disimpan ke mana (Files, Drive, WhatsApp, dan seterusnya).
///
/// App ini tidak menulis ke folder Download secara langsung: itu butuh izin
/// penyimpanan tambahan di Android, sementara share sheet tidak butuh izin apa
/// pun dan memberi user kendali penuh atas tujuannya.
///
/// Byte-nya dikirim lewat [XFile.fromData], bukan file yang kita tulis sendiri.
/// share_plus sudah menyimpannya ke direktori sementara saat dibutuhkan, jadi
/// kode ini tidak perlu menyentuh `dart:io` — yang penting karena `dart:io`
/// tidak bisa dikompilasi untuk web.
Future<void> shareExport({
  required String json,
  required String fileName,
  String? subject,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          utf8.encode(json),
          mimeType: 'application/json',
          name: fileName,
        ),
      ],
      // Nama di XFile.fromData diabaikan di luar web; ini yang benar-benar
      // menentukan nama berkas yang diterima aplikasi tujuan.
      fileNameOverrides: [fileName],
      subject: subject,
      downloadFallbackEnabled: true,
    ),
  );
}
