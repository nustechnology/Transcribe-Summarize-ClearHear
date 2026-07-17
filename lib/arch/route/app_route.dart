import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/screen/history/bindings/history_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/bindings/session_detail_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/session_detail_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/history/history_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/home/bindings/home_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/home/home_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/main/bindings/main_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/main/main_shell.dart';
import 'package:transcribe_summarize_clearhear/screen/development/bindings/development_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/development/development_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/bindings/settings_binding.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/settings_widget.dart';

abstract class AppRoutes {
  static const main = '/';
  static const live = '/live';
  static const history = '/history';
  static const settings = '/settings';
  static const development = '/settings/development';

  static const sessionDetail = '/history/detail/:id';
  static String sessionDetailPath(String id) => '/history/detail/$id';
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
          name: AppRoutes.sessionDetail,
          page: () => const SessionDetailView(),
          binding: SessionDetailBinding(),
        ),
        GetPage(
          name: AppRoutes.settings,
          page: () => const SettingsView(),
          binding: SettingsBinding(),
        ),
        GetPage(
          name: AppRoutes.development,
          page: () => const DevelopmentView(),
          binding: DevelopmentBinding(),
        ),
      ],
    ),
  ];
}
