import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class StoreApiService {
  StoreApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>?> getStore() async {
    try {
      final response = await _apiClient.get(
        '/merchant/store',
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      return Map<String, dynamic>.from(
        data['store'] as Map,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> createStore({
    required String name,
    required String moduleId,
    required String zoneId,
    required String address,
    required double minimumOrder,
  }) async {
    final response = await _apiClient.post(
      '/merchant/store',
      data: {
        'name': name,
        'moduleId': moduleId,
        'zoneId': zoneId,
        'address': address,
        'minimumOrder': minimumOrder,
      },
    );

    final data = Map<String, dynamic>.from(
      response.data as Map,
    );

    return Map<String, dynamic>.from(
      data['store'] as Map,
    );
  }

  Future<void> updateStoreStatus({
    required String storeId,
    required bool isOpen,
  }) async {
    await _apiClient.patch(
      '/merchant/store/$storeId/status',
      data: {
        'isOpen': isOpen,
      },
    );
  }
}
