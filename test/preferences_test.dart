import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/data/bell_data.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/models/voice_config.dart';
import 'package:setandsit/screens/bell_configuration_screen.dart';
import 'package:setandsit/screens/manage_voices_screen.dart';
import 'package:setandsit/services/preferences_service.dart';
import 'package:setandsit/widgets/voice_stepper_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    PreferencesService.resetCache();
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('Save and load state in PreferencesService with practiceMode', () async {
    final state = SavedState(
      practiceDurationMinutes: 35,
      instructionDensity: 4.0,
      redirectionDensity: 2.0,
      preparationDelaySeconds: 15,
      practiceMode: 'Silent',
      bells: BellData.defaultBells,
      selectedBellId: 'bell_singing_bowl',
      selectedPractice: 'Open Awareness / Insight',
      selectedPracticeId: 'open_awareness',
      selectedVoiceIndex: 1,
      selectedVoiceId: 'grace',
      targetClockTimeHour: 9,
      targetClockTimeMinute: 35,
      targetClockTimeIsAm: true,
    );

    await PreferencesService.saveState(state);
    final loaded = await PreferencesService.loadState();

    expect(loaded.practiceDurationMinutes, 35);
    expect(loaded.instructionDensity, 4.0);
    expect(loaded.redirectionDensity, 2.0);
    expect(loaded.preparationDelaySeconds, 15);
    expect(loaded.practiceMode, 'Silent');
    expect(loaded.selectedBellId, 'bell_singing_bowl');
    expect(loaded.selectedPracticeId, 'open_awareness');
    expect(loaded.selectedVoiceId, 'grace');
  });

  testWidgets('Settings screen defaults are retained across app restart', (WidgetTester tester) async {
    // 1. First app launch
    await tester.pumpWidget(const SetAndSitApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap settings
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Defaults'), findsOneWidget);
    expect(find.text('Manage Bells'), findsOneWidget);

    final defaultsText = tester.widget<Text>(find.text('Defaults'));
    expect(defaultsText.style?.fontSize, 14);
    expect(defaultsText.style?.fontWeight, FontWeight.w600);

    // Edit duration: change 20 -> 35
    final durationFinder = find.widgetWithText(TextField, '20');
    expect(durationFinder, findsOneWidget);
    await tester.enterText(durationFinder, '35');
    await tester.pump(const Duration(milliseconds: 50));

    // Edit delay: change 10 -> 15
    final delayFinder = find.widgetWithText(TextField, '10');
    expect(delayFinder, findsOneWidget);
    await tester.enterText(delayFinder, '15');
    await tester.pump(const Duration(milliseconds: 50));

    // Tap Back
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 100));

    // 2. Simulate app close and cold launch
    final reloadedState = await PreferencesService.loadState();
    final reloadedVoices = await PreferencesService.loadVoices();
    final reloadedPractices = await PreferencesService.loadPractices();

    await tester.pumpWidget(SetAndSitApp(
      initialState: reloadedState,
      initialVoices: reloadedVoices,
      initialPractices: reloadedPractices,
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Reopen Settings
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify the defaults are retained: 35 min and 15 sec!
    expect(find.widgetWithText(TextField, '35'), findsOneWidget);
    expect(find.widgetWithText(TextField, '15'), findsOneWidget);
  });

  testWidgets('Front page selections (Practice, Voice, Bell, Silent/Guided) persist across restart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SetAndSitApp());
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Change Voice on Home screen to Grace
    final voiceNext = find.descendant(
      of: find.byType(VoiceStepperCard),
      matching: find.byIcon(Icons.chevron_right),
    );
    expect(voiceNext, findsOneWidget);
    await tester.tap(voiceNext);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Grace'), findsOneWidget);

    // 2. Change Bell on Home screen to next bell
    final bellCards = find.text('Meditation Bell');
    expect(bellCards, findsOneWidget);
    // Find next chevron on the Bell card
    final bellNextChevrons = find.byIcon(Icons.chevron_right);
    // Tap the chevron for the bell stepper (last one on screen)
    await tester.tap(bellNextChevrons.last);
    await tester.pump(const Duration(milliseconds: 50));

    // 3. Change Mode to Silent
    await tester.tap(find.text('Silent'));
    await tester.pump(const Duration(milliseconds: 50));

    // Check saved state
    final saved = await PreferencesService.loadState();
    expect(saved.practiceMode, 'Silent');
    expect(saved.selectedVoiceId, 'grace');

    // 4. Simulate cold launch
    final reloadedState = await PreferencesService.loadState();
    final reloadedVoices = await PreferencesService.loadVoices();
    final reloadedPractices = await PreferencesService.loadPractices();

    await tester.pumpWidget(SetAndSitApp(
      initialState: reloadedState,
      initialVoices: reloadedVoices,
      initialPractices: reloadedPractices,
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Silent mode is still active
    // When in Silent mode, Practice Card and Voice Card are hidden
    expect(find.byType(VoiceStepperCard), findsNothing);

    // Switch back to Guided to verify Voice is still Grace
    await tester.tap(find.text('Guided'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('Manage Bells screen has consistent layout with Manage Voices', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BellConfigurationScreen(
          bells: BellData.defaultBells,
          selectedBellId: 'bell_meditation',
          onBellSelected: (_) {},
          onBellUpdated: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Manage Bells'), findsOneWidget);

    // 1st: Stepper Pill with bell title
    expect(find.text('Select Bell to Configure'), findsOneWidget);
    expect(find.text('Meditation Bell'), findsNWidgets(2));

    // 2nd: "Include on Home Screen" Switch Container with subtitle
    expect(find.text('Include on Home Screen'), findsOneWidget);
    expect(find.text('Active in Home Screen Bell selector'), findsOneWidget);

    // 3rd: "Audition Bell" Button
    expect(find.text('Audition Bell'), findsOneWidget);
    expect(find.text('Test Bell Sound'), findsNothing);
    expect(find.text('Enable Bell'), findsNothing);

    // 4th: Bell Parameters
    expect(find.text('Bell Name'), findsOneWidget);
    expect(find.text('Duration (Seconds)'), findsOneWidget);
  });

  testWidgets('Manage Voices screen does not display Voice Profile & Management subtitle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ManageVoicesScreen(
          initialVoices: VoiceConfig.defaultVoices,
          initialSelectedVoiceId: 'kia',
          onVoicesUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage Voices'), findsOneWidget);
    expect(find.text('Voice Profile & Management'), findsNothing);
  });
}
