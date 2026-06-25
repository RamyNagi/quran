import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'controllers/app_controller.dart';
import 'controllers/prayer_controller.dart';
import 'controllers/quran_controller.dart';
import 'localization/app_translations.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/quran_page.dart';
import 'pages/salat_page.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';
import 'services/qibla_service.dart';
import 'services/quran_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  Get.put(storage, permanent: true);
  Get.put(NotificationService(storage), permanent: true);
  Get.put(PrayerService(storage), permanent: true);
  Get.put(QuranService(storage), permanent: true);
  Get.put(QuranAudioService(), permanent: true);
  Get.put(QiblaService(), permanent: true);
  Get.put(AppController(storage), permanent: true);
  Get.put(
    PrayerController(
      Get.find<PrayerService>(),
      Get.find<NotificationService>(),
    ),
    permanent: true,
  );
  Get.put(
    QuranController(Get.find<QuranService>(), Get.find<QuranAudioService>()),
    permanent: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();

    // ScreenUtilInit uses 390×844 (iPhone 14) as the design baseline.
    // All .w / .h / .sp / .r values scale proportionally on every device.
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => Obx(
        () => GetMaterialApp(
          title: 'Hayah',
          debugShowCheckedModeBanner: false,
          translations: AppTranslations(),
          locale: Locale(controller.currentLanguage.value),
          fallbackLocale: const Locale('en'),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.nightTheme,
          themeMode: controller.isNightMode.value
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const StartupSplash(),
        ),
      ),
    );
  }
}

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> {
  Timer? _timer;
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(const Duration(milliseconds: 1800), () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        if (mounted) {
          setState(() => _showApp = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) {
      return const MainRouter();
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Image.asset(
          'stitch_hayat/hayah.png/screen.png',
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class MainRouter extends StatelessWidget {
  const MainRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();

    return Obx(() {
      switch (controller.activePageIndex.value) {
        case 1:
          return const SalatPage();
        case 2:
          return const QuranPage();
        case 5:
          return const ProfilePage();
        default:
          return const HomePage();
      }
    });
  }
}
