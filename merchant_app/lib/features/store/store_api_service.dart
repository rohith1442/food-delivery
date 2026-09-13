import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class StoreApiService {
  StoreApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>?> getStore() async {
    try {
      final response = await _apiClient.get('/merchant/store');

      final data = Map<String, dynamic>.from(response.data as Map);

      return Map<String, dynamic>.from(data['store'] as Map);
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
    required double latitude,
    required double longitude,
    required double minimumOrder,
  }) async {
    final response = await _apiClient.post(
      '/merchant/store',
      data: {
        'name': name,
        'moduleId': moduleId,
        'zoneId': zoneId,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'minimumOrder': minimumOrder,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return Map<String, dynamic>.from(data['store'] as Map);
  }

  Future<void> updateStoreStatus({
    required String storeId,
    required bool isOpen,
  }) async {
    await _apiClient.patch(
      '/merchant/store/$storeId/status',
      data: {'isOpen': isOpen},
    );
  }

  Future<String> uploadStoreImage({required String filePath}) async {
    final response = await _apiClient.uploadFile(
      '/merchant/store/image',
      filePath: filePath,
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    final imageUrl = data['imageUrl']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Store image upload failed');
    }

    return imageUrl;
  }

  Future<void> updateStoreImage({required String imageUrl}) async {
    await _apiClient.patch(
      '/merchant/store/image',
      data: {'imageUrl': imageUrl},
    );
  }

  Future<Map<String, dynamic>> updateStore({
    required String storeId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _apiClient.patch(
      '/merchant/store/$storeId',
      data: data,
    );

    final responseData = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(responseData['store'] as Map);
  }
}
