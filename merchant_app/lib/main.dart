import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/config/app_branding.dart';
import 'core/theme/merchant_theme.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'screens/system/app_startup_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MerchantApp());
}

class MerchantApp extends StatelessWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppBrandingController.instance,
      builder: (context, _) {
        final branding = AppBrandingController.instance.branding;

        return MaterialApp.router(
          title: branding.appName,
          debugShowCheckedModeBanner: false,
          theme: MerchantTheme.fromBranding(branding),
          routerConfig: AppRouter.router,
          builder: (context, child) {
            return AppStartupGate(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
