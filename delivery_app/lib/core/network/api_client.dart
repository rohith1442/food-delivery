import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_base_url.dart';

class ApiClient {
  ApiClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: getApiBaseUrl(),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      );

  final Dio _dio;

  Future<Response<dynamic>> get(String path) async {
    final token = await _getFirebaseToken();

    return _dio.get(
      path,
      options: Options(
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<Response<dynamic>> post(String path, {dynamic data}) async {
    final token = await _getFirebaseToken();

    return _dio.post(
      path,
      data: data,
      options: Options(
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<Response<dynamic>> patch(String path, {dynamic data}) async {
    final token = await _getFirebaseToken();

    return _dio.patch(
      path,
      data: data,
      options: Options(
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<Response<dynamic>> put(String path, {dynamic data}) async {
    final token = await _getFirebaseToken();
    return _dio.put(
      path,
      data: data,
      options: Options(
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<String?> _getFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return user.getIdToken();
  }
}
