import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/empty_state.dart';

import 'golden_harness.dart';

void main() {
  testWidgets('EmptyState golden variants', (tester) async {
    await goldenVariants(
      tester,
      'empty_state',
      (context) => Column(
        children: [
          const EmptyState(
            title: 'لا توجد مباريات في هذا اليوم',
            body: 'جرّب يوماً آخر أو اسحب القائمة لتحديثها.',
          ),
          EmptyState(
            kind: EmptyStateKind.error,
            title: 'تعذّر تحميل البيانات',
            body: 'حدث خطأ غير متوقع',
            action: TextButton(onPressed: () {}, child: const Text('إعادة المحاولة')),
          ),
          const EmptyState(kind: EmptyStateKind.allClear, title: 'انتهت'),
          const SizedBox(height: MadarSpace.s4),
        ],
      ),
    );
  });
}
