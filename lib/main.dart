import 'dart:async';
import 'dart:isolate';
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
import 'pages/sunnah_page.dart';
import 'services/audio_download_service.dart';
import 'services/audio_service.dart';
import 'services/memorization_speech_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';
import 'services/qibla_service.dart';
import 'services/quran_library_bootstrap.dart';
import 'services/quran_service.dart';
import 'services/storage_service.dart';

import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if we are running in the background isolate
  final isBackground = Isolate.current.debugName != null && Isolate.current.debugName != 'main';
  if (isBackground) {
    debugPrint('Running in background isolate (${Isolate.current.debugName}), running empty App.');
    runApp(const SizedBox.shrink());
    return;
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.audioservice.notification',
      androidNotificationChannelName: 'تلاوة القرآن الكريم',
      androidNotificationOngoing: false,
      androidShowNotificationBadge: true,
    );
  } catch (e) {
    debugPrint('Error initializing JustAudioBackground: $e');
  }

  // تثبيت التطبيق في الوضع الرأسي فقط
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storage = StorageService();
  await storage.init();
  await initQuranLibrary();

  Get.put(storage, permanent: true);
  Get.put(NotificationService(storage), permanent: true);
  Get.put(PrayerService(storage), permanent: true);
  Get.put(QuranService(storage), permanent: true);
  Get.put(QuranAudioService(), permanent: true);
  Get.put(AudioDownloadService(), permanent: true);
  Get.put(MemorizationSpeechService(), permanent: true);
  Get.put(QiblaService(), permanent: true);
  Get.put(AppController(storage), permanent: true);
  Get.put(
    PrayerController(
      Get.find<PrayerService>(),
      Get.find<NotificationService>(),
    ),
    permanent: true,
  );
  Get.lazyPut(
    () => QuranController(
      Get.find<QuranService>(),
      Get.find<QuranAudioService>(),
    ),
    fenix: true,
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
        () {
          final isNight = controller.isNightMode.value;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: isNight ? AppTheme.statusBarDark : AppTheme.statusBarLight,
              statusBarIconBrightness: isNight ? Brightness.light : Brightness.dark,
              statusBarBrightness: isNight ? Brightness.dark : Brightness.light,
            ),
          );

          return GetMaterialApp(
            title: 'Hayah',
            debugShowCheckedModeBanner: false,
            translations: AppTranslations(),
            locale: Locale(controller.currentLanguage.value),
            fallbackLocale: const Locale('ar'),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.nightTheme,
            themeMode: isNight ? ThemeMode.dark : ThemeMode.light,
            home: const StartupSplash(),
          );
        },
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
        final isNight = Get.find<AppController>().isNightMode.value;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: isNight ? AppTheme.statusBarDark : AppTheme.statusBarLight,
            statusBarIconBrightness: isNight ? Brightness.light : Brightness.dark,
            statusBarBrightness: isNight ? Brightness.dark : Brightness.light,
          ),
        );
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
    final isNight = Get.find<AppController>().isNightMode.value;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isNight ? AppTheme.statusBarDark : AppTheme.statusBarLight,
        statusBarIconBrightness: isNight ? Brightness.light : Brightness.dark,
        statusBarBrightness: isNight ? Brightness.dark : Brightness.light,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) {
      return const UserNameGate();
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

class UserNameGate extends StatelessWidget {
  const UserNameGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController controller = Get.find<AppController>();

    return Obx(
      () => controller.hasUserName ? const MainRouter() : const UserNamePage(),
    );
  }
}

class UserNamePage extends StatefulWidget {
  const UserNamePage({super.key});

  @override
  State<UserNamePage> createState() => _UserNamePageState();
}

class _UserNamePageState extends State<UserNamePage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await Get.find<AppController>().setUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const goldColor = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mosque, color: goldColor, size: 54),
                  const SizedBox(height: 18),
                  Text(
                    'مرحباً بك في حياة',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اكتب اسمك ليظهر داخل التطبيق بدل الاسم الافتراضي.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveName(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'اسمك',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: goldColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: goldColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveName,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'متابعة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      final isNight = controller.isNightMode.value;
      
      final overlayStyle = SystemUiOverlayStyle(
        statusBarColor: isNight ? AppTheme.statusBarDark : AppTheme.statusBarLight,
        statusBarIconBrightness: isNight ? Brightness.light : Brightness.dark,
        statusBarBrightness: isNight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isNight ? Brightness.light : Brightness.dark,
      );

      Widget child;
      switch (controller.activePageIndex.value) {
        case 1:
          child = const SalatPage();
          break;
        case 2:
          child = const QuranPage();
          break;
        case 3:
          child = const SunnahPage();
          break;
        case 5:
          child = const ProfilePage();
          break;
        default:
          child = const HomePage();
          break;
      }


      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: child,
      );
    });
  }
}
