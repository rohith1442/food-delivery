import 'package:flutter/material.dart';

class AppBranding {
  const AppBranding({
    required this.appName,
    required this.shortName,
    required this.tagline,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.currencySymbol,
    required this.supportPhone,
  });
  final String appName,
      shortName,
      tagline,
      logoUrl,
      primaryColor,
      secondaryColor,
      accentColor,
      currencySymbol,
      supportPhone;
  static const fallback = AppBranding(
    appName: 'Fresh Food Delivery',
    shortName: 'Fresh Food',
    tagline: 'Deliver fast. Earn more.',
    logoUrl: '',
    primaryColor: '#159447',
    secondaryColor: '#FF6B00',
    accentColor: '#F5B400',
    currencySymbol: '₹',
    supportPhone: '',
  );
  factory AppBranding.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    String value(Object? input, String fallbackValue) {
      final text = input?.toString().trim();
      return text?.isNotEmpty == true ? text! : fallbackValue;
    }

    return AppBranding(
      appName: value(json['appName'], fallback.appName),
      shortName: value(json['shortName'], fallback.shortName),
      tagline: value(json['tagline'], fallback.tagline),
      logoUrl: json['logoUrl']?.toString().trim() ?? '',
      primaryColor: value(json['primaryColor'], fallback.primaryColor),
      secondaryColor: value(json['secondaryColor'], fallback.secondaryColor),
      accentColor: value(json['accentColor'], fallback.accentColor),
      currencySymbol: value(json['currencySymbol'], fallback.currencySymbol),
      supportPhone: json['supportPhone']?.toString().trim() ?? '',
    );
  }
  Color get primary => _color(primaryColor, const Color(0xFF159447));
  Color get secondary => _color(secondaryColor, const Color(0xFFFF6B00));
  Color get accent => _color(accentColor, const Color(0xFFF5B400));
  static Color _color(String value, Color fallback) {
    final clean = value.replaceFirst('#', '').trim();
    final parsed = clean.length == 6
        ? int.tryParse('FF$clean', radix: 16)
        : null;
    return parsed == null ? fallback : Color(parsed);
  }
}

class AppBrandingController extends ChangeNotifier {
  AppBrandingController._();
  static final instance = AppBrandingController._();
  AppBranding _branding = AppBranding.fallback;
  AppBranding get branding => _branding;
  void update(AppBranding branding) {
    _branding = branding;
    notifyListeners();
  }
}
