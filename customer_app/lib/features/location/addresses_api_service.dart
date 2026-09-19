import '../../core/network/api_client.dart';

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    required this.latitude,
    required this.longitude,
    required this.zoneId,
    required this.isDefault,
  });

  final String id;
  final String label;
  final String address;
  final String contactName;
  final String contactPhone;
  final double latitude;
  final double longitude;
  final String zoneId;
  final bool isDefault;

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Home',
      address: json['address']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      zoneId: json['zoneId']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }
}

class AddressesApiService {
  AddressesApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<CustomerAddress>> getAddresses() async {
    final response = await _apiClient.get('/addresses');

    final responseData = response.data;

    if (responseData is! Map) {
      throw const FormatException('Invalid addresses response');
    }

    final data = Map<String, dynamic>.from(responseData);

    final rawAddresses = data['addresses'];

    if (rawAddresses is! List) {
      return [];
    }

    return rawAddresses
        .whereType<Map>()
        .map(
          (item) => CustomerAddress.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<CustomerAddress> createAddress({
    required String address,
    required double latitude,
    required double longitude,
    required String contactName,
    required String contactPhone,
    String label = 'Home',
  }) async {
    final response = await _apiClient.post(
      '/addresses',
      data: {
        'label': label,
        'address': address,
        'contactName': contactName.trim(),
        'contactPhone': contactPhone.trim(),
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    final responseData = response.data;

    if (responseData is! Map) {
      throw const FormatException('Invalid create address response');
    }

    final data = Map<String, dynamic>.from(responseData);

    final rawAddress = data['address'];

    if (rawAddress is! Map) {
      throw const FormatException('Address information is missing');
    }

    return CustomerAddress.fromJson(Map<String, dynamic>.from(rawAddress));
  }

  Future<void> setDefaultAddress(String addressId) async {
    await _apiClient.patch('/addresses/$addressId/default');
  }

  Future<void> deleteAddress(String addressId) async {
    await _apiClient.delete('/addresses/$addressId');
  }
}
