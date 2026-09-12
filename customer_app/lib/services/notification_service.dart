import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/network/api_client.dart';

class NotificationService {
  NotificationService({FirebaseMessaging? messaging, ApiClient? apiClient})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _apiClient = apiClient ?? ApiClient();

  final FirebaseMessaging _messaging;
  final ApiClient _apiClient;

  Future<void> initialize() async {
    await _requestPermission();

    final token = await _messaging.getToken();

    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      await _registerToken(token);
    });
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _registerToken(String token) async {
    await _apiClient.post(
      '/notifications/device-token',
      data: {
        'token': token,
        'app': 'CUSTOMER',
        'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
      },
    );
  }
}
