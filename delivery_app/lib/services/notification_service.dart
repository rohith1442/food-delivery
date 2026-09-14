import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';

class NotificationService {
  NotificationService({FirebaseMessaging? messaging, ApiClient? apiClient})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _apiClient = apiClient ?? ApiClient();

  final FirebaseMessaging _messaging;
  final ApiClient _apiClient;

  Future<void> initialize() async {
    try {
      await _requestPermission();
      if (Platform.isIOS && await _messaging.getAPNSToken() == null) return;
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
      _messaging.onTokenRefresh.listen((token) async {
        try {
          await _registerToken(token);
        } catch (error) {
          debugPrint('Unable to register refreshed notification token: $error');
        }
      });
    } catch (error) {
      debugPrint('Notification initialization skipped: $error');
    }
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _registerToken(String token) async {
    await _apiClient.post(
      '/notifications/device-token',
      data: {
        'token': token,
        'app': 'DELIVERY',
        'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
      },
    );
  }
}
