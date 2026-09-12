import '../../core/network/api_client.dart';

class StoresApiService {
  StoresApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> search({
    required String zoneId,
    required String query,
  }) async {
    final response = await _apiClient.get(
      '/search',
      queryParameters: {'zoneId': zoneId, 'q': query.trim()},
    );

    if (response.data is! Map) {
      throw const FormatException('Invalid search response.');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getModules() async {
    final response = await _apiClient.get('/modules');

    final data = response.data;

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getStores({
    String? moduleId,
    String? zoneId,
    String? category,
  }) async {
    final query = <String, dynamic>{};

    if (moduleId != null && moduleId.isNotEmpty) {
      query['moduleId'] = moduleId;
    }

    if (zoneId != null && zoneId.isNotEmpty) {
      query['zoneId'] = zoneId;
    }

    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }

    final response = await _apiClient.get('/stores', queryParameters: query);

    return _extractList(response.data, key: 'stores');
  }

  Future<List<Map<String, dynamic>>> getHomeCategories({
    required String moduleId,
    required String zoneId,
  }) async {
    final response = await _apiClient.get(
      '/categories',
      queryParameters: {'moduleId': moduleId, 'zoneId': zoneId},
    );

    return _extractList(response.data, key: 'categories');
  }

  Future<List<Map<String, dynamic>>> getCategories(String storeId) async {
    final response = await _apiClient.get('/stores/$storeId/categories');

    return _extractList(response.data, key: 'categories');
  }

  Future<List<Map<String, dynamic>>> getProducts(
    String storeId, {
    String? categoryId,
  }) async {
    final query = <String, dynamic>{};

    if (categoryId != null && categoryId.isNotEmpty) {
      query['categoryId'] = categoryId;
    }

    final response = await _apiClient.get(
      '/stores/$storeId/products',
      queryParameters: query,
    );

    return _extractList(response.data, key: 'products');
  }

  List<Map<String, dynamic>> _extractList(
    dynamic responseData, {
    required String key,
  }) {
    dynamic rawList;

    // Backend directly returns:
    // [
    //   {...},
    //   {...}
    // ]
    if (responseData is List) {
      rawList = responseData;
    }
    // Backend returns:
    // {
    //   "stores": [...]
    // }
    else if (responseData is Map) {
      rawList = responseData[key];
    }

    if (rawList == null) {
      return [];
    }

    if (rawList is! List) {
      throw FormatException('Invalid API response: "$key" must be a list.');
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
