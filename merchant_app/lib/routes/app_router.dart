import 'package:go_router/go_router.dart';

import '../features/auth/approval_pending_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/dashboard/dashboard_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const MerchantLoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const MerchantRegisterPage(),
      ),
      GoRoute(
        path: '/approval-pending',
        builder: (context, state) => const ApprovalPendingPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );
}
