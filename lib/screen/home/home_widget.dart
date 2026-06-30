import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../lang/string_keys.dart';
import 'controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(StringKeys.appTitle.tr),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(StringKeys.homeSubtitle.tr),
            const SizedBox(height: 16),
            Obx(
              () => Text(
                '${controller.counter.value}',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        tooltip: StringKeys.incrementTooltip.tr,
        child: const Icon(Icons.add),
      ),
    );
  }
}
