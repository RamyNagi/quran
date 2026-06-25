import 'package:flutter_qiblah/flutter_qiblah.dart';

class QiblaService {
  Future<bool> supportsCompass() async {
    final supported = await FlutterQiblah.androidDeviceSensorSupport();
    return supported ?? false;
  }

  Future<LocationStatus> checkLocationStatus() =>
      FlutterQiblah.checkLocationStatus();

  Future<void> requestPermissions() async {
    await FlutterQiblah.requestPermissions();
  }

  Stream<QiblahDirection> get directionStream => FlutterQiblah.qiblahStream;

  void disposeCompass() {
    FlutterQiblah().dispose();
  }
}
