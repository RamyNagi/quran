import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hayah/controllers/app_controller.dart';
import 'package:hayah/main.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('app starts on the landing page', (WidgetTester tester) async {
    Get.put(AppController());

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1900));

    expect(find.text('Hayah'), findsWidgets);
    expect(find.text('BEGIN REFLECTION'), findsOneWidget);
  });
}
