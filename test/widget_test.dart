import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/main.dart';

void main() {
  testWidgets('SetAndSit app loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SetAndSitApp());
    expect(find.text('Set&Sit'), findsOneWidget);
    expect(find.text('Adaptive Guided Meditation'), findsOneWidget);
    expect(find.text('Practice Ends At'), findsOneWidget);
  });

  testWidgets('Tapping anywhere in circle opens time picker adjustment dialog', (WidgetTester tester) async {
    await tester.pumpWidget(const SetAndSitApp());

    // Tap on 'Practice Ends At' inside the circle
    await tester.tap(find.text('Practice Ends At'));
    await tester.pumpAndSettle();

    // Verify TimePicker is shown (contains Cancel button / Select time)
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    // Dismiss time picker
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Tap on 'Tap to Adjust' inside the circle
    await tester.tap(find.text('Tap to Adjust'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
