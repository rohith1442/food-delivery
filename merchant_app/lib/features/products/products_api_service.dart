import '../../core/network/api_client.dart';

class ProductsApiService {
  ProductsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _apiClient.get('/merchant/categories');

    final data = Map<String, dynamic>.from(response.data as Map);

    final categories = data['categories'] as List<dynamic>? ?? [];

    return categories
        .map((category) => Map<String, dynamic>.from(category as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createCategory({required String name}) async {
    final response = await _apiClient.post(
      '/merchant/categories',
      data: {'name': name},
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return Map<String, dynamic>.from(data['category'] as Map);
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {
    await _apiClient.patch(
      '/merchant/categories/$categoryId',
      data: {'name': name, 'sortOrder': sortOrder, 'isActive': isActive},
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final response = await _apiClient.get('/merchant/products');

    final data = Map<String, dynamic>.from(response.data as Map);

    final products = data['products'] as List<dynamic>? ?? [];

    return products
        .map((product) => Map<String, dynamic>.from(product as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createProduct({
    required String name,
    required String description,
    required String categoryId,
    required double price,
    required int stock,
    String? imageUrl,
  }) async {
    final response = await _apiClient.post(
      '/merchant/products',
      data: {
        'name': name,
        'description': description,
        'categoryId': categoryId,
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return Map<String, dynamic>.from(data['product'] as Map);
  }

  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    required String name,
    required String description,
    required String categoryId,
    required double price,
    required int stock,
    String? imageUrl,
  }) async {
    final response = await _apiClient.patch(
      '/merchant/products/$productId',
      data: {
        'name': name,
        'description': description,
        'categoryId': categoryId,
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return Map<String, dynamic>.from(data['product'] as Map);
  }

  Future<void> updateAvailability({
    required String productId,
    required bool isAvailable,
  }) async {
    await _apiClient.patch(
      '/merchant/products/$productId/availability',
      data: {'isAvailable': isAvailable},
    );
  }

  Future<void> deleteProduct(String productId) async {
    await _apiClient.delete('/merchant/products/$productId');
  }

  Future<String> uploadProductImage({required String filePath}) async {
    final response = await _apiClient.uploadFile(
      '/merchant/products/images',
      filePath: filePath,
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    final imageUrl = data['imageUrl']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Image upload failed');
    }

    return imageUrl;
  }

  Future<String> uploadCategoryImage({required String filePath}) async {
    final response = await _apiClient.uploadFile(
      '/merchant/categories/images',
      filePath: filePath,
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    final imageUrl = data['imageUrl']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Category image upload failed');
    }

    return imageUrl;
  }

  Future<void> updateCategoryImage({
    required String categoryId,
    required String imageUrl,
  }) async {
    await _apiClient.patch(
      '/merchant/categories/$categoryId/image',
      data: {'imageUrl': imageUrl},
    );
  }
}
