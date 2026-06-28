import 'package:quran_library/quran_library.dart';

Future<void> initQuranLibrary() async {
  await QuranLibrary().init();
  await QuranLibrary().initTafsir();
}
