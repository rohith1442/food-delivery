import 'package:flutter/foundation.dart';

class HomeSectionConfig {
  final String id;
  final bool enabled;
  final int sortOrder;

  const HomeSectionConfig({
    required this.id,
    required this.enabled,
    required this.sortOrder,
  });

  factory HomeSectionConfig.fromJson(Map<String, dynamic> json) {
    return HomeSectionConfig(
      id: json['id']?.toString() ?? '',
      enabled: json['enabled'] == true,
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
    );
  }
}

class PromoBannerConfig {
  final bool enabled;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String actionType;
  final String actionValue;

  const PromoBannerConfig({
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.actionType,
    required this.actionValue,
  });

  factory PromoBannerConfig.fromJson(Map<String, dynamic> json) {
    return PromoBannerConfig(
      enabled: json['enabled'] != false,
      title: json['title']?.toString() ?? 'Fresh deals for you',
      subtitle: json['subtitle']?.toString() ?? 'Order your favourites today',
      imageUrl: json['imageUrl']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? 'NONE',
      actionValue: json['actionValue']?.toString() ?? '',
    );
  }
}

class HomeConfig {
  final List<String> enabledModules;
  final List<HomeSectionConfig> sections;
  final PromoBannerConfig promoBanner;

  const HomeConfig({
    required this.enabledModules,
    required this.sections,
    required this.promoBanner,
  });

  static const fallback = HomeConfig(
    enabledModules: ['food', 'grocery'],
    sections: [
      HomeSectionConfig(id: 'modules', enabled: true, sortOrder: 1),
      HomeSectionConfig(id: 'promo', enabled: true, sortOrder: 2),
      HomeSectionConfig(id: 'categories', enabled: true, sortOrder: 3),
      HomeSectionConfig(id: 'nearby', enabled: true, sortOrder: 4),
    ],
    promoBanner: PromoBannerConfig(
      enabled: true,
      title: 'Fresh deals for you',
      subtitle: 'Order your favourites today',
      imageUrl: '',
      actionType: 'NONE',
      actionValue: '',
    ),
  );

  factory HomeConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return fallback;
    }

    final modules = (json['enabledModules'] as List<dynamic>?)
        ?.map((module) => module.toString())
        .where((module) => module.isNotEmpty)
        .toList();

    final sections = (json['sections'] as List<dynamic>?)
        ?.whereType<Map>()
        .map(
          (section) =>
              HomeSectionConfig.fromJson(Map<String, dynamic>.from(section)),
        )
        .where((section) => section.id.isNotEmpty)
        .toList();

    final promoJson = json['promoBanner'] is Map
        ? Map<String, dynamic>.from(json['promoBanner'] as Map)
        : null;

    return HomeConfig(
      enabledModules: modules == null || modules.isEmpty
          ? fallback.enabledModules
          : modules,
      sections: sections == null || sections.isEmpty
          ? fallback.sections
          : sections,
      promoBanner: PromoBannerConfig.fromJson(promoJson ?? <String, dynamic>{}),
    );
  }

  bool moduleEnabled(String moduleId) => enabledModules.contains(moduleId);
}

class HomeConfigController extends ChangeNotifier {
  HomeConfigController._();

  static final HomeConfigController instance = HomeConfigController._();

  HomeConfig _config = HomeConfig.fallback;

  HomeConfig get config => _config;

  void update(HomeConfig config) {
    _config = config;
    notifyListeners();
  }
}
