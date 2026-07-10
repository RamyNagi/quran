import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../controllers/prayer_controller.dart';
import '../services/qibla_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';

class SalatPage extends StatelessWidget {
  const SalatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = theme.colorScheme.secondary;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: Obx(() {
            final day = controller.prayerDay.value;
            return RefreshIndicator(
              onRefresh: controller.refreshPrayerTimes,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 100.h),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: accentColor, size: 28.r),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'prayer_times'.tr,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: controller.refreshPrayerTimes,
                        icon: controller.isLoading.value
                            ? SizedBox(
                                width: 18.r,
                                height: 18.r,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accentColor,
                                ),
                              )
                            : Icon(Icons.my_location, color: accentColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (controller.errorMessage.value.isNotEmpty)
                    _InfoBanner(
                      text: controller.errorMessage.value,
                      goldColor: goldColor,
                    ),
                  SizedBox(height: 16.h),
                  if (day == null)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80.h),
                        child: CircularProgressIndicator(color: goldColor),
                      ),
                    )
                  else ...[
                    _NextPrayerCard(
                      goldColor: goldColor,
                      title: day.nextPrayerKey.tr,
                      time: controller.formatTime(day.nextPrayerTime),
                      countdown: controller.countdownText(),
                      location: day.locationLabel,
                      qibla: day.qiblaDegrees,
                    ),
                    SizedBox(height: 20.h),
                    _QiblaCompassCard(
                      qiblaDegrees: day.qiblaDegrees,
                      goldColor: goldColor,
                    ),
                    SizedBox(height: 20.h),
                    for (final prayer in day.prayers) ...[
                      _PrayerRow(
                        name: prayer.labelKey.tr,
                        time: controller.formatTime(prayer.time),
                        active: prayer.key == day.nextPrayerKey,
                        mode: controller.getNotificationMode(prayer.key),
                        goldColor: goldColor,
                        onTapSettings: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (sheetContext) => _AlertSettingsSheet(
                              prayerKey: prayer.key,
                              prayerName: prayer.labelKey.tr,
                              controller: controller,
                              goldColor: goldColor,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 10.h),
                    ],
                    SizedBox(height: 10.h),
                    _GlobalEarlyReminderCard(
                      controller: controller,
                      goldColor: goldColor,
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({
    required this.goldColor,
    required this.title,
    required this.time,
    required this.countdown,
    required this.location,
    required this.qibla,
  });

  final Color goldColor;
  final String title;
  final String time;
  final String countdown;
  final String location;
  final double qibla;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final cardBg = isDark
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
        : theme.colorScheme.primary.withValues(alpha: 0.95);

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark
              ? goldColor.withValues(alpha: 0.25)
              : theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: isDark ? goldColor : theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                size: 18.r,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? theme.textTheme.bodySmall?.color : theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Text(
            'next_prayer'.tr,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? goldColor : theme.colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 36.sp,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'in_time'.trParams({'time': countdown}),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? theme.colorScheme.inversePrimary : const Color(0xFFD1F2E5),
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 16.h),
          InkWell(
            onTap: null,
            child: Row(
              children: [
                Icon(
                  Icons.explore,
                  color: isDark ? goldColor : theme.colorScheme.onPrimary,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${'qibla_direction'.tr}: ${qibla.toStringAsFixed(1)}°',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? goldColor : theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaCompassCard extends StatefulWidget {
  const _QiblaCompassCard({
    required this.qiblaDegrees,
    required this.goldColor,
  });

  final double qiblaDegrees;
  final Color goldColor;

  @override
  State<_QiblaCompassCard> createState() => _QiblaCompassCardState();
}

class _QiblaCompassCardState extends State<_QiblaCompassCard> {
  late final QiblaService _qiblaService;
  Future<bool>? _supportFuture;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _qiblaService = Get.find<QiblaService>();
  }

  Future<bool> _initCompass() async {
    final supported = await _qiblaService.supportsCompass();
    if (supported) {
      await _qiblaService.requestPermissions();
    }
    return supported;
  }

  void _startCompass() {
    setState(() {
      _isActive = true;
      _supportFuture = _initCompass();
    });
  }

  void _stopCompass() {
    _qiblaService.disposeCompass();
    setState(() {
      _isActive = false;
      _supportFuture = null;
    });
  }

  @override
  void dispose() {
    _qiblaService.disposeCompass();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark
              ? widget.goldColor.withValues(alpha: 0.18)
              : theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.03),
                  blurRadius: 10.r,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: !_isActive
          ? _CompassIdleContent(
              goldColor: widget.goldColor,
              qiblaDegrees: widget.qiblaDegrees,
              onStart: _startCompass,
            )
          : FutureBuilder<bool>(
        future: _supportFuture,
        builder: (context, supportSnapshot) {
          final supported = supportSnapshot.data ?? false;
          if (supportSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.r),
                child: CircularProgressIndicator(color: widget.goldColor),
              ),
            );
          }

          if (!supported) {
            return _CompassContent(
              goldColor: widget.goldColor,
              qiblaDegrees: widget.qiblaDegrees,
              headingDegrees: null,
              message: 'qibla_no_sensor'.tr,
              onStop: _stopCompass,
            );
          }

          return StreamBuilder<QiblahDirection>(
            stream: _qiblaService.directionStream,
            builder: (context, snapshot) {
              return _CompassContent(
                goldColor: widget.goldColor,
                qiblaDegrees: widget.qiblaDegrees,
                headingDegrees: snapshot.data?.direction,
                message: snapshot.hasError
                    ? 'qibla_stream_error'.tr
                    : 'qibla_align_hint'.tr,
                onStop: _stopCompass,
              );
            },
          );
        },
      ),
    );
  }
}

