import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/prayer_controller.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AppController extends GetxController {
  AppController(this._storage);

  final StorageService _storage;
  StreamSubscription<String>? _notificationPayloadSub;
  Timer? _dayTicker;
  NotificationService get _notificationService =>
      Get.find<NotificationService>();

  static const List<DailyDhikr> dailyDhikrItems = [
    DailyDhikr(
      id: 0,
      text: 'سبحان الله وبحمده',
      reference: 'من قالها مائة مرة حطت خطاياه وإن كانت مثل زبد البحر',
    ),
    DailyDhikr(
      id: 1,
      text:
          'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
      reference: 'ذكر عظيم يجدد معنى التوحيد في القلب',
    ),
    DailyDhikr(
      id: 2,
      text: 'أستغفر الله العظيم وأتوب إليه',
      reference: 'باب واسع للطمأنينة والرجوع إلى الله',
    ),
    DailyDhikr(
      id: 3,
      text: 'اللهم صل وسلم على نبينا محمد',
      reference: 'صلاة وسلام على رسول الله صلى الله عليه وسلم',
    ),
    DailyDhikr(
      id: 4,
      text: 'لا حول ولا قوة إلا بالله',
      reference: 'كنز من كنوز الجنة',
    ),
  ];

  // Navigation / Route state
  // 0: Home, 1: Salat, 2: Quran, 3: Sunnah, 5: Profile
  final RxInt activePageIndex = 0.obs;

  // Language state
  late final RxString currentLanguage;

  // Theme state
  late final RxBool isNightMode;

  // User profile state
  late final RxString userName;

  // Dhikr reminders
  late final RxBool dhikrReminderEnabled;
  late final Rx<DhikrReminderMode> dhikrReminderMode;
  late final RxInt dhikrDailyTarget;
  late final RxInt dhikrCompletedCount;
  late final RxString dhikrCompletionDate;
  late final RxInt selectedDhikrId;

  // App simulation states
  final RxInt tasbihCount = 11.obs; // out of 33 (33%)
  final RxDouble prayerProgress = 0.75.obs; // 75% progress to Maghrib
  final RxString currentDayKey = ''.obs;

  @override
  void onInit() {
    super.onInit();
    currentLanguage = _storage.read<String>('language', 'ar').obs;
    isNightMode = _storage.read<bool>('night_mode', true).obs;
    userName = _storage.read<String>('user_name', '').obs;
    dhikrReminderEnabled = _storage
        .read<bool>('dhikr_reminder_enabled', false)
        .obs;
    dhikrReminderMode = _readDhikrReminderMode().obs;
    dhikrDailyTarget = _storage.read<int>('dhikr_daily_target', 3).obs;
    dhikrCompletedCount = _storage.read<int>('dhikr_completed_count', 0).obs;
    dhikrCompletionDate = _storage
        .read<String>('dhikr_completion_date', '')
        .obs;
    _resetDhikrProgressIfNeeded();
    selectedDhikrId = _dailyDhikrIdForToday().obs;
    if (Get.isRegistered<NotificationService>()) {
      _notificationPayloadSub = _notificationService.payloads.listen(
        handleNotificationPayload,
      );
    }
    if (dhikrReminderEnabled.value && Get.isRegistered<NotificationService>()) {
      unawaited(rescheduleDhikrReminders());
    }
    _startDayTicker();
  }

  @override
  void onClose() {
    _notificationPayloadSub?.cancel();
    _dayTicker?.cancel();
    super.onClose();
  }

  bool get hasUserName => userName.value.trim().isNotEmpty;

  DailyDhikr get currentDailyDhikr {
    final id = selectedDhikrId.value;
    return dailyDhikrItems.firstWhere(
      (dhikr) => dhikr.id == id,
      orElse: () => dailyDhikrItems.first,
    );
  }

  String get currentDailyDhikrPayload => 'dhikr:${currentDailyDhikr.id}';

  String get dhikrProgressLabel =>
      '${dhikrCompletedCount.value.clamp(0, dhikrDailyTarget.value)} / ${dhikrDailyTarget.value}';

  double get dhikrProgressValue {
    if (dhikrDailyTarget.value <= 0) return 0;
    return (dhikrCompletedCount.value / dhikrDailyTarget.value).clamp(0.0, 1.0);
  }

  String get dhikrReminderModeLabel {
    return switch (dhikrReminderMode.value) {
      DhikrReminderMode.onceDaily => 'dhikr_mode_once_daily'.tr,
      DhikrReminderMode.morningEvening => 'dhikr_mode_morning_evening'.tr,
      DhikrReminderMode.afterPrayers => 'dhikr_mode_after_prayers'.tr,
    };
  }

  Future<void> setUserName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    userName.value = cleanName;
    await _storage.write('user_name', cleanName);
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

  Future<void> setDhikrReminderEnabled(bool enabled) async {
    dhikrReminderEnabled.value = enabled;
    await _storage.write('dhikr_reminder_enabled', enabled);
    if (enabled) {
      await rescheduleDhikrReminders();
    } else {
      await _notificationService.cancelDhikrReminders();
    }
  }

  Future<void> setDhikrReminderMode(DhikrReminderMode mode) async {
    dhikrReminderMode.value = mode;
    await _storage.write('dhikr_reminder_mode', mode.name);
    await rescheduleDhikrReminders();
  }

  Future<void> setDhikrDailyTarget(int target) async {
    dhikrDailyTarget.value = target;
    await _storage.write('dhikr_daily_target', target);
    if (dhikrCompletedCount.value > target) {
      dhikrCompletedCount.value = target;
      await _storage.write('dhikr_completed_count', target);
    }
  }

  Future<void> completeCurrentDhikr() async {
    _resetDhikrProgressIfNeeded();
    if (dhikrCompletedCount.value < dhikrDailyTarget.value) {
      dhikrCompletedCount.value++;
      await _storage.write('dhikr_completed_count', dhikrCompletedCount.value);
      await _storage.write('dhikr_completion_date', _todayKey());
    }
    incrementTasbih();
  }

  Future<void> rescheduleDhikrReminders() async {
    if (!Get.isRegistered<NotificationService>()) return;
    if (dhikrReminderEnabled.value) {
      await _notificationService.scheduleDhikrReminders(
        mode: dhikrReminderMode.value,
        dhikrText: currentDailyDhikr.text,
        payload: currentDailyDhikrPayload,
        prayerDay: Get.isRegistered<PrayerController>()
            ? Get.find<PrayerController>().prayerDay.value
            : null,
      );
    } else {
      await _notificationService.cancelDhikrReminders();
    }
  }

  void handleNotificationPayload(String payload) {
    if (payload.startsWith('dhikr:')) {
      final id = int.tryParse(payload.substring('dhikr:'.length));
      if (id != null) {
        selectedDhikrId.value = id;
      }
      navigateToPage(0);
      Future<void>.delayed(
        const Duration(milliseconds: 2100),
        showCurrentDhikr,
      );
      return;
    }

    if (payload.startsWith('prayer:')) {
      final prayerKey = payload.substring('prayer:'.length);
      navigateToPage(1);
      Future<void>.delayed(const Duration(milliseconds: 2100), () {
        Get.snackbar(
          'prayer_times'.tr,
          '${prayerKey.tr} - ${'notification_opened'.tr}',
          snackPosition: SnackPosition.BOTTOM,
        );
      });
    }
  }

  void showCurrentDhikr() {
    if (Get.isBottomSheetOpen == true) return;
    final dhikr = currentDailyDhikr;
    Get.bottomSheet<void>(
      _DhikrDetailSheet(dhikr: dhikr),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
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

  DhikrReminderMode _readDhikrReminderMode() {
    final raw = _storage.read<String>(
      'dhikr_reminder_mode',
      DhikrReminderMode.onceDaily.name,
    );
    return DhikrReminderMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => DhikrReminderMode.onceDaily,
    );
  }

  void _resetDhikrProgressIfNeeded() {
    final today = _todayKey();
    if (dhikrCompletionDate.value == today) return;
    dhikrCompletionDate.value = today;
    dhikrCompletedCount.value = 0;
    unawaited(_storage.write('dhikr_completion_date', today));
    unawaited(_storage.write('dhikr_completed_count', 0));
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _dailyDhikrIdForToday() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year);
    final dayIndex = now.difference(firstDayOfYear).inDays;
    return dailyDhikrItems[dayIndex % dailyDhikrItems.length].id;
  }

  void _startDayTicker() {
    currentDayKey.value = _todayKey();
    if (_isWidgetTestBinding) return;
    _dayTicker?.cancel();
    _dayTicker = Timer.periodic(const Duration(minutes: 15), (_) {
      final today = _todayKey();
      if (currentDayKey.value == today) return;
      currentDayKey.value = today;
      selectedDhikrId.value = _dailyDhikrIdForToday();
      _resetDhikrProgressIfNeeded();
      unawaited(rescheduleDhikrReminders());
    });
  }

  bool get _isWidgetTestBinding => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');
}

class DailyDhikr {
  const DailyDhikr({
    required this.id,
    required this.text,
    required this.reference,
  });

  final int id;
  final String text;
  final String reference;
}

class _DhikrDetailSheet extends StatelessWidget {
  const _DhikrDetailSheet({required this.dhikr});

  final DailyDhikr dhikr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: goldColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.self_improvement, color: goldColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ذكر اليوم',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: goldColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                dhikr.text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  height: 1.7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                dhikr.reference,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  await Get.find<AppController>().completeCurrentDhikr();
                  Get.back<void>();
                },
                icon: const Icon(Icons.touch_app),
                label: Text('dhikr_done'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
