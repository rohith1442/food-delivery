import '../../core/network/api_client.dart';

class OrdersApiService {
  OrdersApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    required String addressId,
    required String paymentMethod,
  }) async {
    final response = await _apiClient.post(
      '/orders',
      data: {
        'storeId': storeId,
        'items': items,
        'addressId': addressId,
        'paymentMethod': paymentMethod,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _apiClient.get('/orders');

    final data = Map<String, dynamic>.from(response.data as Map);

    final orders = data['orders'] as List<dynamic>? ?? [];

    return orders
        .map((order) => Map<String, dynamic>.from(order as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final response = await _apiClient.get('/orders/$orderId');

    return Map<String, dynamic>.from(response.data as Map);
  }
}
