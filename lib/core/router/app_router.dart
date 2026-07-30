import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academic/presentation/schedule_form_page.dart';
import '../../features/academic/presentation/schedule_page.dart';
import '../../features/academic/presentation/task_form_page.dart';
import '../../features/academic/presentation/tasks_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/workout/presentation/workout_form_page.dart';
import '../../features/workout/presentation/workout_history_page.dart';
import '../../features/workout/presentation/workout_progress_page.dart';
import '../supabase/supabase_client_provider.dart';
import '../widgets/app_shell.dart';
import 'go_router_refresh_stream.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final isLoggedIn = client.auth.currentSession != null;
      final isAuthRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/academic/schedule',
              builder: (context, state) => const SchedulePage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const ScheduleFormPage(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/academic/tasks',
              builder: (context, state) => const TasksPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const TaskFormPage(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/workout',
              builder: (context, state) => const WorkoutHistoryPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const WorkoutFormPage(),
                ),
                GoRoute(
                  path: 'progress',
                  builder: (context, state) => const WorkoutProgressPage(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
});
