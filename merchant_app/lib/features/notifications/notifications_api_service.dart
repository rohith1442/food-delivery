import '../../core/network/api_client.dart';

class NotificationsApiService {
  NotificationsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _apiClient.get('/notifications');
    final data = Map<String, dynamic>.from(response.data as Map);
    final values = data['notifications'];
    if (values is! List) return [];

    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _apiClient.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _apiClient.patch('/notifications/read-all');
  }
}
