import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/reminder_sync.dart';
import 'core/router/app_router.dart';
import 'core/security/kunci_app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/nutrition/data/catat_cepat_widget.dart';
import 'features/routine/data/rutinitas_widget_sync.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    // Menjaga penjadwal pengingat tetap hidup selama app berjalan.
    ref.watch(reminderSyncProvider);
    // Begitu juga isi widget layar utama.
    ref.watch(rutinitasWidgetSyncProvider);
    ref.watch(catatCepatWidgetSyncProvider);

    return MaterialApp.router(
      title: 'Produktivitas Mahasiswa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      // Kunci app berada di atas seluruh navigasi, jadi halaman mana pun yang
      // terbuka — termasuk dari notifikasi atau widget — tertutup olehnya.
      builder: (context, child) => KunciApp(child: child ?? const SizedBox.shrink()),
    );
  }
}
