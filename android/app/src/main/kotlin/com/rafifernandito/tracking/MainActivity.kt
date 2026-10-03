package com.rafifernandito.tracking

import io.flutter.embedding.android.FlutterFragmentActivity

// FragmentActivity, bukan FlutterActivity: dialog sidik jari (local_auth) dan
// layar izin Health Connect (registerForActivityResult) sama-sama butuh itu.
class MainActivity : FlutterFragmentActivity()
