import '../../core/network/api_client.dart';

class MerchantOrdersApiService {
  MerchantOrdersApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _apiClient.get('/merchant/orders');

    final data = Map<String, dynamic>.from(response.data as Map);

    final orders = data['orders'] as List<dynamic>? ?? [];

    return orders
        .map((order) => Map<String, dynamic>.from(order as Map))
        .toList();
  }

  Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    await _apiClient.patch(
      '/merchant/orders/$orderId/status',
      data: {'status': status},
    );
  }
}
