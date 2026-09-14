import '../../core/network/api_client.dart';

class DeliveryOnboardingApiService {
  DeliveryOnboardingApiService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  Future<Map<String, dynamic>> get() async => Map<String, dynamic>.from(
    (await _api.get('/delivery/onboarding')).data as Map,
  );
  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
        (await _api.put('/delivery/onboarding', data: data)).data as Map,
      );
  Future<void> submit() async {
    await _api.post('/delivery/onboarding/submit');
  }

  Future<void> addDocument(Map<String, dynamic> data) async {
    await _api.post('/delivery/onboarding/documents', data: data);
  }
}
