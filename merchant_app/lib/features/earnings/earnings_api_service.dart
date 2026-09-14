import '../../core/network/api_client.dart';

class EarningsApiService {
  EarningsApiService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  Future<Map<String, dynamic>> getSummary() async {
    final response = await _api.get('/merchant/earnings/summary');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _api.get('/merchant/earnings/transactions');
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['transactions'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
