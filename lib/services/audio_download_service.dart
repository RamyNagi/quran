import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;
import 'quran_service.dart';
import '../static/mysnakbar.dart';

class AudioDownloadService extends GetxService {
  final RxDouble downloadProgress = 0.0.obs;
  final RxString downloadStatus = ''.obs;
  final RxBool isDownloading = false.obs;
  final RxBool isPaused = false.obs;
  final RxString downloadSizeText = ''.obs;
  bool _cancelDownload = false;
  void Function(int surah)? onSurahDownloaded;

  void togglePause() {
    if (isDownloading.value) {
      isPaused.value = !isPaused.value;
    }
  }

  String _formatBytesToMB(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  void _updateSizeProgress(int downloadedBytes, int processedCount, int totalCount) {
    if (processedCount == 0) {
      final estimatedTotal = totalCount * 150 * 1024;
      downloadSizeText.value = '${_formatBytesToMB(downloadedBytes)} / ${_formatBytesToMB(estimatedTotal)}';
    } else {
      final averageVerseSize = downloadedBytes / processedCount;
      final estimatedTotal = (averageVerseSize * totalCount).toInt();
      downloadSizeText.value = '${_formatBytesToMB(downloadedBytes)} / ${_formatBytesToMB(estimatedTotal)}';
    }
  }

  // مسار الحفظ المحلي
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // مسار ملف الآية المحدد لقارئ معين
  Future<File> getLocalAudioFile(String reciterKey, int surah, int verse) async {
    final path = await _localPath;
    final file = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3');
    return file;
  }

  // التحقق من تحميل آية معينة
  Future<bool> isVerseDownloaded(String reciterKey, int surah, int verse) async {
    final file = await getLocalAudioFile(reciterKey, surah, verse);
    if (await file.exists()) {
      final size = await file.length();
      // إذا كان الملف موجوداً وحجمه أكبر من 100 بايت (ملف سليم وليس فارغاً)
      return size > 100;
    }
    return false;
  }

  // التحقق من تحميل سورة بالكامل
  Future<bool> isSurahDownloaded(String reciterKey, int surah) async {
    try {
      final path = await _localPath;
      final surahDir = Directory('$path/reciter_audio/$reciterKey/$surah');
      if (surahDir.existsSync()) {
        final files = surahDir.listSync();
        int mp3Count = 0;
        for (final fileEntity in files) {
          if (fileEntity is File && fileEntity.path.endsWith('.mp3')) {
            if (fileEntity.lengthSync() > 100) {
              mp3Count++;
            }
          }
        }
        return mp3Count == quran.getVerseCount(surah);
      }
    } catch (_) {}
    return false;
  }

  // إلغاء التحميل الجاري
  void cancelActiveDownload() {
    _cancelDownload = true;
    isDownloading.value = false;
    isPaused.value = false;
    downloadStatus.value = '';
    downloadProgress.value = 0.0;
    downloadSizeText.value = '';
  }

  // فحص الاتصال بالإنترنت
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // تحميل سورة معينة لقارئ معين
  Future<void> downloadSurah(String reciterKey, int surah, QuranReciterOption reciterOption) async {
    if (isDownloading.value) return;

    _cancelDownload = false;
    isDownloading.value = true;
    isPaused.value = false;
    downloadProgress.value = 0.0;
    downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '0'});

