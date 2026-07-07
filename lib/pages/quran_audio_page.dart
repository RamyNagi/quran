import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_pkg;

import '../services/audio_download_service.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../static/mysnakbar.dart';
import '../static/mydialog.dart';

class QuranAudioPage extends StatefulWidget {
  const QuranAudioPage({super.key});

  @override
  State<QuranAudioPage> createState() => _QuranAudioPageState();
}

class _QuranAudioPageState extends State<QuranAudioPage> {
  late final QuranService _quranService;
  late final QuranAudioService _audioService;
  late final AudioDownloadService _downloadService;

  late List<QuranReciterOption> _reciters;
  late QuranReciterOption _selectedReciter;

  int _selectedSurah = 1;
  int _startVerse = 1;
  int _endVerse = 7;
  int _repeatCount = 1;

  bool _dependenciesLoaded = false;
  String _errorMessage = '';

  // حالات التحميل التفاعلية للمستندات والملفات الصوتية
  bool _isCurrentSurahDownloaded = false;
  bool _isQuranDownloaded = false;
  bool _hasAnyDownloads = false;
  Set<int> _downloadedSurahs = {};

  @override
  void initState() {
    super.initState();
    try {
      _quranService = Get.find<QuranService>();
      _audioService = Get.find<QuranAudioService>();
      _downloadService = Get.find<AudioDownloadService>();
      _downloadService.onSurahDownloaded = (surah) {
        if (mounted) {
          _updateDownloadStatuses();
        }
      };

      _reciters = QuranService.reciters;
      _selectedReciter = _quranService.getSelectedReciter();

      // تعيين السورة والآيات الافتراضية بناءً على آخر صفحة مقروءة أو الإعدادات المحفوظة
      try {
        final lastRead = _quranService.getLastRead();
        final defaultSurah = lastRead.surah.clamp(1, 114);
        final defaultMax = quran_pkg.getVerseCount(defaultSurah);
        final defaultStart = lastRead.verse.clamp(1, defaultMax);

        _selectedSurah = _quranService.getSelectedAudioSurahOrDefault(defaultSurah);
        final maxVerses = quran_pkg.getVerseCount(_selectedSurah);
        _startVerse = _quranService.getSelectedAudioStartVerseOrDefault(defaultStart).clamp(1, maxVerses);
        _endVerse = _quranService.getSelectedAudioEndVerseOrDefault(maxVerses).clamp(1, maxVerses);
        _repeatCount = _quranService.getSelectedAudioRepeatCount().clamp(1, 10);
      } catch (_) {
        _selectedSurah = 1;
        _startVerse = 1;
        _endVerse = 7;
        _repeatCount = 1;
      }
      _dependenciesLoaded = true;
      _updateDownloadStatuses();
    } catch (e, s) {
      _dependenciesLoaded = false;
      _errorMessage = '$e\n$s';
      debugPrint('Error initializing QuranAudioPage: $e\n$s');
    }
  }

  @override
  void dispose() {
    if (_dependenciesLoaded) {
      _downloadService.onSurahDownloaded = null;
    }
    super.dispose();
  }

  // تحديث حالات التحميل محلياً
  Future<void> _updateDownloadStatuses() async {
    if (!_dependenciesLoaded || !mounted) return;
    final reciterKey = _selectedReciter.key;
    final isSurah = await _downloadService.isSurahDownloaded(reciterKey, _selectedSurah);
    final hasAny = await _downloadService.hasAnyDownloadedSurahs(reciterKey);
    final isQuran = await _downloadService.isEntireQuranDownloaded(reciterKey);
    final downloadedSet = await _downloadService.getDownloadedSurahs(reciterKey);

    if (mounted) {
      setState(() {
        _isCurrentSurahDownloaded = isSurah;
        _hasAnyDownloads = hasAny;
        _isQuranDownloaded = isQuran;
        _downloadedSurahs = downloadedSet;
      });
    }
  }

  void _onSurahChanged(int surah) async {
    if (!_dependenciesLoaded) return;
    setState(() {
      _selectedSurah = surah;
      _startVerse = 1;
      _endVerse = quran_pkg.getVerseCount(surah);
    });
    await _quranService.setSelectedAudioSurah(surah);
    await _quranService.setSelectedAudioStartVerse(1);
    await _quranService.setSelectedAudioEndVerse(quran_pkg.getVerseCount(surah));
    await _updateDownloadStatuses();
  }

