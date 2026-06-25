import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hayah/controllers/app_controller.dart';
import 'package:hayah/localization/app_translations.dart';
import 'package:hayah/services/storage_service.dart';
import 'package:hayah/widgets/app_bottom_nav.dart';

class FakeStorageService extends StorageService {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<void> init() async {}

  @override
  T read<T>(String key, T fallback) {
    final value = _values[key];
    return value is T ? value : fallback;
  }

  @override
  Future<void> write<T>(String key, T value) async {
    _values[key] = value;
  }
}

void main() {
  tearDown(Get.reset);

  testWidgets('bottom navigation switches to Quran tab', (tester) async {
    final storage = FakeStorageService();
    final controller = AppController(storage);
    Get.put<AppController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        home: const Scaffold(bottomNavigationBar: AppBottomNav(currentIndex: 0)),
      ),
    );

    await tester.tap(find.text('QURAN'));
    await tester.pump();

    expect(controller.activePageIndex.value, 2);
  });
}
