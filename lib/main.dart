import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'arch/route/app_route.dart';
import 'lang/string_keys.dart';
import 'lang/translation.dart';
import 'service/database_service.dart';
import 'style/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Translation.load();

  // Register DatabaseService as a permanent global singleton.
  // All repository bindings use Get.find<DatabaseService>() to access it.
  Get.put<DatabaseService>(DatabaseService(), permanent: true);

  Get.locale = const Locale('en', 'US');
  Get.fallbackLocale = const Locale('en', 'US');

  runApp(const ClearHearApp());
}

class ClearHearApp extends StatelessWidget {
  const ClearHearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: StringKeys.appTitle.tr,
      debugShowCheckedModeBanner: false,
      translations: Translation.instance,
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
