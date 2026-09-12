import '../../core/network/api_client.dart';

class AuthApiService {
  AuthApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _apiClient.get('/auth/me');

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    final response = await _apiClient.patch(
      '/auth/profile',
      data: {'name': name.trim()},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> registerCustomer({String? name}) async {
    final response = await _apiClient.post(
      '/auth/register/customer',
      data: {if (name != null && name.trim().isNotEmpty) 'name': name.trim()},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> ensureCustomerProfile() async {
    final currentUser = await getCurrentUser();

    final user = currentUser['user'];

    if (user != null) {
      return currentUser;
    }

    await registerCustomer();

    return getCurrentUser();
  }
}
