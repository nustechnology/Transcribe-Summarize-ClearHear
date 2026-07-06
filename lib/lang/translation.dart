import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

class Translation extends Translations {
  Translation._();

  static final Translation instance = Translation._();

  static const _assetPaths = {
    'en_US': 'assets/i18n/en_us.json',
    'vi_VN': 'assets/i18n/vi_vn.json',
  };

  static final Map<String, Map<String, String>> _keys = {};

  static Future<void> load() async {
    _keys.clear();

    for (final entry in _assetPaths.entries) {
      final jsonString = await rootBundle.loadString(entry.value);
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      _keys[entry.key] = decoded.map(
        (key, value) => MapEntry(key, value as String),
      );
    }

    _keys['en'] = Map<String, String>.from(_keys['en_US']!);
    _keys['vi'] = Map<String, String>.from(_keys['vi_VN']!);

    Get.addTranslations(_keys);
  }

  @override
  Map<String, Map<String, String>> get keys => _keys;
}
