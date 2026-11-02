import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/banner.dart';
import 'package:madar_sat/design/components/button.dart';
import 'package:madar_sat/design/components/dialog.dart';
import 'package:madar_sat/design/components/form_controls.dart';
import 'package:madar_sat/design/components/list_row.dart';
import 'package:madar_sat/design/components/progress_dots.dart';

import 'golden_harness.dart';

/// D3's new components, in RTL × {light, dark} × {1.0, 1.3} (T124, constitution IV): each
/// state the READMEs name, drawn from tokens only.
void main() {
  testWidgets('list row states', (tester) async {
    await goldenVariants(
      tester,
      'list_row',
      (context) => SizedBox(
        width: 328,
        child: MadarListGroup(
          children: [
            MadarListRow(
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              subtitle: 'التوقيت، المظهر، أقماري',
              showChevron: true,
              onTap: () {},
            ),
            MadarListRow(
              icon: Icons.satellite_alt,
              title: 'اختر أقماري',
              subtitle: 'نايل سات، بدر',
              showChevron: true,
              onTap: () {},
            ),
            MadarListRow(
              icon: Icons.public,
              title: 'المنطقة الزمنية',
              value: 'تلقائي (GMT+3)',
              showChevron: true,
              onTap: () {},
            ),
            MadarListRow(
              icon: Icons.delete_outline,
              title: 'حذف بيانات جهازي',
              subtitle: 'المتابعات ورمز الإشعارات من الخادم',
              danger: true,
              showChevron: true,
              onTap: () {},
            ),
            const MadarListRow(
              icon: Icons.notifications_none,
              title: 'الإشعارات',
              trailing: MadarSwitch(value: true, onChanged: null, label: 'الإشعارات'),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('button variants and the follow and bell toggles', (tester) async {
    await goldenVariants(
      tester,
      'buttons',
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final variant in MadarButtonVariant.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MadarSpace.s1),
              child: MadarButton(label: 'تحديث الآن', variant: variant, onPressed: () {}),
            ),
          // The busy state spins forever, so it is not a static golden; its layout is the
          // button's own and is checked in the widget tests.
          const SizedBox(height: MadarSpace.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FollowButton(
                following: false,
                label: 'تابع',
                followingLabel: 'تتابعه',
                onPressed: () {},
              ),
              const SizedBox(width: MadarSpace.s2),
              FollowButton(
                following: true,
                label: 'تابع',
                followingLabel: 'تتابعه',
                onPressed: () {},
              ),
              const SizedBox(width: MadarSpace.s2),
              BellButton(on: true, label: 'تنبيهات', onPressed: () {}),
              BellButton(on: false, label: 'تنبيهات', onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  });

  testWidgets('the delete dialog', (tester) async {
    await goldenVariants(
      tester,
      'madar_dialog',
      (context) => const SizedBox(
        width: 320,
        child: MadarDialog(
          title: 'حذف بيانات جهازي؟',
          body: 'سنحذف متابعاتك ورمز الإشعارات من الخادم، وسيبدأ التطبيق من جديد.',
          confirmLabel: 'حذف',
        ),
      ),
    );
  });

  testWidgets('banners and the exit snackbar', (tester) async {
    await goldenVariants(
      tester,
      'banner',
      (context) => const SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OfflineBanner(age: Duration(minutes: 12)),
            SizedBox(height: MadarSpace.s3),
            ExitSnackbar(),
          ],
        ),
      ),
    );
  });

  testWidgets('form controls', (tester) async {
    await goldenVariants(
      tester,
      'form_controls',
      (context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MadarSwitch(value: true, onChanged: (_) {}, label: 'مفعّل'),
          MadarSwitch(value: false, onChanged: (_) {}, label: 'متوقف'),
          const MadarSwitch(value: true, onChanged: null, label: 'معطّل', enabled: false),
          MadarRadio(selected: true, onTap: () {}, label: 'مختار'),
          MadarRadio(selected: false, onTap: () {}, label: 'غير مختار'),
          MadarCheckbox(checked: true, onChanged: (_) {}, label: 'محدّد'),
          MadarCheckbox(checked: false, onChanged: (_) {}, label: 'غير محدّد'),
        ],
      ),
    );
  });

  testWidgets('progress dots', (tester) async {
    await goldenVariants(
      tester,
      'progress_dots',
      (context) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressDots(current: 0, count: 4),
          SizedBox(height: MadarSpace.s3),
          ProgressDots(current: 2, count: 4),
          SizedBox(height: MadarSpace.s3),
          ProgressDots(current: 3, count: 4),
        ],
      ),
    );
  });
}
