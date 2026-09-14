import '../../core/network/api_client.dart';

class DeliveryOrdersApiService {
  DeliveryOrdersApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _apiClient.get('/delivery/orders');

    final data = Map<String, dynamic>.from(response.data as Map);

    final orders = data['orders'] as List<dynamic>? ?? [];

    return orders
        .map((order) => Map<String, dynamic>.from(order as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final response = await _apiClient.get('/delivery/orders/history');
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['orders'] as List<dynamic>? ?? [])
        .map((order) => Map<String, dynamic>.from(order as Map))
        .toList();
  }

  Future<void> acceptOrder(String orderId) async {
    await _apiClient.patch('/delivery/orders/$orderId/accept');
  }

  Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    await _apiClient.patch(
      '/delivery/orders/$orderId/status',
      data: {'status': status},
    );
  }

  Future<String?> generateDeliveryOtp(String orderId) async {
    final response = await _apiClient.post(
      '/delivery/orders/$orderId/otp/generate',
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return data['otp']?.toString();
  }

  Future<void> verifyDeliveryOtp({
    required String orderId,
    required String otp,
  }) async {
    await _apiClient.post(
      '/delivery/orders/$orderId/otp/verify',
      data: {'otp': otp},
    );
  }
}
