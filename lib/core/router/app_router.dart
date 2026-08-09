import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academic/presentation/grades_page.dart';
import '../../features/academic/presentation/khs_import_page.dart';
import '../../features/academic/presentation/krs_import_page.dart';
import '../../features/academic/presentation/recurring_tasks_page.dart';
import '../../features/academic/presentation/schedule_form_page.dart';
import '../../features/academic/presentation/schedule_page.dart';
import '../../features/academic/presentation/task_detail_page.dart';
import '../../features/academic/presentation/task_form_page.dart';
import '../../features/academic/presentation/tasks_page.dart';
import '../../features/assistant/presentation/assistant_page.dart';
import '../../features/assistant/presentation/preset_answers_page.dart';
import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/body/presentation/body_profile_form_page.dart';
import '../../features/body/presentation/calorie_page.dart';
import '../../features/body/presentation/progress_photo_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/document/presentation/document_page.dart';
import '../../features/finance/presentation/finance_page.dart';
import '../../features/finance/presentation/recurring_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/insight/presentation/insight_page.dart';
import '../../features/live/presentation/live_workout_page.dart';
import '../../features/run/presentation/run_history_page.dart';
import '../../features/run/presentation/run_tracker_page.dart';
import '../../features/sleep/presentation/sleep_page.dart';
import '../../features/muscle/presentation/muscle_builder_page.dart';
import '../../features/muscle/presentation/muscle_detail_page.dart';
import '../../features/nutrition/presentation/nutrition_page.dart';
import '../../features/progress/presentation/progress_dashboard_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/workout/presentation/workout_form_page.dart';
import '../../features/workout/presentation/workout_history_page.dart';
import '../../features/workout/presentation/workout_home_page.dart';
import '../../features/workout/presentation/workout_progress_page.dart';
import '../../features/vehicle/presentation/vehicle_detail_page.dart';
import '../../features/vehicle/presentation/vehicle_page.dart';
import '../../features/watchlist/presentation/watchlist_page.dart';
import '../../features/wishlist/presentation/wishlist_page.dart';
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
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardPage(),
              routes: [
                GoRoute(
                  path: 'search',
                  builder: (context, state) => const SearchPage(),
                ),
                GoRoute(
                  path: 'goals',
                  builder: (context, state) => const GoalsPage(),
                ),
                GoRoute(
                  // Sejajar dengan Keuangan, bukan di dalamnya. Wishlist memang
                  // memakai angka keuangan, tapi yang kamu lakukan di sini
                  // adalah menginginkan sesuatu — bukan mencatat pengeluaran,
                  // dan tidak seharusnya lewat halaman itu dulu.
                  path: 'wishlist',
                  builder: (context, state) => const WishlistPage(),
                ),
                GoRoute(
                  path: 'watchlist',
                  builder: (context, state) => const WatchlistPage(),
                ),
                GoRoute(
                  path: 'documents',
                  builder: (context, state) => const DocumentPage(),
                ),
                GoRoute(
                  path: 'vehicle',
                  builder: (context, state) => const VehiclePage(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) =>
                          VehicleDetailPage(vehicleId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
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
                  // Absensi tinggal di cabang Jadwal, bukan Tugas: yang dicatat
                  // di sini adalah pertemuan kuliah, dan pertemuan itu datang
                  // dari jadwal.
                  path: 'attendance',
                  builder: (context, state) => const AttendancePage(),
                ),
                GoRoute(
                  path: 'import',
                  builder: (context, state) => const KrsImportPage(),
                ),
                GoRoute(
                  // Nilai tinggal di cabang Jadwal karena mata kuliahnya lahir
                  // dari sini — bukan karena keduanya soal jadwal.
                  path: 'grades',
                  builder: (context, state) => const GradesPage(),
                  routes: [
                    GoRoute(
                      path: 'import',
                      builder: (context, state) => const KhsImportPage(),
                    ),
                  ],
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
                // Rute literal harus dideklarasikan sebelum rute berparameter
                // supaya tidak ikut tertangkap sebagai ':id'.
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const TaskFormPage(),
                ),
                GoRoute(
                  path: 'recurring',
                  builder: (context, state) => const RecurringTasksPage(),
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
              builder: (context, state) => const WorkoutHomePage(),
              routes: [
                GoRoute(
                  // Riwayat dipisah dari halaman utama: ratusan sesi tidak
                  // boleh menenggelamkan pintasan alat lainnya.
                  path: 'history',
                  builder: (context, state) => const WorkoutHistoryPage(),
                ),
                GoRoute(
                  path: 'new',
                  // ?from=<id> membuka form berisi salinan sesi tersebut.
                  // ?exercise/&type/&sets/&reps diisi Latihan Terpandu setelah
                  // selesai. `reps` bisa tidak ada kalau tiap setnya berbeda.
                  builder: (context, state) {
                    final query = state.uri.queryParameters;
                    return WorkoutFormPage(
                      repeatSessionId: query['from'],
                      prefillExerciseName: query['exercise'],
                      prefillType: query['type'],
                      prefillSets: int.tryParse(query['sets'] ?? ''),
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
                  path: 'photos',
                  builder: (context, state) => const ProgressPhotoPage(),
                ),
                GoRoute(
                  path: 'sleep',
                  builder: (context, state) => const SleepPage(),
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
            // Keuangan punya cabang sendiri, bukan menumpang di bawah Dashboard.
            // Sebelumnya satu-satunya jalan masuk adalah menekan kartu di
            // Dashboard — jalan yang tidak dimiliki bagian utama mana pun.
            GoRoute(
              path: '/finance',
              builder: (context, state) => const FinancePage(),
              routes: [
                GoRoute(
                  path: 'recurring',
                  builder: (context, state) => const RecurringPage(),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Profil di luar rangka tab: dia berisi setelan, rekap, dan ekspor —
      // dibuka sesekali, bukan tiap hari. Dibuka dari foto profil di Beranda,
      // dan karena berdiri di atas rangka, bar bawahnya ikut menghilang selama
      // kamu di dalamnya. Itu memang yang diinginkan: sedang mengatur app,
      // bukan sedang memakainya.
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
          GoRoute(
            path: 'tanya',
            // Jalur utama gratis: pertanyaan siap pakai yang jawabannya
            // dihitung di HP. Ketik bebas jadi cabang opsional karena
            // butuh Edge Function dan berbayar.
            builder: (context, state) => const PresetAnswersPage(),
            routes: [
              GoRoute(
                path: 'bebas',
                builder: (context, state) => const AssistantPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
