import 'dart:convert';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/prayer_day.dart';
import 'storage_service.dart';

class CalculationMethodHelper {
  static int getMethodIdForCountry(String? countryCode) {
    if (countryCode == null) return 3; // Default to MWL
    final code = countryCode.toUpperCase();
    return switch (code) {
      'EG' => 5, // Egyptian General Authority of Survey
      'US' || 'CA' => 2, // ISNA
      'SA' => 4, // Umm Al-Qura University, Makkah
      'AE' => 16, // UAE (GAIAE)
      'QA' => 8, // Gulf Region (Qatar)
      'KW' => 9, // Kuwait
      'OM' => 8, // Gulf Region (Oman)
      'BH' => 8, // Gulf Region (Bahrain)
      'TR' => 13, // Diyanet İşleri Başkanlığı, Turkey
      'PK' || 'IN' || 'BD' => 1, // Karachi
      'SG' => 22, // Singapore (MUIS)
      'MY' => 21, // Malaysia (JAKIM)
      'ID' => 20, // Indonesia (Kemenag)
      'FR' => 12, // France (UOIF)
      _ => 3, // Muslim World League (MWL)
    };
  }

  static CalculationParameters getLocalParametersForCountry(String? countryCode) {
    if (countryCode == null) return CalculationMethodParameters.muslimWorldLeague();
    final code = countryCode.toUpperCase();
    final params = switch (code) {
      'EG' => CalculationMethodParameters.egyptian(),
      'US' || 'CA' => CalculationMethodParameters.northAmerica(),
      'SA' => CalculationMethodParameters.ummAlQura(),
      'AE' => CalculationMethodParameters.dubai(),
      'QA' => CalculationMethodParameters.qatar(),
      'KW' => CalculationMethodParameters.kuwait(),
      'PK' || 'IN' || 'BD' => CalculationMethodParameters.karachi(),
      'SG' || 'MY' || 'ID' => CalculationMethodParameters.singapore(),
      _ => CalculationMethodParameters.muslimWorldLeague(),
    };
    params.madhab = Madhab.shafi;
    return params;
  }

  static String getMethodTranslationKey(int methodId) {
    return switch (methodId) {
      1 => 'method_karachi',
      2 => 'method_isna',
      4 => 'method_umm_al_qura',
      5 => 'egyptian_general_authority',
      8 || 9 => 'method_gulf',
      12 => 'method_france',
      13 => 'method_turkey',
      16 => 'method_dubai',
      20 => 'method_kemenag',
      21 => 'method_jakim',
      22 => 'method_singapore',
      _ => 'muslim_world_league',
    };
  }
}

class PrayerService {
  PrayerService(this._storage);

  final StorageService _storage;

  static const _latKey = 'last_latitude';
  static const _lngKey = 'last_longitude';
  static const _locationLabelKey = 'last_location_label';
  static const _countryCodeKey = 'last_country_code';
  static const _apiCacheKey = 'prayer_times_api_cache';

  Future<PrayerDay> loadToday() async {
    final position = await _resolvePosition();
    
    String? countryCode;
    String locationLabel = 'Current location';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        countryCode = place.isoCountryCode;
        final city = place.locality?.isNotEmpty == true
            ? place.locality
            : place.administrativeArea;
        final country = place.country;
        locationLabel = [
          city,
          country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      }
    } catch (_) {}

    await _storage.write(_latKey, position.latitude);
    await _storage.write(_lngKey, position.longitude);
    await _storage.write(_locationLabelKey, locationLabel);
    if (countryCode != null) {
      await _storage.write(_countryCodeKey, countryCode);
    } else {
      countryCode = _storage.read<String?>(_countryCodeKey, null);
    }

