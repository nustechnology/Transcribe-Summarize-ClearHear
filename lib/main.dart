import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'arch/route/app_route.dart';
import 'lang/string_keys.dart';
import 'lang/translation.dart';
import 'screen/main/bindings/main_binding.dart';
import 'style/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Translation.load();

  Get.locale = const Locale('en', 'US');
  Get.fallbackLocale = const Locale('en', 'US');

  runApp(const ClearHearApp());
}

class ClearHearApp extends StatelessWidget {
  const ClearHearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp.router(
      title: StringKeys.appTitle.tr,
      debugShowCheckedModeBanner: false,
      translations: Translation.instance,
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      getPages: AppPages.routes,
      initialBinding: MainBinding(),
      routeInformationParser: GetInformationParser(
        initialRoute: AppPages.initial,
      ),
    );
  }
}
