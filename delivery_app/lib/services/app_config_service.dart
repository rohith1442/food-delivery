import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfigResult {
  final bool maintenanceMode;
  final bool updateRequired;
  final String currentVersion;
  final String minimumVersion;

  const AppConfigResult({
    required this.maintenanceMode,
    required this.updateRequired,
    required this.currentVersion,
    required this.minimumVersion,
  });
}

class AppConfigService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:3000',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  Future<AppConfigResult> check() async {
    final response = await _dio.get(
      '/settings/app-config',
      queryParameters: {
        'app': 'DELIVERY',
      },
    );

    final data = Map<String, dynamic>.from(
      response.data,
    );

    final maintenanceMode =
        data['maintenanceMode'] == true;

    final forceUpdate =
        data['forceUpdate'] == true;

    final minimumVersion =
        data['minimumVersion']?.toString() ??
            '1.0.0';

    final packageInfo =
    await PackageInfo.fromPlatform();

    final currentVersion =
        packageInfo.version;

    return AppConfigResult(
      maintenanceMode: maintenanceMode,
      updateRequired:
      forceUpdate &&
          _isVersionLower(
            currentVersion,
            minimumVersion,
          ),
      currentVersion: currentVersion,
      minimumVersion: minimumVersion,
    );
  }

  bool _isVersionLower(
      String current,
      String minimum,
      ) {
    final currentParts =
    _parseVersion(current);

    final minimumParts =
    _parseVersion(minimum);

    for (var i = 0; i < 3; i++) {
      if (currentParts[i] <
          minimumParts[i]) {
        return true;
      }

      if (currentParts[i] >
          minimumParts[i]) {
        return false;
      }
    }

    return false;
  }

  List<int> _parseVersion(
      String version,
      ) {
    final cleanVersion =
        version.split('+').first;

    final parts =
    cleanVersion.split('.');

    return List.generate(
      3,
          (index) {
        if (index >= parts.length) {
          return 0;
        }

        return int.tryParse(
          parts[index],
        ) ??
            0;
      },
    );
  }
}