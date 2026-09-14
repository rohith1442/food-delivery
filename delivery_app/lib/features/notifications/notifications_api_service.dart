import '../../core/network/api_client.dart';

class NotificationsApiService {
  NotificationsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();
  final ApiClient _apiClient;
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _apiClient.get('/notifications');
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['notifications'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> markRead(String id) =>
      _apiClient.patch('/notifications/$id/read').then((_) {});
  Future<void> markAllRead() =>
      _apiClient.patch('/notifications/read-all').then((_) {});
}
