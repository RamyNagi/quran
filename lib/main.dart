import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'controllers/app_controller.dart';
import 'localization/app_translations.dart';
import 'theme/app_theme.dart';
import 'pages/landing_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the GetX Controller
  Get.put(AppController());

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
      builder: (_, __) => Obx(
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
          return const HomePage();
        case 5:
          return const ProfilePage();
        default:
          return const LandingPage();
      }
    });
  }
}
