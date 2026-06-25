import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_day.dart';
import 'storage_service.dart';

class NotificationService {
  NotificationService(this._storage);

  final StorageService _storage;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _enabledPrefix = 'notification_enabled_';
  bool _ready = false;

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
  }

  bool isPrayerEnabled(String prayerKey) =>
      _storage.read<bool>('$_enabledPrefix$prayerKey', true);

  Future<void> setPrayerEnabled(String prayerKey, bool enabled) =>
      _storage.write('$_enabledPrefix$prayerKey', enabled);

  Future<void> schedulePrayerDay(PrayerDay day) async {
    await init();
    await cancelPrayerDay();
    for (var index = 0; index < day.prayers.length; index++) {
      final prayer = day.prayers[index];
      if (!isPrayerEnabled(prayer.key)) continue;
      var scheduledTime = prayer.time;
      if (scheduledTime.isBefore(DateTime.now())) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        index + 1,
        'Hayah Prayer Reminder',
        '${prayer.labelKey.toUpperCase()} time is now',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hayah_prayers',
            'Prayer reminders',
            channelDescription: 'Daily local prayer time reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelPrayerDay() async {
    for (var id = 1; id <= 5; id++) {
      await _plugin.cancel(id);
    }
  }
}
