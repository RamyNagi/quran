// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;

import '../controllers/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import 'quran_memorization_page.dart';

class QuranMemorizationSetupPage extends StatefulWidget {
  const QuranMemorizationSetupPage({
    super.key,
    required this.initialSurah,
    required this.initialStartVerse,
    required this.initialEndVerse,
  });

  final int initialSurah;
  final int initialStartVerse;
  final int initialEndVerse;

  @override
  State<QuranMemorizationSetupPage> createState() =>
      _QuranMemorizationSetupPageState();
}

class _QuranMemorizationSetupPageState
    extends State<QuranMemorizationSetupPage> {
  late int _selectedSurah;
  late int _startVerse;
  late int _endVerse;

  @override
  void initState() {
    super.initState();
    _selectedSurah = widget.initialSurah;
    _startVerse = widget.initialStartVerse;
    _endVerse = widget.initialEndVerse;
  }

  void _startMemorization() {
    Get.to(() => QuranMemorizationPage(
          initialSurah: _selectedSurah,
          initialStartVerse: _startVerse,
          initialEndVerse: _endVerse,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final verseCount = quran_text.getVerseCount(_selectedSurah);
    final surahName = quran_text.getSurahNameArabic(_selectedSurah);
    final appController = Get.find<AppController>();

    return Obx(() {
      final isNight = appController.isNightMode.value;

      final Color bgColor = isNight ? AppTheme.backgroundNight : AppTheme.backgroundLight;
      final Color goldColor = isNight ? AppTheme.textVariantNight : AppTheme.primaryLight;
      final Color textColor = isNight ? AppTheme.textNight : AppTheme.textLight;
      final Color textVariantColor = isNight ? AppTheme.textVariantNight : AppTheme.textVariantLight;
      final Color dropdownColor = isNight ? const Color(0xFF151515) : Colors.white;
      final Color borderColor = isNight ? Colors.white24 : Colors.black26;

      return Theme(
        data: ThemeData(
          brightness: isNight ? Brightness.dark : Brightness.light,
          useMaterial3: true,
        ).copyWith(
          scaffoldBackgroundColor: bgColor,
          colorScheme: isNight
              ? ColorScheme.dark(
                  primary: goldColor,
                  secondary: goldColor,
                  surface: Colors.black,
                )
              : ColorScheme.light(
                  primary: goldColor,
                  secondary: goldColor,
                  surface: Colors.white,
                ),
        ),
        child: Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            foregroundColor: textColor,
            elevation: 0,
            title: Text('tashmee_setup_title'.tr),
            centerTitle: true,
          ),
          bottomNavigationBar: const AppBottomNav(currentIndex: 2),
          body: SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── أيقونة وعنوان ──
                    Center(
                      child: Container(
                        width: 80.r,
                        height: 80.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: goldColor, width: 2),
                          color: goldColor.withOpacity(0.08),
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: goldColor,
                          size: 42.r,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Center(
                      child: Text(
                        'tashmee_assistant'.tr,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Center(
                      child: Text(
                        'tashmee_setup_subtitle'.tr,
                        style: TextStyle(
                          color: textVariantColor,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // ── معاينة الاختيار ──
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: goldColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: goldColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              color: goldColor, size: 20.r),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              '$surahName  •  الآية $_startVerse ← الآية $_endVerse',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: goldColor,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // ── اختيار السورة ──
                    _buildLabel('السورة', textVariantColor),
                    SizedBox(height: 8.h),
                    _buildDropdown<int>(
                      value: _selectedSurah,
                      dropdownColor: dropdownColor,
                      borderColor: borderColor,
                      goldColor: goldColor,
                      textColor: textColor,
                      items: List.generate(quran_text.totalSurahCount, (index) {
                        final surah = index + 1;
                        return DropdownMenuItem<int>(
                          value: surah,
                          child: Text(
                            '$surah. ${quran_text.getSurahNameArabic(surah)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textColor),
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedSurah = value;
                          _startVerse = 1;
                          _endVerse = quran_text.getVerseCount(value);
                        });
                      },
                    ),
                    SizedBox(height: 20.h),

                    // ── من آية ──
                    _buildLabel('من الآية', textVariantColor),
                    SizedBox(height: 8.h),
                    _buildDropdown<int>(
                      value: _startVerse,
                      dropdownColor: dropdownColor,
                      borderColor: borderColor,
                      goldColor: goldColor,
                      textColor: textColor,
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text(
                            'الآية $verse',
                            style: TextStyle(color: textColor),
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _startVerse = value;
                          if (_endVerse < value) _endVerse = value;
                        });
                      },
                    ),
                    SizedBox(height: 20.h),

                    // ── إلى آية ──
                    _buildLabel('إلى الآية', textVariantColor),
                    SizedBox(height: 8.h),
                    _buildDropdown<int>(
                      value: _endVerse,
                      dropdownColor: dropdownColor,
                      borderColor: borderColor,
                      goldColor: goldColor,
                      textColor: textColor,
                      items: List.generate(
                        verseCount - _startVerse + 1,
                        (index) {
                          final verse = _startVerse + index;
                          return DropdownMenuItem<int>(
                            value: verse,
                            child: Text(
                              'الآية $verse',
                              style: TextStyle(color: textColor),
                            ),
                          );
                        },
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _endVerse = value);
                      },
                    ),
                    SizedBox(height: 40.h),

                    // ── زر البدء ──
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: goldColor,
                        foregroundColor: isNight ? Colors.black : Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: _startMemorization,
                      icon: Icon(Icons.play_arrow_rounded, size: 26.r),
                      label: Text(
                        'tashmee_start'.tr,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Center(
                      child: Text(
                        'tashmee_setup_desc'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textVariantColor.withOpacity(0.7),
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required Color dropdownColor,
    required Color borderColor,
    required Color goldColor,
    required Color textColor,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: dropdownColor,
      decoration: InputDecoration(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(12.r),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: goldColor),
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      style: TextStyle(color: textColor, fontSize: 15.sp),
      items: items,
      onChanged: onChanged,
    );
  }
}
