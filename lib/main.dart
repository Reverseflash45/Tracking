import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/crash/crash_reporter.dart';
import 'features/routine/data/rutinitas_widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Paling awal, supaya error saat inisialisasi di bawah juga tertangkap.
  await CrashReporter.instance.pasang();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Tombol "Sudah" di widget layar utama memanggil Dart di latar belakang;
  // penanggapnya harus terdaftar sebelum tombol itu pertama kali ditekan.
  unawaited(daftarkanAksiWidget());

  runApp(const ProviderScope(child: App()));
}
