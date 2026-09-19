import '../../core/network/api_client.dart';

class EarningsApiService {
  EarningsApiService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  String _query(int? days) => days == null ? '' : '?days=$days';

  Future<Map<String, dynamic>> getSummary({int? days}) async {
    final response = await _api.get(
      '/merchant/earnings/summary${_query(days)}',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getTransactions({int? days}) async {
    final response = await _api.get(
      '/merchant/earnings/transactions${_query(days)}',
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['transactions'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
