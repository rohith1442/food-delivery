import '../../core/network/api_client.dart';

class EarningsApiService {
  EarningsApiService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Map<String, dynamic>> getEarnings({int? days}) async {
    final query = days == null ? '' : '?days=$days';
    final response = await _api.get('/delivery/earnings$query');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
