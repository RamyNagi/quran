import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppController extends GetxController {
  // Navigation / Route state
  // 0: Landing Page, 1: Home Page/Dashboard, 2: Salat details, 3: Quran explorer, 4: Ummah, 5: Profile
  final RxInt activePageIndex = 0.obs;

  // Language state
  final RxString currentLanguage = 'en'.obs;

  // Theme state
  final RxBool isNightMode = true.obs;

  // App simulation states
  final RxInt tasbihCount = 11.obs; // out of 33 (33%)
  final RxDouble prayerProgress = 0.75.obs; // 75% progress to Maghrib

  void changeLanguage(String langCode) {
    currentLanguage.value = langCode;
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
