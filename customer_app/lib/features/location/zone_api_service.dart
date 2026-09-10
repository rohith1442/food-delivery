import '../../core/network/api_client.dart';

class ZoneResolution {
  const ZoneResolution({required this.serviceable, this.zoneId, this.zoneName});

  final bool serviceable;
  final String? zoneId;
  final String? zoneName;
}

class ZoneApiService {
  ZoneApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ZoneResolution> resolveZone({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.get(
      '/zones/resolve',
      queryParameters: {'latitude': latitude, 'longitude': longitude},
    );

    final responseData = response.data;

    if (responseData is! Map) {
      throw const FormatException('Invalid zone response');
    }

    final data = Map<String, dynamic>.from(responseData);

    final serviceable = data['serviceable'] == true;

    if (!serviceable) {
      return const ZoneResolution(serviceable: false);
    }

    final rawZone = data['zone'];

    if (rawZone is! Map) {
      throw const FormatException('Zone information is missing');
    }

    final zone = Map<String, dynamic>.from(rawZone);

    final zoneId = zone['id']?.toString().trim();

    if (zoneId == null || zoneId.isEmpty) {
      throw const FormatException('Zone ID is missing');
    }

    return ZoneResolution(
      serviceable: true,
      zoneId: zoneId,
      zoneName: zone['name']?.toString(),
    );
  }
}
