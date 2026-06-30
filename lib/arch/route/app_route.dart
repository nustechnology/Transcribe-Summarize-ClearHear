import 'package:get/get.dart';

import '../../screen/home/bindings/home_binding.dart';
import '../../screen/home/home_widget.dart';

abstract class AppRoutes {
  static const home = '/home';
}

class AppPages {
  static const initial = AppRoutes.home;

  static final routes = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
  ];
}
