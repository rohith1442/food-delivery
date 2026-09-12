import 'package:go_router/go_router.dart';

import '../features/auth/auth_state.dart';
import '../features/auth/login_page.dart';
import '../features/auth/onboarding_page.dart';
import '../features/auth/splash_page.dart';
import '../features/home/home_page.dart';
import '../features/location/location_picker_page.dart';

class AppRouter {
  AppRouter._();

  static final AuthState authState = AuthState();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (!authState.initialized) {
        return location == '/' ? null : '/';
      }

      final loggedIn = authState.isLoggedIn;

      if (loggedIn &&
          (location == '/' ||
              location == '/login' ||
              location == '/onboarding')) {
        return '/home';
      }

      if (!loggedIn && location == '/home') {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/location',
        builder: (context, state) => const LocationPickerPage(),
      ),
    ],
  );
}