    final client = http.Client();
    try {
      final verseCount = quran.getVerseCount(surah);
      int alreadyDownloadedCount = 0;
      int downloadedBytes = 0;
      int processedCount = 0;
      final path = await _localPath;

      // حساب عدد الآيات وحجمها المحمل مسبقاً
      for (var verse = 1; verse <= verseCount; verse++) {
        final file = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3');
        if (await file.exists()) {
          final size = await file.length();
          if (size > 100) {
            alreadyDownloadedCount++;
            downloadedBytes += size;
            processedCount++;
          }
        }
      }

      if (alreadyDownloadedCount == verseCount) {
        isDownloading.value = false;
        downloadProgress.value = 1.0;
        downloadStatus.value = 'audio_downloaded'.tr;
        downloadSizeText.value = '';
        MySnackbar.showSuccess(title: 'audio_title'.tr, message: 'audio_downloaded'.tr);
        return;
      }

      _updateSizeProgress(downloadedBytes, processedCount, verseCount);

      int downloadedCount = 0;

      for (var verse = 1; verse <= verseCount; verse++) {
        if (_cancelDownload) {
          isDownloading.value = false;
          isPaused.value = false;
          return;
        }

        // تحقق مما إذا كان التحميل مؤقتاً
        if (isPaused.value) {
          final percent = ((downloadedCount / verseCount) * 100).toInt();
          downloadStatus.value = 'audio_download_paused'.trParams({'percent': '$percent'});
          while (isPaused.value) {
            if (_cancelDownload) {
              isDownloading.value = false;
              isPaused.value = false;
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          // عند الاستئناف، أعد ضبط النص
          downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$percent'});
        }

        final file = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3');
        final tmpFile = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3.tmp');

        // لو الآية غير محملة أو حجمها تالف
        if (!await isVerseDownloaded(reciterKey, surah, verse)) {
          try {
            final String url;
            if (reciterOption.everyAyahFolder != null) {
              final sStr = surah.toString().padLeft(3, '0');
              final vStr = verse.toString().padLeft(3, '0');
              url = 'https://everyayah.com/data/${reciterOption.everyAyahFolder}/$sStr$vStr.mp3';
            } else {
              url = quran.getAudioURLByVerse(surah, verse, reciter: reciterOption.reciter ?? quran.Reciter.arAlafasy);
            }

            int retryCount = 0;
            http.Response? response;
            while (retryCount < 3) {
              try {
                response = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
                if (response.statusCode == 200) {
                  break;
                }
              } catch (e) {
                print('Download attempt ${retryCount + 1} failed for $url: $e');
              }
              retryCount++;
              if (retryCount < 3) {
                await Future<void>.delayed(Duration(seconds: retryCount));
              }
            }

            if (response == null) {
              // فشلت جميع المحاولات بسبب خطأ شبكة
              if (await tmpFile.exists()) {
                await tmpFile.delete().catchError((_) => tmpFile);
              }
              isDownloading.value = false;
              downloadStatus.value = 'audio_download_interrupted'.tr;
              MySnackbar.showError(title: 'audio_title'.tr, message: 'audio_download_interrupted'.tr);
              return;
            } else if (response.statusCode == 200) {
              // إنشاء المجلدات الأبوية إن لم تكن موجودة
              await tmpFile.parent.create(recursive: true);
              await tmpFile.writeAsBytes(response.bodyBytes);
              if (await file.exists()) {
                await file.delete();
              }
              await tmpFile.rename(file.path);
              downloadedCount++;
              downloadedBytes += response.bodyBytes.length;
              processedCount++;
              
              // تأخير بسيط لمنع حظر الطلبات من السيرفر
              await Future<void>.delayed(const Duration(milliseconds: 150));
            } else {
              // خطأ من السيرفر (الملف غير موجود)
              if (await tmpFile.exists()) {
                await tmpFile.delete().catchError((_) => tmpFile);
              }
              isDownloading.value = false;
              downloadStatus.value = 'audio_download_server_error'.tr;
              MySnackbar.showError(title: 'audio_title'.tr, message: 'audio_download_server_error'.tr);
              return;
            }
          } catch (e) {
            print('AudioDownloadService.downloadSurah Exception: $e');
            if (await tmpFile.exists()) {
              await tmpFile.delete().catchError((_) => tmpFile);
            }
            isDownloading.value = false;
            downloadStatus.value = 'audio_download_interrupted'.tr;
            MySnackbar.showError(title: 'audio_title'.tr, message: 'audio_download_interrupted'.tr);
            return;
          }
        } else {
          // الآية محملة مسبقاً، لا نعيد تحميلها بل نزيد العداد مباشرة (Skip ذكي)
          downloadedCount++;
        }

        final percent = ((downloadedCount / verseCount) * 100).toInt();
        downloadProgress.value = downloadedCount / verseCount;
        downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$percent'});
        _updateSizeProgress(downloadedBytes, processedCount, verseCount);
      }

      if (!_cancelDownload) {
        if (onSurahDownloaded != null) {
          onSurahDownloaded!(surah);
        }
      }

      isDownloading.value = false;
      downloadProgress.value = 1.0;
      downloadStatus.value = 'audio_downloaded'.tr;
      downloadSizeText.value = '';
      MySnackbar.showSuccess(title: 'audio_title'.tr, message: 'audio_downloaded'.tr);
    } finally {
      client.close();
    }
  }

  // تحميل المصحف كاملاً لقارئ معين
  Future<void> downloadEntireQuran(String reciterKey, QuranReciterOption reciterOption) async {
    if (isDownloading.value) return;

    _cancelDownload = false;
    isDownloading.value = true;
    isPaused.value = false;
    downloadProgress.value = 0.0;
    downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '0'});

