import 'package:flutter/material.dart';

import '../../services/app_config_service.dart';
import 'force_update_page.dart';
import 'maintenance_page.dart';

class AppStartupGate
    extends StatefulWidget {
  const AppStartupGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppStartupGate> createState() =>
      _AppStartupGateState();
}

class _AppStartupGateState
    extends State<AppStartupGate> {
  final AppConfigService _service =
  AppConfigService();

  AppConfigResult? _config;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
      await _service.check();

      if (!mounted) {
        return;
      }

      setState(() {
        _config = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
        'Unable to check app configuration.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding:
            const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign:
                  TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _check,
                  child: const Text(
                    'Retry',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final config = _config!;

    if (config.maintenanceMode) {
      return MaintenancePage(
        onRetry: _check,
      );
    }

    if (config.updateRequired) {
      return ForceUpdatePage(
        currentVersion:
        config.currentVersion,
        minimumVersion:
        config.minimumVersion,
      );
    }

    return widget.child;
  }
}