import 'dart:io';

const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

String getApiBaseUrl() {
  if (_apiBaseUrlOverride.isNotEmpty) {
    return _apiBaseUrlOverride;
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://127.0.0.1:3000';
}