    final client = http.Client();
    try {
      const totalVerses = quran.totalVerseCount; // 6236 آية
      int downloadedCount = 0;
      int downloadedBytes = 0;
      int processedCount = 0;
      final path = await _localPath;

      // حساب عدد الآيات وحجمها المحمل مسبقاً في كل المصحف
      for (var surah = 1; surah <= 114; surah++) {
        final verseCount = quran.getVerseCount(surah);
        for (var verse = 1; verse <= verseCount; verse++) {
          final file = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3');
          if (await file.exists()) {
            final size = await file.length();
            if (size > 100) {
              downloadedCount++;
              downloadedBytes += size;
              processedCount++;
            }
          }
        }
      }

      if (downloadedCount == totalVerses) {
        isDownloading.value = false;
        downloadProgress.value = 1.0;
        downloadStatus.value = 'audio_downloaded'.tr;
        downloadSizeText.value = '';
        MySnackbar.showSuccess(title: 'audio_title'.tr, message: 'audio_downloaded'.tr);
        return;
      }

      _updateSizeProgress(downloadedBytes, processedCount, totalVerses);
      final initialPercent = ((downloadedCount / totalVerses) * 100).toInt();
      downloadProgress.value = downloadedCount / totalVerses;
      downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$initialPercent'});

      bool hasError = false;
      String errorStatus = 'audio_download_interrupted';

      for (var surah = 1; surah <= 114; surah++) {
        if (_cancelDownload || hasError) break;

        // تحقق مما إذا كان التحميل مؤقتاً
        if (isPaused.value) {
          final percent = ((downloadedCount / totalVerses) * 100).toInt();
          final surahName = Get.locale?.languageCode == 'ar'
              ? quran.getSurahNameArabic(surah)
              : quran.getSurahName(surah);
          downloadStatus.value = 'audio_download_paused'.trParams({'percent': '$percent'}) + ' (${'surah'.tr}: $surahName)';
          while (isPaused.value) {
            if (_cancelDownload || hasError) break;
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          if (_cancelDownload || hasError) break;
          downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$percent'}) + ' (${'surah'.tr}: $surahName)';
        }

        final verseCount = quran.getVerseCount(surah);
        final missingVerses = <int>[];

        // العثور على الآيات الناقصة في هذه السورة
        for (var verse = 1; verse <= verseCount; verse++) {
          if (!await isVerseDownloaded(reciterKey, surah, verse)) {
            missingVerses.add(verse);
          }
        }

        // إذا كانت السورة محملة بالكامل مسبقاً، ننتقل للسورة التالية مباشرة دون إبطاء
        if (missingVerses.isEmpty) {
          continue;
        }

        // تحديث النص ليوضح اسم السورة الجاري تحميلها قبل تشغيل الـ workers
        final surahName = Get.locale?.languageCode == 'ar'
            ? quran.getSurahNameArabic(surah)
            : quran.getSurahName(surah);
        final percent = ((downloadedCount / totalVerses) * 100).toInt();
        downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$percent'}) + ' (${'surah'.tr}: $surahName)';

        // تحميل الآيات الناقصة لهذه السورة بالتوازي
        int index = 0;
        const maxConcurrency = 5;

        Future<void> worker() async {
          while (true) {
            if (_cancelDownload || hasError) return;

            // تحقق من التوقف المؤقت داخل الـ worker
            if (isPaused.value) {
              final percent = ((downloadedCount / totalVerses) * 100).toInt();
              final sName = Get.locale?.languageCode == 'ar'
                  ? quran.getSurahNameArabic(surah)
                  : quran.getSurahName(surah);
              downloadStatus.value = 'audio_download_paused'.trParams({'percent': '$percent'}) + ' (${'surah'.tr}: $sName)';
              while (isPaused.value) {
                if (_cancelDownload || hasError) return;
                await Future<void>.delayed(const Duration(milliseconds: 300));
              }
              downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$percent'}) + ' (${'surah'.tr}: $sName)';
            }

            int currentIdx;
            // سحب الآية التالية بطريقة تسلسلية
            if (index >= missingVerses.length) return;
            currentIdx = index++;

            final verse = missingVerses[currentIdx];
            final file = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3');
            final tmpFile = File('$path/reciter_audio/$reciterKey/$surah/$verse.mp3.tmp');

            try {
              final String url;
              if (reciterOption.everyAyahFolder != null) {
                final sStr = surah.toString().padLeft(3, '0');
                final vStr = verse.toString().padLeft(3, '0');
                url = 'https://everyayah.com/data/${reciterOption.everyAyahFolder}/$sStr$vStr.mp3';
              } else {
                url = quran.getAudioURLByVerse(surah, verse, reciter: reciterOption.reciter ?? quran.Reciter.arAlafasy);
              }

              int retryCount = 0;
              http.Response? response;
              while (retryCount < 3) {
                if (_cancelDownload || hasError) return;
                try {
                  response = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
                  if (response.statusCode == 200) {
                    break;
                  }
                } catch (e) {
                  print('Download attempt ${retryCount + 1} failed for $url: $e');
                }
                retryCount++;
                if (retryCount < 3) {
                  await Future<void>.delayed(Duration(seconds: retryCount));
                }
              }

              if (response == null) {
                hasError = true;
                errorStatus = 'audio_download_interrupted';
                return;
              } else if (response.statusCode == 200) {
                await tmpFile.parent.create(recursive: true);
                await tmpFile.writeAsBytes(response.bodyBytes);
                if (await file.exists()) {
                  await file.delete();
                }
                await tmpFile.rename(file.path);

                downloadedCount++;
                downloadedBytes += response.bodyBytes.length;
                processedCount++;

                final percent = ((downloadedCount / totalVerses) * 100).toInt();
                downloadProgress.value = downloadedCount / totalVerses;
                final sName = Get.locale?.languageCode == 'ar'
                    ? quran.getSurahNameArabic(surah)
                    : quran.getSurahName(surah);
                downloadStatus.value = 'audio_downloading_progress'.trParams({'percent': '$percent'}) + ' (${'surah'.tr}: $sName)';
                _updateSizeProgress(downloadedBytes, processedCount, totalVerses);
              } else {
                hasError = true;
                errorStatus = 'audio_download_server_error';
                return;
              }
            } catch (e) {
              print('Worker error: $e');
              hasError = true;
              errorStatus = 'audio_download_interrupted';
              if (await tmpFile.exists()) {
                await tmpFile.delete().catchError((_) => tmpFile);
              }
              return;
            }
          }
        }

        final workers = <Future<void>>[];
        for (var i = 0; i < maxConcurrency && i < missingVerses.length; i++) {
          workers.add(worker());
        }

        await Future.wait(workers);

        if (!_cancelDownload && !hasError) {
          if (onSurahDownloaded != null) {
            onSurahDownloaded!(surah);
          }
        }
      }

      if (_cancelDownload) {
        isDownloading.value = false;
        isPaused.value = false;
        return;
      }

      if (hasError) {
        isDownloading.value = false;
        if (errorStatus == 'audio_download_server_error') {
          downloadStatus.value = 'audio_download_server_error'.tr;
          MySnackbar.showError(title: 'audio_title'.tr, message: 'audio_download_server_error'.tr);
        } else {
          downloadStatus.value = 'audio_download_interrupted'.tr;
          MySnackbar.showError(title: 'audio_title'.tr, message: 'audio_download_interrupted'.tr);
        }
        return;
      }

      isDownloading.value = false;
      downloadProgress.value = 1.0;
      downloadStatus.value = 'audio_downloaded'.tr;
      downloadSizeText.value = '';
      MySnackbar.showSuccess(title: 'audio_title'.tr, message: 'audio_downloaded'.tr);

    } catch (e) {
      print('AudioDownloadService.downloadEntireQuran Exception: $e');
      isDownloading.value = false;
      downloadStatus.value = 'audio_download_interrupted'.tr;
      MySnackbar.showError(title: 'audio_title'.tr, message: 'audio_download_interrupted'.tr);
    } finally {
      client.close();
    }
  }

