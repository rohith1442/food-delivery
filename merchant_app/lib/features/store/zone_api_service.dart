import '../../core/network/api_client.dart';

class ZoneApiService {
  ZoneApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>?> resolveZone({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.get(
      '/zones/resolve',
      queryParameters: {'latitude': latitude, 'longitude': longitude},
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['serviceable'] != true || data['zone'] is! Map) return null;

    return Map<String, dynamic>.from(data['zone'] as Map);
  }
}
