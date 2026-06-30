import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

class Translation extends Translations {
  static const _assetPaths = {
    'en_US': 'assets/i18n/en_us.json',
    'vi_VN': 'assets/i18n/vi_vn.json',
  };

  static final Map<String, Map<String, String>> _keys = {};

  static Future<void> load() async {
    for (final entry in _assetPaths.entries) {
      final jsonString = await rootBundle.loadString(entry.value);
      _keys[entry.key] = Map<String, String>.from(json.decode(jsonString));
    }
  }

  @override
  Map<String, Map<String, String>> get keys => _keys;
}
