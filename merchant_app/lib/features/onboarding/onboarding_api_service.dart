import '../../core/network/api_client.dart';

class MerchantOnboardingApiService {
  MerchantOnboardingApiService({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  Future<Map<String, dynamic>> get() async => Map<String, dynamic>.from(
    (await _api.get('/merchant/onboarding')).data as Map,
  );
  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
        (await _api.put('/merchant/onboarding', data: data)).data as Map,
      );
  Future<void> submit() async {
    await _api.post('/merchant/onboarding/submit');
  }

  Future<void> addDocument(Map<String, dynamic> data) async {
    await _api.post('/merchant/onboarding/documents', data: data);
  }
}
