import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const _boxName = 'hayah_settings';

  late final Box<dynamic> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  T read<T>(String key, T fallback) {
    final value = _box.get(key);
    return value is T ? value : fallback;
  }

  Future<void> write<T>(String key, T value) => _box.put(key, value);

  Future<void> remove(String key) => _box.delete(key);

  bool contains(String key) => _box.containsKey(key);

  List<String> readStringList(String key) {
    final value = _box.get(key);
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return <String>[];
  }

  Future<void> writeStringList(String key, List<String> value) =>
      _box.put(key, value);
}
