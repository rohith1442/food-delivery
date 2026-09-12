import '../../core/network/api_client.dart';

class PaymentsApiService {
  PaymentsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createRazorpayOrder({
    required String storeId,
    required String addressId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.post(
      '/payments/razorpay/order',
      data: {'storeId': storeId, 'addressId': addressId, 'items': items},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _apiClient.post(
      '/payments/razorpay/verify',
      data: {
        'paymentId': paymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}
