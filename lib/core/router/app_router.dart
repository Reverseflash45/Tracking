import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academic/presentation/schedule_form_page.dart';
import '../../features/academic/presentation/schedule_page.dart';
import '../../features/academic/presentation/task_detail_page.dart';
import '../../features/academic/presentation/task_form_page.dart';
import '../../features/academic/presentation/tasks_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/body/presentation/body_profile_form_page.dart';
import '../../features/body/presentation/calorie_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/insight/presentation/insight_page.dart';
import '../../features/live/presentation/live_workout_page.dart';
import '../../features/run/presentation/run_history_page.dart';
import '../../features/run/presentation/run_tracker_page.dart';
import '../../features/muscle/presentation/muscle_builder_page.dart';
import '../../features/muscle/presentation/muscle_detail_page.dart';
import '../../features/nutrition/presentation/nutrition_page.dart';
import '../../features/progress/presentation/progress_dashboard_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/workout/presentation/workout_form_page.dart';
import '../../features/workout/presentation/workout_history_page.dart';
import '../../features/workout/presentation/workout_progress_page.dart';
import '../../features/wrapped/presentation/wrapped_page.dart';
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
                // Rute literal harus dideklarasikan sebelum rute berparameter
                // supaya 'new' tidak ikut tertangkap sebagai ':id'.
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const ScheduleFormPage(),
                ),
                GoRoute(
                  path: 'calendar',
                  builder: (context, state) => const CalendarPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) =>
                      ScheduleFormPage(scheduleId: state.pathParameters['id']),
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
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) => TaskFormPage(taskId: state.pathParameters['id']),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      TaskDetailPage(taskId: state.pathParameters['id']!),
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
                  // ?from=<id> membuka form berisi salinan sesi tersebut.
                  // ?exercise/&type/&reps diisi Latihan Terpandu setelah selesai.
                  builder: (context, state) {
                    final query = state.uri.queryParameters;
                    return WorkoutFormPage(
                      repeatSessionId: query['from'],
                      prefillExerciseName: query['exercise'],
                      prefillType: query['type'],
                      prefillReps: int.tryParse(query['reps'] ?? ''),
                    );
                  },
                ),
                GoRoute(
                  path: 'live',
                  builder: (context, state) => const LiveWorkoutPage(),
                ),
                GoRoute(
                  path: 'run',
                  builder: (context, state) => const RunHistoryPage(),
                  routes: [
                    GoRoute(
                      path: 'track',
                      builder: (context, state) => const RunTrackerPage(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'progress',
                  builder: (context, state) => const WorkoutProgressPage(),
                ),
                GoRoute(
                  path: 'body',
                  builder: (context, state) => const BodyProfileFormPage(),
                ),
                GoRoute(
                  path: 'calories',
                  builder: (context, state) => const CaloriePage(),
                ),
                GoRoute(
                  path: 'nutrition',
                  builder: (context, state) => const NutritionPage(),
                ),
                GoRoute(
                  path: 'stats',
                  builder: (context, state) => const ProgressDashboardPage(),
                ),
                GoRoute(
                  path: 'muscle',
                  builder: (context, state) => const MuscleBuilderPage(),
                  routes: [
                    GoRoute(
                      path: ':slug',
                      builder: (context, state) =>
                          MuscleDetailPage(slug: state.pathParameters['slug']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) =>
                      WorkoutFormPage(sessionId: state.pathParameters['id']),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
              routes: [
                GoRoute(
                  path: 'wrapped',
                  builder: (context, state) => const WrappedPage(),
                ),
                GoRoute(
                  path: 'insight',
                  builder: (context, state) => const InsightPage(),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
