import 'package:quran_library/quran_library.dart';
import 'package:get_storage/get_storage.dart';

Future<void> initQuranLibrary() async {
  await GetStorage.init();
  await GetStorage().write('fontsSelected2', 0); // فرض خط حفص العثماني المدمج فوراً
  await QuranLibrary().init();
  await QuranLibrary().initTafsir();
}