class _CompassIdleContent extends StatelessWidget {
  const _CompassIdleContent({
    required this.goldColor,
    required this.qiblaDegrees,
    required this.onStart,
  });

  final Color goldColor;
  final double qiblaDegrees;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.explore, color: accentColor),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'qibla'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${qiblaDegrees.toStringAsFixed(1)}°',
              style: theme.textTheme.headlineMedium?.copyWith(color: accentColor),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Text(
          'qibla_on_demand_hint'.tr,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        SizedBox(height: 14.h),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.explore),
          label: Text('start_qibla'.tr),
        ),
      ],
    );
  }
}

class _CompassContent extends StatelessWidget {
  const _CompassContent({
    required this.goldColor,
    required this.qiblaDegrees,
    required this.headingDegrees,
    required this.message,
    required this.onStop,
  });

  final Color goldColor;
  final double qiblaDegrees;
  final double? headingDegrees;
  final String message;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;
    final rotation = ((qiblaDegrees - (headingDegrees ?? 0)) + 360) % 360;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.explore, color: accentColor),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'qibla'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${qiblaDegrees.toStringAsFixed(1)}°',
              style: theme.textTheme.headlineMedium?.copyWith(color: accentColor),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: 190.r,
          height: 190.r,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
              ),
              Positioned(top: 12.h, child: Text('N', style: _label(theme))),
              Positioned(bottom: 12.h, child: Text('S', style: _label(theme))),
              Positioned(left: 16.w, child: Text('W', style: _label(theme))),
              Positioned(right: 16.w, child: Text('E', style: _label(theme))),
              Transform.rotate(
                angle: rotation * math.pi / 180,
                child: Icon(Icons.navigation, color: accentColor, size: 72.r),
              ),
              Container(
                width: 10.r,
                height: 10.r,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (headingDegrees != null) ...[
          SizedBox(height: 6.h),
          Text(
            '${'device_heading'.tr}: ${headingDegrees!.toStringAsFixed(1)}°',
            style: theme.textTheme.bodySmall?.copyWith(
              color: accentColor.withValues(alpha: 0.75),
            ),
          ),
        ],
        SizedBox(height: 10.h),
        TextButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text('stop_qibla'.tr),
        ),
      ],
    );
  }

  TextStyle? _label(ThemeData theme) =>
      theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.active,
    required this.mode,
    required this.goldColor,
    required this.onTapSettings,
  });

  final String name;
  final String time;
  final bool active;
  final String mode;
  final Color goldColor;
  final VoidCallback onTapSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? goldColor : theme.colorScheme.primary;
    final activeBg = isDark ? goldColor.withValues(alpha: 0.08) : theme.colorScheme.primary.withValues(alpha: 0.06);
    final activeBorder = isDark ? goldColor.withValues(alpha: 0.35) : theme.colorScheme.primary.withValues(alpha: 0.3);

    IconData getModeIcon() {
      switch (mode) {
        case 'disabled':
          return Icons.notifications_off_rounded;
        case 'silent':
          return Icons.volume_off_rounded;
        case 'makkah':
        case 'madinah':
          return Icons.volume_up_rounded;
        case 'default':
        default:
          return Icons.notifications_active_rounded;
      }
    }

    Color getModeColor(Color fallbackPrimary) {
      if (mode == 'disabled') {
        return Colors.grey.withValues(alpha: 0.5);
      }
      return fallbackPrimary;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: active
            ? activeBg
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: active 
              ? activeBorder 
              : (isDark ? goldColor.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.notifications_active : Icons.schedule,
            color: active ? activeColor : (isDark ? goldColor.withValues(alpha: 0.6) : theme.colorScheme.primary.withValues(alpha: 0.5)),
            size: 22.r,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? activeColor : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          Text(
            time,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 20.sp,
              color: active ? activeColor : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            icon: Icon(
              getModeIcon(),
              color: active ? activeColor : getModeColor(isDark ? goldColor : theme.colorScheme.primary),
              size: 24.r,
            ),
            onPressed: onTapSettings,
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.goldColor});

  final String text;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? goldColor : theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        text, 
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDark ? theme.textTheme.bodySmall?.color : theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AlertSettingsSheet extends StatefulWidget {
  const _AlertSettingsSheet({
    required this.prayerKey,
    required this.prayerName,
    required this.controller,
    required this.goldColor,
  });

  final String prayerKey;
  final String prayerName;
  final PrayerController controller;
  final Color goldColor;

  @override
  State<_AlertSettingsSheet> createState() => _AlertSettingsSheetState();
}

class _AlertSettingsSheetState extends State<_AlertSettingsSheet> {
  late String _selectedMode;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingPreview; // 'makkah', 'madinah' or null

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.controller.getNotificationMode(widget.prayerKey);
    
    // Listen to player state to reset playingPreview when audio completes
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _playingPreview = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String type) async {
    if (_playingPreview == type) {
      await _audioPlayer.stop();
      setState(() {
        _playingPreview = null;
      });
    } else {
      await _audioPlayer.stop();
      setState(() {
        _playingPreview = type;
      });
      try {
        final path = type == 'makkah' 
            ? 'assets/sounds/adhan_makkah.mp3' 
            : 'assets/sounds/adhan_madinah.mp3';
        await _audioPlayer.setAudioSource(
          AudioSource.asset(
            path,
            tag: MediaItem(
              id: 'adhan_$type',
              title: type == 'makkah' ? 'notification_mode_makkah'.tr : 'notification_mode_madinah'.tr,
              album: 'hayah'.tr,
            ),
          ),
        );
        _audioPlayer.play();
      } catch (e) {
        debugPrint("Error playing preview: $e");
        setState(() {
          _playingPreview = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? widget.goldColor : theme.colorScheme.primary;
    final textColor = isDark ? AppTheme.textNight : AppTheme.textLight;
    final cardColor = isDark ? AppTheme.surfaceNight : AppTheme.surfaceLight;

    final modes = [
      {'key': 'default', 'label': 'notification_mode_default'.tr, 'icon': Icons.notifications_active_rounded},
      {'key': 'makkah', 'label': 'notification_mode_makkah'.tr, 'icon': Icons.volume_up_rounded, 'hasPreview': true},
      {'key': 'madinah', 'label': 'notification_mode_madinah'.tr, 'icon': Icons.volume_up_rounded, 'hasPreview': true},
      {'key': 'silent', 'label': 'notification_mode_silent'.tr, 'icon': Icons.volume_off_rounded},
      {'key': 'disabled', 'label': 'notification_mode_disabled'.tr, 'icon': Icons.notifications_off_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF3A4E47) : widget.goldColor.withValues(alpha: 0.3),
            width: 2.w,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A4E47) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            '${'customize_alert'.tr}: ${widget.prayerName}',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 16.h),
          ...modes.map((m) {
            final isSelected = _selectedMode == m['key'];
            final hasPreview = m['hasPreview'] == true;
            final keyStr = m['key'] as String;
            final isCurrentPlaying = _playingPreview == keyStr;

            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryColor.withValues(alpha: 0.06) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected 
                      ? primaryColor.withValues(alpha: 0.3) 
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: ListTile(
                onTap: () {
                  setState(() {
                    _selectedMode = keyStr;
                  });
                  widget.controller.setNotificationMode(widget.prayerKey, keyStr);
                },
                leading: Icon(
                  m['icon'] as IconData,
                  color: isSelected ? primaryColor : textColor.withValues(alpha: 0.6),
                ),
                title: Text(
                  m['label'] as String,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14.sp,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPreview) ...[
                      IconButton(
                        onPressed: () => _togglePreview(keyStr),
                        icon: Icon(
                          isCurrentPlaying 
                              ? Icons.pause_circle_filled_rounded 
                              : Icons.play_circle_filled_rounded,
                          color: primaryColor,
                          size: 28.r,
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Radio<String>(
                      value: keyStr,
                      groupValue: _selectedMode,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedMode = val;
                          });
                          widget.controller.setNotificationMode(widget.prayerKey, val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}

class _GlobalEarlyReminderCard extends StatelessWidget {
  const _GlobalEarlyReminderCard({
    required this.controller,
    required this.goldColor,
  });

  final PrayerController controller;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? goldColor : theme.colorScheme.primary;
    final textColor = isDark ? AppTheme.textNight : AppTheme.textLight;
    final cardBg = isDark ? AppTheme.surfaceNight : Colors.white;

    return Obx(() {
      final earlyMinutes = controller.globalEarlyReminderMinutes.value;
      final earlySoundMode = controller.globalEarlyReminderSoundMode.value;

      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark
                ? const Color(0xFF3A4E47)
                : goldColor.withValues(alpha: 0.25),
            width: 1.5.w,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: primaryColor, size: 22.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'early_reminder_title'.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              'early_reminder_desc'.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2D27) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF3A4E47) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: earlyMinutes,
                  isExpanded: true,
                  dropdownColor: isDark ? AppTheme.surfaceNight : Colors.white,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
                  items: [
                    DropdownMenuItem(value: 0, child: Text('early_reminder_disabled'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                    DropdownMenuItem(value: 5, child: Text('minutes_5'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                    DropdownMenuItem(value: 10, child: Text('minutes_10'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                    DropdownMenuItem(value: 15, child: Text('minutes_15'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                    DropdownMenuItem(value: 20, child: Text('minutes_20'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                    DropdownMenuItem(value: 30, child: Text('minutes_30'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      controller.setGlobalEarlyReminderMinutes(val);
                    }
                  },
                ),
              ),
            ),
            if (earlyMinutes > 0) ...[
              SizedBox(height: 14.h),
              Text(
                'early_reminder_sound'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2D27) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3A4E47) : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: earlySoundMode,
                    isExpanded: true,
                    dropdownColor: isDark ? AppTheme.surfaceNight : Colors.white,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
                    items: [
                      DropdownMenuItem(value: 'default', child: Text('early_reminder_default'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                      DropdownMenuItem(value: 'silent', child: Text('early_reminder_silent'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                      DropdownMenuItem(value: 'makkah', child: Text('notification_mode_makkah'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                      DropdownMenuItem(value: 'madinah', child: Text('notification_mode_madinah'.tr, style: TextStyle(color: textColor, fontSize: 13.sp))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        controller.setGlobalEarlyReminderSoundMode(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
