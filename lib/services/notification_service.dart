import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_day.dart';
import 'storage_service.dart';

enum DhikrReminderMode { onceDaily, morningEvening, afterPrayers }

class NotificationService {
  NotificationService(this._storage);

  final StorageService _storage;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();

  static const _enabledPrefix = 'notification_enabled_';
  static const _dhikrReminderStartId = 7001;
  static const _dhikrReminderCount = 8;
  bool _ready = false;

  Stream<String> get payloads => _payloadController.stream;

  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _payloadController.add(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      scheduleMicrotask(() => _payloadController.add(launchPayload));
    }
  }

  bool isPrayerEnabled(String prayerKey) =>
      getPrayerNotificationMode(prayerKey) != 'disabled';

  Future<void> setPrayerEnabled(String prayerKey, bool enabled) =>
      setPrayerNotificationMode(prayerKey, enabled ? 'default' : 'disabled');

  String getPrayerNotificationMode(String prayerKey) {
    final oldEnabled = _storage.read<bool>('$_enabledPrefix$prayerKey', true);
    if (oldEnabled == false) return 'disabled';
    return _storage.read<String>('notification_mode_$prayerKey', 'default');
  }

  Future<void> setPrayerNotificationMode(String prayerKey, String mode) async {
    await _storage.write('notification_mode_$prayerKey', mode);
    await _storage.write('$_enabledPrefix$prayerKey', mode != 'disabled');
  }

  int getGlobalEarlyReminderMinutes() =>
      _storage.read<int>('early_reminder_minutes_global', 0);

  Future<void> setGlobalEarlyReminderMinutes(int minutes) =>
      _storage.write('early_reminder_minutes_global', minutes);

  String getGlobalEarlyReminderSoundMode() =>
      _storage.read<String>('early_reminder_sound_global', 'default');

  Future<void> setGlobalEarlyReminderSoundMode(String soundMode) =>
      _storage.write('early_reminder_sound_global', soundMode);

  Future<void> scheduleDhikrReminders({
    required DhikrReminderMode mode,
    required String dhikrText,
    required String payload,
    PrayerDay? prayerDay,
  }) async {
    await init();
    await cancelDhikrReminders();

    final scheduledTimes = _dhikrScheduleTimes(mode, prayerDay);
    for (var index = 0; index < scheduledTimes.length; index++) {
      await _plugin.zonedSchedule(
        _dhikrReminderStartId + index,
        'ذكر اليوم',
        dhikrText,
        tz.TZDateTime.from(scheduledTimes[index], tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_dhikr',
            'Dhikr reminders',
            channelDescription: 'Daily reminders for remembrance',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
        matchDateTimeComponents: mode == DhikrReminderMode.afterPrayers
            ? null
            : DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelDhikrReminders() async {
    for (var index = 0; index < _dhikrReminderCount; index++) {
      await _plugin.cancel(_dhikrReminderStartId + index);
    }
  }

  List<DateTime> _dhikrScheduleTimes(
    DhikrReminderMode mode,
    PrayerDay? prayerDay,
  ) {
    final now = DateTime.now();
    DateTime nextDailyTime(int hour, int minute) {
      var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (!scheduledTime.isAfter(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      return scheduledTime;
    }

    return switch (mode) {
      DhikrReminderMode.onceDaily => [nextDailyTime(8, 0)],
      DhikrReminderMode.morningEvening => [
        nextDailyTime(8, 0),
        nextDailyTime(18, 0),
      ],
      DhikrReminderMode.afterPrayers => _afterPrayerDhikrTimes(prayerDay, now),
    };
  }

  List<DateTime> _afterPrayerDhikrTimes(PrayerDay? prayerDay, DateTime now) {
    final day = prayerDay;
    if (day == null) {
      return [
        DateTime(now.year, now.month, now.day, 8).add(const Duration(days: 1)),
      ];
    }

    final times = <DateTime>[];
    for (final prayer in day.prayers) {
      var scheduledTime = prayer.time.add(const Duration(minutes: 10));
      if (!scheduledTime.isAfter(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      times.add(scheduledTime);
    }
    return times.take(_dhikrReminderCount).toList(growable: false);
  }

  Future<void> schedulePrayerDay(PrayerDay day) async {
    await init();
    await cancelPrayerDay();
    final scheduleMode = await _scheduleMode(preferExact: true);
    for (var index = 0; index < day.prayers.length; index++) {
      final prayer = day.prayers[index];
      
      // 1. Schedule main prayer notification
      final mode = getPrayerNotificationMode(prayer.key);
      if (mode != 'disabled') {
        var scheduledTime = prayer.time;
        if (scheduledTime.isBefore(DateTime.now())) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          index + 1,
          'prayer_times'.tr,
          '${prayer.labelKey.tr} - ${'prayer_notification_body'.tr}',
          tz.TZDateTime.from(scheduledTime, tz.local),
          _buildNotificationDetails(mode, prayer.labelKey.tr),
          androidScheduleMode: scheduleMode,
          payload: 'prayer:${prayer.key}',
        );
      }

      // 2. Schedule early reminder notification
      final earlyMinutes = getGlobalEarlyReminderMinutes();
      if (earlyMinutes > 0 && mode != 'disabled') {
        var earlyTime = prayer.time.subtract(Duration(minutes: earlyMinutes));
        if (earlyTime.isBefore(DateTime.now())) {
          earlyTime = earlyTime.add(const Duration(days: 1));
        }
        final earlySoundMode = getGlobalEarlyReminderSoundMode();

        await _plugin.zonedSchedule(
          index + 101, // 101 to 105
          'prayer_approaching_title'.trParams({'prayer': prayer.labelKey.tr}),
          'prayer_approaching_body'.trParams({'minutes': '$earlyMinutes'}),
          tz.TZDateTime.from(earlyTime, tz.local),
          _buildEarlyNotificationDetails(earlySoundMode),
          androidScheduleMode: scheduleMode,
          payload: 'early_prayer:${prayer.key}',
        );
      }
    }
  }

  NotificationDetails _buildNotificationDetails(String mode, String prayerName) {
    switch (mode) {
      case 'silent':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_silent',
            'Silent prayer reminders',
            channelDescription: 'Daily silent prayer time reminders',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            presentAlert: true,
            presentBadge: true,
          ),
        );
      case 'makkah':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_makkah',
            'Makkah Adhan reminders',
            channelDescription: 'Daily prayer time reminders with Makkah Adhan',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('adhan_makkah'),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'adhan_makkah.mp3',
            presentSound: true,
          ),
        );
      case 'madinah':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_madinah',
            'Madinah Adhan reminders',
            channelDescription: 'Daily prayer time reminders with Madinah Adhan',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('adhan_madinah'),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'adhan_madinah.mp3',
            presentSound: true,
          ),
        );
      case 'default':
      default:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_default',
            'Default prayer reminders',
            channelDescription: 'Daily default prayer time reminders',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
          ),
        );
    }
  }

  NotificationDetails _buildEarlyNotificationDetails(String soundMode) {
    switch (soundMode) {
      case 'silent':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_early_silent',
            'Early silent prayer reminders',
            channelDescription: 'Daily silent pre-prayer reminders',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            presentAlert: true,
            presentBadge: true,
          ),
        );
      case 'makkah':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_early_makkah',
            'Early Makkah Adhan reminders',
            channelDescription: 'Daily pre-prayer reminders with Makkah Adhan',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('adhan_makkah'),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'adhan_makkah.mp3',
            presentSound: true,
          ),
        );
      case 'madinah':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_early_madinah',
            'Early Madinah Adhan reminders',
            channelDescription: 'Daily pre-prayer reminders with Madinah Adhan',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('adhan_madinah'),
          ),
          iOS: DarwinNotificationDetails(
            sound: 'adhan_madinah.mp3',
            presentSound: true,
          ),
        );
      case 'default':
      default:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers_early_default',
            'Early default prayer reminders',
            channelDescription: 'Daily default pre-prayer reminders',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
          ),
        );
    }
  }

  Future<void> cancelPrayerDay() async {
    for (var id = 1; id <= 5; id++) {
      await _plugin.cancel(id);
      await _plugin.cancel(id + 100);
    }
  }

  Future<AndroidScheduleMode> _scheduleMode({required bool preferExact}) async {
    if (!preferExact) return AndroidScheduleMode.inexactAllowWhileIdle;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExact =
        await android?.canScheduleExactNotifications() ?? false;
    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
