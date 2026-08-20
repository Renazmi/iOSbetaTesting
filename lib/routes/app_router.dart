import 'package:go_router/go_router.dart';

import '../models/trackit_role.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/officer/officer_dashboard_screen.dart';
import '../screens/shared/message_screen.dart';
import '../screens/shared/event_publish_screen.dart';
import '../screens/shared/events_list_screen.dart';
import '../screens/shared/organizations_screen.dart';
import '../screens/shared/profile_screen.dart';
import '../screens/shared/qr_scanner_screen.dart';
import '../screens/student/student_dashboard_screen.dart';
import '../services/app_state.dart';
import '../widgets/shell/trackit_main_shell.dart';

GoRouter createAppRouter(AppState appState) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: appState,
    redirect: (context, state) => appState.redirectForAuth(state.matchedLocation),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return LoginScreen(
            initialStudentId: qp['studentId'],
            initialSuccessMessage: qp['success'],
          );
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/officer/events/publish',
        builder: (context, state) {
          final editParam = state.uri.queryParameters['edit'];
          final editId = editParam != null ? int.tryParse(editParam) : null;
          return EventPublishScreen(editEventId: editId);
        },
      ),
      GoRoute(
        path: '/officer',
        redirect: (context, state) => '/officer/dashboard',
      ),
      GoRoute(
        path: '/student',
        redirect: (context, state) => '/student/dashboard',
      ),
      _officerShell(),
      _studentShell(),
    ],
  );
}

StatefulShellRoute _officerShell() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return TrackitMainShell(
        role: TrackitRole.officer,
        navigationShell: navigationShell,
      );
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/officer/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OfficerDashboardScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/officer/events',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EventsListScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/officer/message',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessageScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/officer/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/officer/scan',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: QrScannerScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

StatefulShellRoute _studentShell() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return TrackitMainShell(
        role: TrackitRole.student,
        navigationShell: navigationShell,
      );
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/student/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StudentDashboardScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/student/events',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EventsListScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/student/organizations',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrganizationsScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/student/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/student/scan',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: QrScannerScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