  // التحقق والتشغيل
  Future<void> _playSelectedRange() async {
    if (!_dependenciesLoaded) return;
    final verses = _quranService.getSurahVersesRange(_selectedSurah, _startVerse, _endVerse);
    final urls = verses.map((v) => v.audioUrl).toList();

    // التحقق من التواجد أوفلاين
    bool allDownloaded = true;
    for (final verse in verses) {
      final downloaded = await _downloadService.isVerseDownloaded(_selectedReciter.key, verse.surah, verse.verse);
      if (!downloaded) {
        allDownloaded = false;
        break;
      }
    }

    if (!allDownloaded) {
      final hasInternet = await _downloadService.hasInternetConnection();
      if (!hasInternet) {
        MySnackbar.showError(
          title: 'audio_title'.tr,
          message: 'audio_no_internet_alert'.tr,
        );
        return;
      }
    }

    await _audioService.stop();
    await _audioService.playPlaylist(urls, verses: verses, repeatCount: _repeatCount);
  }

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isNight ? AppTheme.backgroundNight : AppTheme.backgroundLight;

    if (!_dependenciesLoaded) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          title: const Text('خطأ في التحميل', style: TextStyle(color: Colors.redAccent)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isNight ? Colors.white : Colors.black),
            onPressed: () => Get.back(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.orange, size: 64.r),
                SizedBox(height: 16.h),
                Text(
                  'يرجى إعادة تشغيل التطبيق بالكامل (Hot Restart)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: isNight ? Colors.white : Colors.black),
                ),
                SizedBox(height: 8.h),
                Text(
                  'تم إضافة خدمات جديدة للتلاوة والتحميل وتتطلب إعادة تشغيل التطبيق بالكامل لتفعيلها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      initState();
                    });
                  },
                  child: const Text('إعادة المحاولة'),
                ),
                SizedBox(height: 24.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _errorMessage,
                    style: TextStyle(fontSize: 10.sp, color: Colors.redAccent),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cardColor = isNight ? AppTheme.surfaceNight : AppTheme.surfaceLight;
    final textColor = isNight ? AppTheme.textNight : AppTheme.textLight;
    final goldColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
    final textVariantColor = isNight ? AppTheme.textVariantNight : AppTheme.textVariantLight;

    final totalSurahs = List.generate(114, (i) => i + 1);
    final maxVerses = quran_pkg.getVerseCount(_selectedSurah);
    _startVerse = _startVerse.clamp(1, maxVerses);
    _endVerse = _endVerse.clamp(_startVerse, maxVerses);
    final versesList = List.generate(maxVerses, (i) => i + 1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'audio_title'.tr,
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20.r),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 140.h, left: 16.w, right: 16.w, top: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقة اختيار القارئ
                  Text(
                    'reciter'.tr,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: goldColor.withOpacity(0.3), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedReciter.key,
                        isExpanded: true,
                        dropdownColor: cardColor,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: goldColor),
                        items: _reciters.map((reciter) {
                          return DropdownMenuItem<String>(
                            value: reciter.key,
                            child: Text(
                              reciter.name,
                              style: TextStyle(color: textColor, fontSize: 14.sp),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _selectedReciter = _reciters.firstWhere((r) => r.key == val);
                            });
                            await _quranService.setSelectedReciter(val);
                            await _updateDownloadStatuses();
                          }
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // بطاقة النطاق
                  Text(
                    'quran_settings'.tr,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: goldColor.withOpacity(0.15), width: 1),
                    ),
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      children: [
                        // اختيار السورة
                        Row(
                          children: [
                            Icon(Icons.book_rounded, color: goldColor, size: 20.r),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedSurah,
                                  isExpanded: true,
                                  dropdownColor: cardColor,
                                  items: totalSurahs.map((surahNum) {
                                    final isDownloaded = _downloadedSurahs.contains(surahNum);
                                    return DropdownMenuItem<int>(
                                      value: surahNum,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${surahNum.toString()} - ${quran_pkg.getSurahNameArabic(surahNum)}',
                                              style: TextStyle(color: textColor, fontSize: 14.sp),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          if (isDownloaded) ...[
                                            SizedBox(width: 8.w),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4.r),
                                              ),
                                              child: Text(
                                                'audio_surah_downloaded'.tr,
                                                style: TextStyle(color: Colors.green, fontSize: 10.sp, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) _onSurahChanged(val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: goldColor.withOpacity(0.15), height: 24.h),

                        // اختيار الآيات (من وإلى)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'audio_from_verse'.tr,
                                    style: TextStyle(fontSize: 11.sp, color: textVariantColor),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _startVerse,
                                      dropdownColor: cardColor,
                                      items: versesList.map((v) {
                                        return DropdownMenuItem<int>(
                                          value: v,
                                          child: Text(
                                            '$v',
                                            style: TextStyle(color: textColor, fontSize: 14.sp),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) async {
                                        if (val != null) {
                                          setState(() {
                                            _startVerse = val;
                                            if (_endVerse < _startVerse) {
                                              _endVerse = _startVerse;
                                            }
                                          });
                                          await _quranService.setSelectedAudioStartVerse(val);
                                          if (_endVerse < _startVerse) {
                                            await _quranService.setSelectedAudioEndVerse(_startVerse);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, color: goldColor.withOpacity(0.5), size: 18.r),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'audio_to_verse'.tr,
                                    style: TextStyle(fontSize: 11.sp, color: textVariantColor),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _endVerse,
                                      dropdownColor: cardColor,
                                      items: versesList.where((v) => v >= _startVerse).map((v) {
                                        return DropdownMenuItem<int>(
                                          value: v,
                                          child: Text(
                                            '$v',
                                            style: TextStyle(color: textColor, fontSize: 14.sp),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) async {
                                        if (val != null) {
                                          setState(() => _endVerse = val);
                                          await _quranService.setSelectedAudioEndVerse(val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // تكرار التلاوة
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: goldColor.withOpacity(0.15), width: 1),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.loop_rounded, color: goldColor, size: 20.r),
                            SizedBox(width: 8.w),
                            Text(
                              'audio_repeat_count'.tr,
                              style: TextStyle(fontSize: 14.sp, color: textColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                               if (_repeatCount > 1) {
                                 setState(() => _repeatCount--);
                                 await _quranService.setSelectedAudioRepeatCount(_repeatCount);
                               }
                             },
                              icon: Icon(Icons.remove_circle_outline_rounded, color: goldColor, size: 24.r),
                            ),
                            Text(
                              '$_repeatCount',
                              style: TextStyle(fontSize: 16.sp, color: textColor, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              onPressed: () async {
                               setState(() => _repeatCount++);
                               await _quranService.setSelectedAudioRepeatCount(_repeatCount);
                             },
                              icon: Icon(Icons.add_circle_outline_rounded, color: goldColor, size: 24.r),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // أزرار التحميل
                  Row(
                    children: [
                      // زر تحميل السورة أو حذف السورة
                      Expanded(
                        child: _isCurrentSurahDownloaded
                            ? OutlinedButton.icon(
                                onPressed: () {
                                  MyDialog.show(
                                    title: 'audio_delete_surah'.tr,
                                    content: 'audio_delete_surah_confirm'.trParams({
                                      'surah': quran_pkg.getSurahNameArabic(_selectedSurah),
                                    }),
                                    confirmText: 'confirm'.tr,
                                    cancelText: 'cancel'.tr,
                                    icon: Icons.delete_forever_rounded,
                                    onConfirm: () async {
                                      await _downloadService.deleteSurahAudio(_selectedReciter.key, _selectedSurah);
                                      await _updateDownloadStatuses();
                                    },
                                  );
                                },
                                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'audio_delete_surah'.tr,
                                    style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () async {
                                  await _downloadService.downloadSurah(
                                    _selectedReciter.key,
                                    _selectedSurah,
                                    _selectedReciter,
                                  );
                                  await _updateDownloadStatuses();
                                },
                                icon: Icon(Icons.download_rounded, color: Colors.white, size: 18.r),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'audio_download_surah'.tr,
                                    style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: goldColor,
                                  padding: EdgeInsets.symmetric(vertical: 14.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                              ),
                      ),
                      // زر تحميل المصحف بالكامل (يختفي إذا كان المصحف محملاً بالكامل بالفعل)
                      if (!_isQuranDownloaded) ...[
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _downloadService.downloadEntireQuran(
                                _selectedReciter.key,
                                _selectedReciter,
                              );
                              await _updateDownloadStatuses();
                            },
                            icon: Icon(Icons.library_books_rounded, color: goldColor, size: 18.r),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'audio_download_quran'.tr,
                                style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.bold, color: goldColor),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: goldColor,
                              side: BorderSide(color: goldColor, width: 1.5),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // زر حذف جميع الصوتيات للقارئ الحالي (يظهر فقط إذا كان هناك أي تنزيلات للقارئ)
                  if (_hasAnyDownloads)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          MyDialog.show(
                            title: 'audio_delete_all_reciter'.tr,
                            content: 'audio_delete_all_reciter_confirm'.trParams({
                              'reciter': _selectedReciter.name,
                            }),
                            confirmText: 'confirm'.tr,
                            cancelText: 'cancel'.tr,
                            icon: Icons.delete_sweep_rounded,
                            onConfirm: () async {
                              await _downloadService.deleteReciterAudio(_selectedReciter.key);
                              await _updateDownloadStatuses();
                            },
                          );
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                        label: Text(
                          'audio_delete_all_reciter'.tr,
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // شريط تقدم التحميل السفلي (يظهر فوق شريط التحكم السفلي)
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 84.h,
            child: Obx(() {
              if (_downloadService.isDownloading.value) {
                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: goldColor.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(12.r),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _downloadService.downloadStatus.value,
                              style: TextStyle(fontSize: 13.sp, color: textColor, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (_downloadService.downloadSizeText.value.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                _downloadService.downloadSizeText.value,
                                style: TextStyle(fontSize: 12.sp, color: textColor.withOpacity(0.7)),
                              ),
                            ],
                            SizedBox(height: 8.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: _downloadService.downloadProgress.value,
                                backgroundColor: goldColor.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                                minHeight: 6.h,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      IconButton(
                        onPressed: () => _downloadService.togglePause(),
                        icon: Icon(
                          _downloadService.isPaused.value
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: goldColor,
                          size: 24.r,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _downloadService.cancelActiveDownload(),
                        icon: Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 24.r),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ),

          // شريط تشغيل الصوت والتحكم السفلي (يظهر الآن في أسفل الـ body مباشرة فوق البار)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8.r,
                    offset: Offset(0, -2.h),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // معلومات السورة الحالية
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'surah'.tr}: ${quran_pkg.getSurahNameArabic(_selectedSurah)}',
                          style: TextStyle(color: textColor, fontSize: 14.sp, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${'ayah'.tr}: $_startVerse - $_endVerse',
                          style: TextStyle(color: textVariantColor, fontSize: 11.sp),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // أزرار التشغيل، الإيقاف المؤقت، والإيقاف الكامل
                  Row(
                    children: [
                      // زر التشغيل (Play)
                      Obx(() {
                        final playing = _audioService.isPlaying.value;
                        return FloatingActionButton(
                          heroTag: 'play_btn',
                          backgroundColor: playing ? Colors.grey : goldColor,
                          mini: true,
                          elevation: playing ? 0 : 2,
                          onPressed: playing
                              ? null
                              : () {
                                  if (_audioService.playingVerses.isNotEmpty) {
                                    _audioService.resume();
                                  } else {
                                    _playSelectedRange();
                                  }
                                },
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24.r,
                          ),
                        );
                      }),
                      SizedBox(width: 8.w),
                      // زر الإيقاف المؤقت (Pause)
                      Obx(() {
                        final playing = _audioService.isPlaying.value;
                        return IconButton(
                          onPressed: !playing ? null : () => _audioService.pause(),
                          icon: Icon(
                            Icons.pause_rounded,
                            color: !playing ? Colors.grey.withOpacity(0.5) : goldColor,
                            size: 26.r,
                          ),
                        );
                      }),
                      SizedBox(width: 4.w),
                      // زر الإيقاف الكامل (Stop)
                      IconButton(
                        onPressed: () => _audioService.stop(),
                        icon: Icon(
                          Icons.stop_rounded,
                          color: goldColor,
                          size: 26.r,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
