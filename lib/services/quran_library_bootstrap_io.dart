import 'dart:io';
import 'dart:developer';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:quran_library/quran_library.dart';
import 'package:get_storage/get_storage.dart';

Future<void> initQuranLibrary() async {
  await GetStorage.init();

  final storage = GetStorage();
  final bool isFontsPreloaded = storage.read<bool>('isDownloadedCodeV2Fonts') ?? false;

  if (!isFontsPreloaded) {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${appDir.path}/quran_fonts');
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      // Read zip from assets
      final data = await rootBundle.load('assets/quran_fonts.zip');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Decode and extract zip
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = '${fontsDir.path}/${file.name}';
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Write download flags to storage so quran_library knows they are local
      await storage.write('isDownloadedCodeV2Fonts', true);
      await storage.write('fontsDownloadedList', [1]); // 1 is Tajweed font index
    } catch (e) {
      log("Error preloading offline quran fonts: $e");
    }
  }

  // Force Tajweed font (1) selection safely
  await storage.write('fontsSelected2', 1);

  await QuranLibrary().init();
  await QuranLibrary().initTafsir();
}
