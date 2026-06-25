import 'dart:async';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/prayer_day.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

class PrayerController extends GetxController {
  PrayerController(this._prayerService, this._notificationService);

  final PrayerService _prayerService;
  final NotificationService _notificationService;

  final Rxn<PrayerDay> prayerDay = Rxn<PrayerDay>();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<Duration> timeUntilNext = Duration.zero.obs;

  Timer? _ticker;

  @override
  void onInit() {
    super.onInit();
    prayerDay.value = _prayerService.loadFromCacheOrDefault();
    _startTicker();
    refreshPrayerTimes();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }

  Future<void> refreshPrayerTimes() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final day = await _prayerService.loadToday();
      prayerDay.value = day;
      try {
        await _notificationService.schedulePrayerDay(day);
      } catch (_) {
        errorMessage.value = 'notification_schedule_failed'.tr;
      }
    } catch (_) {
      errorMessage.value = 'location_fallback'.tr;
      prayerDay.value = _prayerService.loadFromCacheOrDefault();
    } finally {
      _updateCountdown();
      isLoading.value = false;
    }
  }

  bool notificationEnabled(String prayerKey) =>
      _notificationService.isPrayerEnabled(prayerKey);

  Future<void> setNotificationEnabled(String prayerKey, bool enabled) async {
    await _notificationService.setPrayerEnabled(prayerKey, enabled);
    final day = prayerDay.value;
    if (day != null) await _notificationService.schedulePrayerDay(day);
    prayerDay.refresh();
  }

  String formatTime(DateTime time) => DateFormat('HH:mm').format(time);

  String countdownText() {
    final duration = timeUntilNext.value;
    if (duration.isNegative) return '00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateCountdown();
    });
    _updateCountdown();
  }

  void _updateCountdown() {
    final day = prayerDay.value;
    if (day == null) return;
    timeUntilNext.value = day.nextPrayerTime.difference(DateTime.now());
  }
}
