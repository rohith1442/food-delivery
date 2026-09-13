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

  final String appName;
  final String shortName;
  final String tagline;
  final String logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String currencySymbol;
  final String supportPhone;

  static const fallback = AppBranding(
    appName: 'Fresh Food Merchant',
    shortName: 'Fresh Food',
    tagline: 'Manage your store with ease',
    logoUrl: '',
    primaryColor: '#159447',
    secondaryColor: '#FF6B00',
    accentColor: '#F5B400',
    currencySymbol: '₹',
    supportPhone: '',
  );

  factory AppBranding.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;

    return AppBranding(
      appName: _text(json['appName'], fallback.appName),
      shortName: _text(json['shortName'], fallback.shortName),
      tagline: _text(json['tagline'], fallback.tagline),
      logoUrl: json['logoUrl']?.toString().trim() ?? '',
      primaryColor: json['primaryColor']?.toString() ?? fallback.primaryColor,
      secondaryColor:
          json['secondaryColor']?.toString() ?? fallback.secondaryColor,
      accentColor: json['accentColor']?.toString() ?? fallback.accentColor,
      currencySymbol:
          json['currencySymbol']?.toString() ?? fallback.currencySymbol,
      supportPhone: json['supportPhone']?.toString() ?? '',
    );
  }

  Color get primary => _parseColor(primaryColor, const Color(0xFF159447));
  Color get secondary => _parseColor(secondaryColor, const Color(0xFFFF6B00));
  Color get accent => _parseColor(accentColor, const Color(0xFFF5B400));

  static String _text(Object? value, String fallback) {
    final text = value?.toString().trim();
    return text?.isNotEmpty == true ? text! : fallback;
  }

  static Color _parseColor(String value, Color fallback) {
    final cleaned = value.replaceFirst('#', '').trim();
    if (cleaned.length != 6) return fallback;

    final parsed = int.tryParse('FF$cleaned', radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}

class AppBrandingController extends ChangeNotifier {
  AppBrandingController._();

  static final AppBrandingController instance = AppBrandingController._();

  AppBranding _branding = AppBranding.fallback;

  AppBranding get branding => _branding;

  void update(AppBranding branding) {
    _branding = branding;
    notifyListeners();
  }
}
