import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profiles/profile_detail_screen.dart';
import 'features/profiles/profiles_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggedIn = auth.value ?? false;
      final onAuthPage =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profiles',
              builder: (context, state) => const ProfilesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ProfileDetailScreen(
                    id: state.pathParameters['id']!,
                    username: state.uri.queryParameters['username'] ?? '',
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