    final methodId = CalculationMethodHelper.getMethodIdForCountry(countryCode);
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);

    final existingCache = _storage.read<Map<dynamic, dynamic>>(_apiCacheKey, {});
    final cacheMap = Map<String, dynamic>.from(existingCache);

    bool isCacheFresh = false;
    final cachedLat = cacheMap['latitude'] as double?;
    final cachedLng = cacheMap['longitude'] as double?;
    final times = cacheMap['times'] as Map?;
    
    if (cachedLat != null && cachedLng != null && times != null && times.containsKey(dateKey)) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        cachedLat,
        cachedLng,
      );
      if (distance < 10000) { // < 10 km
        isCacheFresh = true;
      }
    }

    if (!isCacheFresh) {
      try {
        await _fetchAndCacheMonth(
          latitude: position.latitude,
          longitude: position.longitude,
          locationLabel: locationLabel,
          methodId: methodId,
          year: now.year,
          month: now.month,
        );

        final nextMonthDate = DateTime(now.year, now.month + 1, 1);
        await _fetchAndCacheMonth(
          latitude: position.latitude,
          longitude: position.longitude,
          locationLabel: locationLabel,
          methodId: methodId,
          year: nextMonthDate.year,
          month: nextMonthDate.month,
        );
      } catch (_) {}
    }

    final updatedCache = _storage.read<Map<dynamic, dynamic>>(_apiCacheKey, {});
    final updatedCacheMap = Map<String, dynamic>.from(updatedCache);
    final cachedDay = _buildPrayerDayFromCacheMap(
      cacheMap: updatedCacheMap,
      dateKey: dateKey,
      now: now,
    );

    if (cachedDay != null) {
      return cachedDay;
    }

    return _buildPrayerDayLocal(
      latitude: position.latitude,
      longitude: position.longitude,
      locationLabel: locationLabel,
      countryCode: countryCode,
      date: now,
    );
  }

  PrayerDay loadFromCacheOrDefault() {
    final latitude = _storage.read<double>(_latKey, 31.9522);
    final longitude = _storage.read<double>(_lngKey, 35.2332);
    final label = _storage.read<String>(_locationLabelKey, 'Jerusalem');
    final countryCode = _storage.read<String?>(_countryCodeKey, null);
    
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    
    final existingCache = _storage.read<Map<dynamic, dynamic>>(_apiCacheKey, {});
    final cacheMap = Map<String, dynamic>.from(existingCache);
    
    final cachedDay = _buildPrayerDayFromCacheMap(
      cacheMap: cacheMap,
      dateKey: dateKey,
      now: now,
    );

    if (cachedDay != null) {
      return cachedDay;
    }

    return _buildPrayerDayLocal(
      latitude: latitude,
      longitude: longitude,
      locationLabel: label,
      countryCode: countryCode,
      date: now,
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

  Future<void> _fetchAndCacheMonth({
    required double latitude,
    required double longitude,
    required String locationLabel,
    required int methodId,
    required int year,
    required int month,
  }) async {
    final url = 'https://api.aladhan.com/v1/calendar/$year/$month?latitude=$latitude&longitude=$longitude&method=$methodId';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final jsonMap = json.decode(response.body);
      if (jsonMap['code'] == 200 && jsonMap['data'] is List) {
        final dataList = jsonMap['data'] as List;
        
        final existingCache = _storage.read<Map<dynamic, dynamic>>(_apiCacheKey, {});
        final cacheMap = Map<String, dynamic>.from(existingCache);
        
        cacheMap['latitude'] = latitude;
        cacheMap['longitude'] = longitude;
        cacheMap['locationLabel'] = locationLabel;
        cacheMap['methodId'] = methodId;
        cacheMap['lastFetchTime'] = DateTime.now().toIso8601String();
        
        final timesMap = cacheMap['times'] != null 
            ? Map<String, dynamic>.from(cacheMap['times'] as Map) 
            : <String, dynamic>{};
            
        for (final dayData in dataList) {
          if (dayData is Map) {
            final timings = dayData['timings'];
            final dateObj = dayData['date'];
            if (timings is Map && dateObj is Map && dateObj['gregorian'] is Map) {
              final rawDate = dateObj['gregorian']['date'] as String;
              final dateKey = _formatGregorianDateToKey(rawDate);
              timesMap[dateKey] = {
                'fajr': timings['Fajr'],
                'sunrise': timings['Sunrise'],
                'dhuhr': timings['Dhuhr'],
                'asr': timings['Asr'],
                'maghrib': timings['Maghrib'],
                'isha': timings['Isha'],
              };
            }
          }
        }
        cacheMap['times'] = timesMap;
        await _storage.write(_apiCacheKey, cacheMap);
      }
    }
  }

  String _formatGregorianDateToKey(String gregorianDate) {
    final parts = gregorianDate.split('-');
    if (parts.length == 3) {
      final day = parts[0];
      final month = parts[1];
      final year = parts[2];
      return '$year-$month-$day';
    }
    return gregorianDate;
  }

  PrayerDay? _buildPrayerDayFromCacheMap({
    required Map<String, dynamic> cacheMap,
    required String dateKey,
    required DateTime now,
  }) {
    final times = cacheMap['times'] as Map?;
    if (times == null || !times.containsKey(dateKey)) return null;

    final dayTimes = times[dateKey] as Map;
    final latitude = cacheMap['latitude'] as double;
    final longitude = cacheMap['longitude'] as double;
    final locationLabel = cacheMap['locationLabel'] as String;
    final methodId = cacheMap['methodId'] as int;
    final methodKey = CalculationMethodHelper.getMethodTranslationKey(methodId);

    final coordinates = Coordinates(latitude, longitude);

    DateTime parseTime(String timeStr, DateTime refDate, int fallbackHour) {
      try {
        final cleanTime = timeStr.trim().split(' ').first;
        final timeParts = cleanTime.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        return DateTime(refDate.year, refDate.month, refDate.day, hour, minute);
      } catch (_) {
        return DateTime(refDate.year, refDate.month, refDate.day, fallbackHour, 0);
      }
    }

    final fajr = parseTime(dayTimes['fajr'] as String, now, 5);
    final _ = parseTime(dayTimes['sunrise'] as String, now, 6);
    final dhuhr = parseTime(dayTimes['dhuhr'] as String, now, 12);
    final asr = parseTime(dayTimes['asr'] as String, now, 15);
    final maghrib = parseTime(dayTimes['maghrib'] as String, now, 18);
    final isha = parseTime(dayTimes['isha'] as String, now, 19);

    final prayers = <PrayerMoment>[
      PrayerMoment(key: 'fajr', labelKey: 'fajr', time: fajr),
      PrayerMoment(key: 'dhuhr', labelKey: 'dhuhr', time: dhuhr),
      PrayerMoment(key: 'asr', labelKey: 'asr', time: asr),
      PrayerMoment(key: 'maghrib', labelKey: 'maghrib', time: maghrib),
      PrayerMoment(key: 'isha', labelKey: 'isha', time: isha),
    ];

    String currentPrayerKey = 'isha';
    String nextPrayerKey = 'fajr';
    DateTime nextPrayerTime = fajr;

    if (now.isBefore(fajr)) {
      currentPrayerKey = 'isha';
      nextPrayerKey = 'fajr';
      nextPrayerTime = fajr;
    } else if (now.isBefore(dhuhr)) {
      currentPrayerKey = 'fajr';
      nextPrayerKey = 'dhuhr';
      nextPrayerTime = dhuhr;
    } else if (now.isBefore(asr)) {
      currentPrayerKey = 'dhuhr';
      nextPrayerKey = 'asr';
      nextPrayerTime = asr;
    } else if (now.isBefore(maghrib)) {
      currentPrayerKey = 'asr';
      nextPrayerKey = 'maghrib';
      nextPrayerTime = maghrib;
    } else if (now.isBefore(isha)) {
      currentPrayerKey = 'maghrib';
      nextPrayerKey = 'isha';
      nextPrayerTime = isha;
    } else {
      currentPrayerKey = 'isha';
      nextPrayerKey = 'fajr';
      
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowDateKey = DateFormat('yyyy-MM-dd').format(tomorrow);
      if (times.containsKey(tomorrowDateKey)) {
        final tomorrowTimes = times[tomorrowDateKey] as Map;
        nextPrayerTime = parseTime(tomorrowTimes['fajr'] as String, tomorrow, 5);
      } else {
        nextPrayerTime = fajr.add(const Duration(days: 1));
      }
    }

    return PrayerDay(
      date: now,
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
      qiblaDegrees: Qibla.qibla(coordinates),
      prayers: prayers,
      currentPrayerKey: currentPrayerKey,
      nextPrayerKey: nextPrayerKey,
      nextPrayerTime: nextPrayerTime,
      calculationMethodKey: methodKey,
    );
  }

  PrayerDay _buildPrayerDayLocal({
    required double latitude,
    required double longitude,
    required String locationLabel,
    required String? countryCode,
    required DateTime date,
  }) {
    final coordinates = Coordinates(latitude, longitude);
    final parameters = CalculationMethodHelper.getLocalParametersForCountry(countryCode);
    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: parameters,
      precision: true,
    );
    final nextPrayer = prayerTimes.nextPrayer(date: date.toUtc());
    final currentPrayer = prayerTimes.currentPrayer(date: date.toUtc());

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

    final methodId = CalculationMethodHelper.getMethodIdForCountry(countryCode);
    final methodKey = CalculationMethodHelper.getMethodTranslationKey(methodId);

    return PrayerDay(
      date: date,
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
      qiblaDegrees: Qibla.qibla(coordinates),
      prayers: prayers,
      currentPrayerKey: _prayerKey(currentPrayer),
      nextPrayerKey: _prayerKey(nextPrayer),
      nextPrayerTime: prayerTimes.timeForPrayer(nextPrayer).toLocal(),
      calculationMethodKey: methodKey,
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

