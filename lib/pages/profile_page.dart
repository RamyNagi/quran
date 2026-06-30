import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/notification_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final goldColor = theme.brightness == Brightness.dark
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC5A059);

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 40.h),
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: goldColor, size: 28.r),
                  SizedBox(width: 12.w),
                  Text(
                    'profile'.tr,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              Center(
                child: Container(
                  width: 104.r,
                  height: 104.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: goldColor.withValues(alpha: 0.12),
                    border: Border.all(color: goldColor, width: 2),
                  ),
                  child: Icon(Icons.person, color: goldColor, size: 58.r),
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () => Text(
                  controller.userName.value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 36.h),
              Text(
                'settings'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: goldColor,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Obx(
                () => _SettingsCard(
                  icon: Icons.badge_outlined,
                  title: 'name_label'.tr,
                  subtitle: controller.userName.value,
                  goldColor: goldColor,
                  trailing: TextButton(
                    onPressed: () => _showEditNameSheet(context, controller),
                    child: Text('edit'.tr, style: TextStyle(color: goldColor)),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              _SettingsCard(
                icon: Icons.language,
                title: 'language'.tr,
                goldColor: goldColor,
                trailing: Obx(
                  () => OutlinedButton(
                    onPressed: controller.toggleLanguage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(color: goldColor),
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 10.h,
                      ),
                    ),
                    child: Text(
                      controller.currentLanguage.value == 'en' ? 'AR' : 'EN',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () => _SettingsCard(
                  icon: controller.isNightMode.value
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  title: 'appearance'.tr,
                  subtitle: controller.isNightMode.value
                      ? 'theme_night'.tr
                      : 'theme_light'.tr,
                  goldColor: goldColor,
                  trailing: Switch.adaptive(
                    value: controller.isNightMode.value,
                    activeColor: goldColor,
                    onChanged: (_) => controller.toggleTheme(),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Obx(
                () => _SettingsCard(
                  icon: controller.dhikrReminderEnabled.value
                      ? Icons.notifications_active
                      : Icons.self_improvement,
                  title: 'dhikr_reminders'.tr,
                  subtitle: 'dhikr_reminders_desc'.trParams({
                    'mode': controller.dhikrReminderModeLabel,
                  }),
                  goldColor: goldColor,
                  trailing: Switch.adaptive(
                    value: controller.dhikrReminderEnabled.value,
                    activeColor: goldColor,
                    onChanged: controller.setDhikrReminderEnabled,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Obx(
                () => _DhikrOptionsCard(
                  icon: Icons.tune,
                  title: 'dhikr_reminder_mode'.tr,
                  subtitle: controller.dhikrReminderEnabled.value
                      ? 'dhikr_reminder_mode_desc'.tr
                      : 'dhikr_reminder_disabled_desc'.tr,
                  goldColor: goldColor,
                  child: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _ChoiceChipButton(
                        label: 'dhikr_mode_once_daily'.tr,
                        selected:
                            controller.dhikrReminderMode.value ==
                            DhikrReminderMode.onceDaily,
                        enabled: controller.dhikrReminderEnabled.value,
                        goldColor: goldColor,
                        onSelected: () => controller.setDhikrReminderMode(
                          DhikrReminderMode.onceDaily,
                        ),
                      ),
                      _ChoiceChipButton(
                        label: 'dhikr_mode_morning_evening'.tr,
                        selected:
                            controller.dhikrReminderMode.value ==
                            DhikrReminderMode.morningEvening,
                        enabled: controller.dhikrReminderEnabled.value,
                        goldColor: goldColor,
                        onSelected: () => controller.setDhikrReminderMode(
                          DhikrReminderMode.morningEvening,
                        ),
                      ),
                      _ChoiceChipButton(
                        label: 'dhikr_mode_after_prayers'.tr,
                        selected:
                            controller.dhikrReminderMode.value ==
                            DhikrReminderMode.afterPrayers,
                        enabled: controller.dhikrReminderEnabled.value,
                        goldColor: goldColor,
                        onSelected: () => controller.setDhikrReminderMode(
                          DhikrReminderMode.afterPrayers,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Obx(
                () => _DhikrOptionsCard(
                  icon: Icons.flag_outlined,
                  title: 'dhikr_daily_target'.tr,
                  subtitle: 'dhikr_daily_target_desc'.tr,
                  goldColor: goldColor,
                  child: Wrap(
                    spacing: 8.w,
                    children: [
                      for (final target in const [1, 3, 5])
                        _ChoiceChipButton(
                          label: '$target',
                          selected: controller.dhikrDailyTarget.value == target,
                          enabled: true,
                          goldColor: goldColor,
                          onSelected: () =>
                              controller.setDhikrDailyTarget(target),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }
}

void _showEditNameSheet(BuildContext context, AppController controller) {
  final nameController = TextEditingController(text: controller.userName.value);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final goldColor = theme.brightness == Brightness.dark
          ? const Color(0xFFD4AF37)
          : const Color(0xFFC5A059);

      return SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20.w,
              18.h,
              20.w,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 22.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تعديل الاسم',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async {
                    await controller.setUserName(nameController.text);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  decoration: InputDecoration(
                    labelText: 'اسمك',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: goldColor),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                FilledButton(
                  onPressed: () async {
                    await controller.setUserName(nameController.text);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(nameController.dispose);
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.goldColor,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color goldColor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: goldColor, size: 22.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

class _DhikrOptionsCard extends StatelessWidget {
  const _DhikrOptionsCard({
    required this.icon,
    required this.title,
    required this.goldColor,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color goldColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: goldColor, size: 22.r),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.goldColor,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color goldColor;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onSelected() : null,
      selectedColor: goldColor.withValues(alpha: 0.22),
      disabledColor: theme.disabledColor.withValues(alpha: 0.08),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: enabled
            ? (selected ? goldColor : theme.colorScheme.onSurface)
            : theme.disabledColor,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? goldColor : goldColor.withValues(alpha: 0.22),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    );
  }
}
