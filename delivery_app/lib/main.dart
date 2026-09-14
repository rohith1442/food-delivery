import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'core/config/app_branding.dart';
import 'core/theme/delivery_theme.dart';
import 'screens/system/app_startup_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppBrandingController.instance,
      builder: (context, child) {
        final branding = AppBrandingController.instance.branding;
        return MaterialApp.router(
          title: branding.appName,
          debugShowCheckedModeBanner: false,
          theme: DeliveryTheme.fromBranding(branding),
          routerConfig: AppRouter.router,
          builder: (context, child) =>
              AppStartupGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
