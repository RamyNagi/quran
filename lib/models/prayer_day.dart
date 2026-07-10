class PrayerMoment {
  const PrayerMoment({
    required this.key,
    required this.labelKey,
    required this.time,
    this.enabled = true,
  });

  final String key;
  final String labelKey;
  final DateTime time;
  final bool enabled;
}

class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.qiblaDegrees,
    required this.prayers,
    required this.currentPrayerKey,
    required this.nextPrayerKey,
    required this.nextPrayerTime,
    required this.calculationMethodKey,
  });

  final DateTime date;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final double qiblaDegrees;
  final List<PrayerMoment> prayers;
  final String currentPrayerKey;
  final String nextPrayerKey;
  final DateTime nextPrayerTime;
  final String calculationMethodKey;

  Duration get timeUntilNext => nextPrayerTime.difference(DateTime.now());
}
