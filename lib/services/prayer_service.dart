import 'package:adhan_dart/adhan_dart.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/prayer_day.dart';
import 'storage_service.dart';

class PrayerService {
  PrayerService(this._storage);

  final StorageService _storage;

  static const _latKey = 'last_latitude';
  static const _lngKey = 'last_longitude';
  static const _locationLabelKey = 'last_location_label';

  Future<PrayerDay> loadToday() async {
    final position = await _resolvePosition();
    final locationLabel = await _resolveLocationLabel(position);

    await _storage.write(_latKey, position.latitude);
    await _storage.write(_lngKey, position.longitude);
    await _storage.write(_locationLabelKey, locationLabel);

    return _buildPrayerDay(
      latitude: position.latitude,
      longitude: position.longitude,
      locationLabel: locationLabel,
    );
  }

  PrayerDay loadFromCacheOrDefault() {
    final latitude = _storage.read<double>(_latKey, 31.9522);
    final longitude = _storage.read<double>(_lngKey, 35.2332);
    final label = _storage.read<String>(_locationLabelKey, 'Jerusalem');
    return _buildPrayerDay(
      latitude: latitude,
      longitude: longitude,
      locationLabel: label,
    );
  }

  Future<Position> _resolvePosition() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw PermissionDeniedException('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> _resolveLocationLabel(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return 'Current location';
      final place = placemarks.first;
      final city = place.locality?.isNotEmpty == true
          ? place.locality
          : place.administrativeArea;
      final country = place.country;
      return [
        city,
        country,
      ].where((part) => part != null && part.isNotEmpty).join(', ');
    } catch (_) {
      return 'Current location';
    }
  }

  PrayerDay _buildPrayerDay({
    required double latitude,
    required double longitude,
    required String locationLabel,
  }) {
    final coordinates = Coordinates(latitude, longitude);
    final parameters = CalculationMethodParameters.egyptian()
      ..madhab = Madhab.shafi;
    final now = DateTime.now();
    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: now,
      calculationParameters: parameters,
      precision: true,
    );
    final nextPrayer = prayerTimes.nextPrayer(date: now.toUtc());
    final currentPrayer = prayerTimes.currentPrayer(date: now.toUtc());

    final prayers = <PrayerMoment>[
      PrayerMoment(
        key: 'fajr',
        labelKey: 'fajr',
        time: prayerTimes.fajr.toLocal(),
      ),
      PrayerMoment(
        key: 'dhuhr',
        labelKey: 'dhuhr',
        time: prayerTimes.dhuhr.toLocal(),
      ),
      PrayerMoment(
        key: 'asr',
        labelKey: 'asr',
        time: prayerTimes.asr.toLocal(),
      ),
      PrayerMoment(
        key: 'maghrib',
        labelKey: 'maghrib',
        time: prayerTimes.maghrib.toLocal(),
      ),
      PrayerMoment(
        key: 'isha',
        labelKey: 'isha',
        time: prayerTimes.isha.toLocal(),
      ),
    ];

    return PrayerDay(
      date: now,
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
      qiblaDegrees: Qibla.qibla(coordinates),
      prayers: prayers,
      currentPrayerKey: _prayerKey(currentPrayer),
      nextPrayerKey: _prayerKey(nextPrayer),
      nextPrayerTime: prayerTimes.timeForPrayer(nextPrayer).toLocal(),
    );
  }

  String _prayerKey(Prayer prayer) {
    return switch (prayer) {
      Prayer.fajr => 'fajr',
      Prayer.sunrise => 'sunrise',
      Prayer.dhuhr => 'dhuhr',
      Prayer.asr => 'asr',
      Prayer.maghrib => 'maghrib',
      Prayer.isha => 'isha',
      Prayer.ishaBefore => 'isha',
      Prayer.fajrAfter => 'fajr',
    };
  }
}
