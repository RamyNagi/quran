import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  static const _goldColor = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: _goldColor,
          secondary: _goldColor,
          surface: Colors.black,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: _goldColor,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => appController.navigateToPage(0),
                      icon: const Icon(Icons.home_rounded),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.menu_book_rounded,
                    color: _goldColor,
                    size: 64,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'صفحة المصحف الكاملة تعمل على Android و iOS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'أنت تشغل التطبيق الآن على Web/Chrome، ومكتبة المصحف والتفسير تستخدم SQLite/FFI وهي غير مدعومة على الويب. شغل التطبيق على الهاتف أو المحاكي لرؤية المصحف الكامل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      height: 1.7,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
