import '../../core/network/api_client.dart';

class ReviewsApiService {
  ReviewsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createReview({
    required String orderId,
    required int rating,
    String comment = '',
  }) async {
    final response = await _apiClient.post(
      '/reviews',
      data: {'orderId': orderId, 'rating': rating, 'comment': comment.trim()},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>?> getOrderReview(String orderId) async {
    final response = await _apiClient.get('/reviews/order/$orderId');
    final data = Map<String, dynamic>.from(response.data as Map);
    final review = data['review'];

    if (review is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(review);
  }

  Future<Map<String, dynamic>> getStoreReviews(String storeId) async {
    final response = await _apiClient.get('/reviews/store/$storeId');

    return Map<String, dynamic>.from(response.data as Map);
  }
}
