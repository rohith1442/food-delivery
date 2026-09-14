import '../../core/network/api_client.dart';

class ContentApiService {
  ContentApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();
  final ApiClient _apiClient;
  Future<Map<String, dynamic>?> getContent(String type) async {
    final response = await _apiClient.get('/settings/content/$type');
    final data = Map<String, dynamic>.from(response.data as Map);
    final content = data['content'];
    return content is Map ? Map<String, dynamic>.from(content) : null;
  }
}
