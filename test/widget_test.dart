import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/screens/clock_time_picker_dialog.dart';
import 'package:setandsit/screens/practice_screen.dart';

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

    // Verify ClockTimePickerDialog is shown with live duration indicator, Cancel and OK
    expect(find.text('Select Finish Time'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    // Dismiss time picker
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Tap on 'Tap to Adjust' inside the circle
    await tester.tap(find.text('Tap to Adjust'));
    await tester.pumpAndSettle();

    expect(find.text('Select Finish Time'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('ClockTimePickerDialog displays live positive duration and negative duration in red without error dialog', (WidgetTester tester) async {
    final now = DateTime.now();

    // 1. Initialized with a future time (+20 minutes)
    final futureTime = now.add(const Duration(minutes: 20));
    final futureHour12 = futureTime.hour % 12 == 0 ? 12 : futureTime.hour % 12;
    final futureIsAm = futureTime.hour < 12;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClockTimePickerDialog(
            initialHour12: futureHour12,
            initialMinute: futureTime.minute,
            initialIsAm: futureIsAm,
          ),
        ),
      ),
    );

    // Should display positive duration
    expect(find.textContaining('min practice'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // 2. Initialized with a past time today (-10 minutes)
    final pastTime = now.subtract(const Duration(minutes: 10));
    final pastHour12 = pastTime.hour % 12 == 0 ? 12 : pastTime.hour % 12;
    final pastIsAm = pastTime.hour < 12;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClockTimePickerDialog(
            initialHour12: pastHour12,
            initialMinute: pastTime.minute,
            initialIsAm: pastIsAm,
          ),
        ),
      ),
    );

    // Negative duration should be displayed with red text and no popup dialog
    final negativeFinder = find.textContaining('-');
    expect(negativeFinder, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // Verify the negative text has red color
    final textWidget = tester.widget<Text>(negativeFinder);
    expect(textWidget.style?.color, const Color(0xFFD32F2F));
  });

  testWidgets('PracticeScreen displays and counts down silence item correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final silenceItem = PauseSilenceItem(
      15,
      displayTitle: 'Quiet Settling Space',
      phaseName: 'Phase 1: Settling',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          isDeveloperMode: true,
          sessionQueue: [silenceItem],
          targetDurationSeconds: 15,
          preparationDelaySeconds: 0,
          selectedMeditationType: 'Focused Calm',
          buildDebugScreen: () => const SizedBox.shrink(),
          onEndSession: () {},
        ),
      ),
    );

    expect(find.text('Quiet Settling Space'), findsOneWidget);
    expect(find.text('Phase 1: Settling'), findsOneWidget);
    expect(find.text('00:15'), findsWidgets);

    // Fast forward 5 seconds
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:10'), findsWidgets);
  });

  testWidgets('PracticeScreen displays preparation countdown and transitions to practice', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final silenceItem = PauseSilenceItem(
      60,
      displayTitle: 'Quiet Settling Space',
      phaseName: 'Phase 1: Settling',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          isDeveloperMode: true,
          sessionQueue: [silenceItem],
          targetDurationSeconds: 60,
          preparationDelaySeconds: 10,
          selectedMeditationType: 'Focused Calm',
          buildDebugScreen: () => const SizedBox.shrink(),
          onEndSession: () {},
        ),
      ),
    );

    // Initial state: Preparation countdown visible
    expect(find.text('10'), findsOneWidget);
    expect(find.text('seconds to settle'), findsOneWidget);
    expect(find.text('Settling In'), findsOneWidget);
    expect(find.text('Begin Now'), findsOneWidget);

    // Advance 3 seconds
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('7'), findsOneWidget);

    // Advance past preparation (7 more seconds)
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();

    // Now transitioned to regular practice screen
    expect(find.text('Quiet Settling Space'), findsOneWidget);
    expect(find.text('Phase 1: Settling'), findsOneWidget);
    expect(find.text('remaining'), findsOneWidget);
  });
}