  // حذف صوتيات قارئ بالكامل
  Future<void> deleteReciterAudio(String reciterKey) async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/reciter_audio/$reciterKey');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      MySnackbar.showSuccess(title: 'audio_title'.tr, message: 'audio_delete_success'.tr);
    } catch (_) {}
  }

  // حذف صوتيات سورة معينة لقارئ معين
  Future<void> deleteSurahAudio(String reciterKey, int surah) async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/reciter_audio/$reciterKey/$surah');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // التحقق من وجود أي تنزيلات لهذا القارئ
  Future<bool> hasAnyDownloadedSurahs(String reciterKey) async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/reciter_audio/$reciterKey');
      if (await dir.exists()) {
        final list = dir.listSync(recursive: true);
        return list.any((entity) => entity is File && entity.path.endsWith('.mp3') && entity.lengthSync() > 100);
      }
    } catch (_) {}
    return false;
  }

  // التحقق من تنزيل المصحف كاملاً للقارئ
  Future<bool> isEntireQuranDownloaded(String reciterKey) async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/reciter_audio/$reciterKey');
      if (await dir.exists()) {
        int count = 0;
        final list = dir.listSync(recursive: true);
        for (final entity in list) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            if (entity.lengthSync() > 100) {
              count++;
            }
          }
        }
        return count >= quran.totalVerseCount;
      }
    } catch (_) {}
    return false;
  }

  // الحصول على قائمة معرفات السور المحملة بالكامل للقارئ
  Future<Set<int>> getDownloadedSurahs(String reciterKey) async {
    final Set<int> downloaded = {};
    try {
      final path = await _localPath;
      final dir = Directory('$path/reciter_audio/$reciterKey');
      if (await dir.exists()) {
        final list = dir.listSync();
        for (final entity in list) {
          if (entity is Directory) {
            final folderName = entity.path.split(Platform.pathSeparator).last;
            final surahNum = int.tryParse(folderName);
            if (surahNum != null && surahNum >= 1 && surahNum <= 114) {
              final surahDir = Directory(entity.path);
              if (surahDir.existsSync()) {
                final files = surahDir.listSync();
                int mp3Count = 0;
                for (final fileEntity in files) {
                  if (fileEntity is File && fileEntity.path.endsWith('.mp3')) {
                    if (fileEntity.lengthSync() > 100) {
                      mp3Count++;
                    }
                  }
                }
                if (mp3Count == quran.getVerseCount(surahNum)) {
                  downloaded.add(surahNum);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return downloaded;
  }
}
