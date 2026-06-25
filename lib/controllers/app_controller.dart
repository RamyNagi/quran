import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/storage_service.dart';

class AppController extends GetxController {
  AppController(this._storage);

  final StorageService _storage;

  // Navigation / Route state
  // 0: Home, 1: Salat, 2: Quran, 5: Profile
  final RxInt activePageIndex = 0.obs;

  // Language state
  late final RxString currentLanguage;

  // Theme state
  late final RxBool isNightMode;

  // App simulation states
  final RxInt tasbihCount = 11.obs; // out of 33 (33%)
  final RxDouble prayerProgress = 0.75.obs; // 75% progress to Maghrib

  @override
  void onInit() {
    super.onInit();
    currentLanguage = _storage.read<String>('language', 'en').obs;
    isNightMode = _storage.read<bool>('night_mode', true).obs;
  }

  Future<void> changeLanguage(String langCode) async {
    currentLanguage.value = langCode;
    await _storage.write('language', langCode);
    Get.updateLocale(Locale(langCode));
  }

  void toggleLanguage() {
    if (currentLanguage.value == 'en') {
      changeLanguage('ar');
    } else {
      changeLanguage('en');
    }
  }

  void toggleTheme() {
    isNightMode.toggle();
    _storage.write('night_mode', isNightMode.value);
    Get.changeThemeMode(isNightMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  void navigateToPage(int index) {
    activePageIndex.value = index;
  }

  void incrementTasbih() {
    if (tasbihCount.value < 33) {
      tasbihCount.value++;
    } else {
      tasbihCount.value = 0;
    }
  }
}
