import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/screen/history/bindings/history_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/history/history_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/home/bindings/home_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/home/home_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/main/bindings/main_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/main/main_shell.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/bindings/settings_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/settings_widget.dart';

abstract class AppRoutes {
  static const main = '/';
  static const live = '/live';
  static const history = '/history';
  static const settings = '/settings';
}

class AppPages {
  static const initial = AppRoutes.live;

  static final routes = [
    GetPage(
      name: AppRoutes.main,
      page: () => const MainShell(),
      binding: MainBinding(),
      participatesInRootNavigator: true,
      children: [
        GetPage(
          name: AppRoutes.live,
          page: () => const HomeView(),
          binding: HomeBinding(),
        ),
        GetPage(
          name: AppRoutes.history,
          page: () => const HistoryView(),
          binding: HistoryBinding(),
        ),
        GetPage(
          name: AppRoutes.settings,
          page: () => const SettingsView(),
          binding: SettingsBinding(),
        ),
      ],
    ),
  ];
}
