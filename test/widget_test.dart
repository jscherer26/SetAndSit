import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/screens/clock_time_picker_dialog.dart';
import 'package:setandsit/screens/practice_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pref_clock_hour': 0,
      'pref_clock_minute': 0,
      'pref_clock_is_am': true,
      'pref_duration': 3,
      'pref_prep_delay': 3,
    });
  });

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

  testWidgets('Changing practice duration in Settings updates the finish time and duration on the front screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SetAndSitApp());
    await tester.pumpAndSettle();

    // Initially front screen shows default 3 min practice
    expect(find.text('3 min practice'), findsOneWidget);

    // Tap settings gear icon
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);

    // Find TextField for duration and change to 35
    final durationTextField = find.byType(TextField).first;
    await tester.enterText(durationTextField, '35');
    await tester.pumpAndSettle();

    // Tap back button in Settings
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Front screen should now show 35 min practice and updated finish time
    expect(find.text('35 min practice'), findsOneWidget);
  });

  testWidgets('PracticeScreen lifecycle resume after expiration finishes session immediately',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final silenceItem = PauseSilenceItem(
      10,
      displayTitle: 'Quiet Space',
      phaseName: 'Phase 1: Settling',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          isDeveloperMode: true,
          sessionQueue: [silenceItem],
          targetDurationSeconds: 10,
          preparationDelaySeconds: 0,
          selectedMeditationType: 'Focused Calm',
          buildDebugScreen: () => const SizedBox.shrink(),
          onEndSession: () {},
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Sit Complete'), findsNothing);

    // Simulate 15 seconds passing while app is in background
    await tester.pump(const Duration(seconds: 15));

    // Simulate app going inactive (switching apps) and then resuming
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Should immediately display finished state
    expect(find.text('Sit Complete'), findsOneWidget);
    expect(find.text('End of Formal Practice'), findsOneWidget);
  });
}
