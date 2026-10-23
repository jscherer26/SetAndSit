import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:setandsit/data/bell_data.dart';
import 'package:setandsit/engine/session_queue_engine.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/models/practice_config.dart';
import 'package:setandsit/screens/manage_practices_screen.dart';
import 'package:setandsit/services/audio_manifest_service.dart';
import 'package:setandsit/services/preferences_service.dart';
import 'package:setandsit/widgets/practice_stepper_card.dart';
import 'package:setandsit/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PreferencesService.resetCache();
    SharedPreferences.setMockInitialValues({});
    await AudioManifestService.initialize();
  });

  group('1. Unified PracticeConfig Data Model & Persistence', () {
    test('Default 4 System Practices match exact specifications', () {
      final practices = PracticeConfig.defaultPractices;
      expect(practices.length, 4);

      // 1. Focused Calm
      final fc = practices[0];
      expect(fc.id, 'focused_calm');
      expect(fc.name, 'Focused Calm');
      expect(
        fc.subtitle,
        'Attentional stability, cognitive decelerating, interoceptive grounding.',
      );
      expect(fc.isSystem, isTrue);
      expect(fc.isIncluded, isTrue);
      expect(fc.segmentIds, [
        'S01', 'S02', 'S03', 'S04', 'S06', 'S07', 'S08', 'S12', 'S13', 'S15', 'S16',
      ]);

      // 2. Trauma-Informed Regulation
      final ti = practices[1];
      expect(ti.id, 'trauma_informed');
      expect(ti.name, 'Trauma-Informed Regulation');
      expect(
        ti.subtitle,
        'High agency, down-regulation, safety anchoring, bypasses forced breathwork.',
      );
      expect(ti.isSystem, isTrue);
      expect(ti.isIncluded, isTrue);
      expect(ti.segmentIds, [
        'S01', 'S02', 'S04', 'S05', 'S07', 'S08', 'S10', 'S12', 'S13', 'S14', 'S15', 'S16',
      ]);

      // 3. Open Awareness / Insight
      final oa = practices[2];
      expect(oa.id, 'open_awareness');
      expect(oa.name, 'Open Awareness / Insight');
      expect(
        oa.subtitle,
        'Decentering, metacognition, cognitive defusion, spacious perspective.',
      );
      expect(oa.isSystem, isTrue);
      expect(oa.isIncluded, isTrue);
      expect(oa.segmentIds, [
        'S01', 'S02', 'S03', 'S04', 'S08', 'S09', 'S10', 'S12', 'S13', 'S15', 'S16',
      ]);

      // 4. Metta / Compassion
      final mc = practices[3];
      expect(mc.id, 'metta_compassion');
      expect(mc.name, 'Metta / Compassion');
      expect(
        mc.subtitle,
        'Ventral vagal activation, pro-social warmth, inner critic reduction.',
      );
      expect(mc.isSystem, isTrue);
      expect(mc.isIncluded, isTrue);
      expect(mc.segmentIds, [
        'S01', 'S02', 'S03', 'S04', 'S07', 'S11', 'S12', 'S13', 'S14', 'S15', 'S16',
      ]);
    });

    test('segmentIds are always stored sorted chronologically from S01 to S16', () {
      final config = PracticeConfig(
        id: 'test_custom',
        name: 'Custom',
        subtitle: 'Test',
        segmentIds: ['S16', 'S03', 'S01', 'S12', 'S08'],
      );

      expect(config.segmentIds, ['S01', 'S03', 'S08', 'S12', 'S16']);
    });

    test('PracticeConfig toJson and fromJson roundtrip correctly', () {
      final original = PracticeConfig(
        id: 'custom_123',
        name: 'My Custom Practice',
        subtitle: 'Calm intention',
        isSystem: false,
        isIncluded: true,
        segmentIds: ['S01', 'S02', 'S03', 'S08', 'S12', 'S13', 'S15', 'S16'],
      );

      final json = original.toJson();
      final parsed = PracticeConfig.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.name, original.name);
      expect(parsed.subtitle, original.subtitle);
      expect(parsed.isSystem, original.isSystem);
      expect(parsed.isIncluded, original.isIncluded);
      expect(parsed.segmentIds, original.segmentIds);
    });

    test('PreferencesService persists and loads custom practices and included toggles', () async {
      final list = [
        ...PracticeConfig.defaultPractices,
        PracticeConfig(
          id: 'custom_test_1',
          name: 'Custom Practice 1',
          subtitle: 'Subtitle 1',
          isSystem: false,
          isIncluded: false,
          segmentIds: ['S01', 'S02', 'S03', 'S12', 'S15', 'S16'],
        ),
      ];

      await PreferencesService.savePractices(list);
      final loaded = await PreferencesService.loadPractices();

      expect(loaded.length, 5);
      expect(loaded.last.id, 'custom_test_1');
      expect(loaded.last.name, 'Custom Practice 1');
      expect(loaded.last.isIncluded, isFalse);
    });
  });

  group('2. SessionQueueEngine with PracticeConfig', () {
    test('generateGuidedSessionQueue generates queue with custom PracticeConfig', () {
      final customPractice = PracticeConfig(
        id: 'custom_test',
        name: 'Custom Practice',
        subtitle: 'Test',
        isSystem: false,
        isIncluded: true,
        segmentIds: ['S01', 'S02', 'S04', 'S08', 'S12', 'S13', 'S15', 'S16'],
      );

      final bell = BellData.defaultBells.first;
      final queue = SessionQueueEngine.generateGuidedSessionQueue(
        targetDurationSeconds: 600,
        practice: customPractice,
        voicePersona: 'kia',
        selectedBell: bell,
      );

      expect(queue.isNotEmpty, isTrue);
      // All mandatory segments present
      final playAudioItems = queue.whereType<PlayAudioItem>().toList();
      final segmentCodes = playAudioItems.map((e) => e.segment?.code).whereType<String>().toList();

      expect(segmentCodes.contains('S01'), isTrue);
      expect(segmentCodes.contains('S02'), isTrue);
      expect(segmentCodes.contains('S12'), isTrue);
      expect(segmentCodes.contains('S15'), isTrue);
      expect(segmentCodes.contains('S16'), isTrue);
    });
  });

  group('3. ManagePracticesScreen UI & Controls', () {
    testWidgets('Top Filter Radio toggles between All, System, and Custom', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ManagePracticesScreen(
            initialPractices: PracticeConfig.defaultPractices,
            onPracticesUpdated: (_) {},
          ),
        ),
      );

      expect(find.text('Manage Practices'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('System'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);

      // Initially 'Focused Calm' is selected
      expect(find.text('Focused Calm'), findsWidgets);

      // Tap 'Custom' filter - no custom practices exist yet, shows empty state
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.text('No Custom Practices Yet'), findsOneWidget);

      // Tap 'System' filter
      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();

      expect(find.text('Focused Calm'), findsWidgets);
    });

    testWidgets('Practice Stepper < and > cycles practices', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ManagePracticesScreen(
            initialPractices: PracticeConfig.defaultPractices,
            onPracticesUpdated: (_) {},
          ),
        ),
      );

      expect(find.text('Focused Calm'), findsWidgets);

      // Tap next chevron
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();

      // Second practice is Trauma-Informed Regulation
      expect(find.text('Trauma-Informed Regulation'), findsWidgets);

      // Tap previous chevron
      await tester.tap(find.byIcon(Icons.chevron_left).first);
      await tester.pumpAndSettle();

      expect(find.text('Focused Calm'), findsWidgets);
    });

    testWidgets('Safeguard: Cannot toggle off the last remaining included practice', (WidgetTester tester) async {
      final practices = [
        PracticeConfig.defaultPractices[0].copyWith(isIncluded: true),
        PracticeConfig.defaultPractices[1].copyWith(isIncluded: false),
        PracticeConfig.defaultPractices[2].copyWith(isIncluded: false),
        PracticeConfig.defaultPractices[3].copyWith(isIncluded: false),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: practices,
              initialSelectedPracticeId: 'focused_calm',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // Attempt to toggle off the only included practice
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Safeguard SnackBar must be displayed
      expect(
        find.text('At least one practice must remain included on the Home Screen.'),
        findsOneWidget,
      );
    });

    testWidgets('Add Custom Practice creates custom practice with default 8 segments', (WidgetTester tester) async {
      List<PracticeConfig>? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: PracticeConfig.defaultPractices,
              onPracticesUpdated: (list) {
                updated = list;
              },
            ),
          ),
        ),
      );

      // Tap 'Add' action button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Practice'), findsOneWidget);

      // Enter name in dialog
      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
        'Evening Wind-Down',
      );
      await tester.pumpAndSettle();

      // Tap 'Create'
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.length, 5);

      final newCustom = updated!.last;
      expect(newCustom.name, 'Evening Wind-Down');
      expect(newCustom.isSystem, isFalse);
      expect(newCustom.isIncluded, isTrue);
      expect(newCustom.segmentIds, [
        'S01', 'S02', 'S03', 'S08', 'S12', 'S13', 'S15', 'S16',
      ]);
    });

    testWidgets('Copy Practice clones currently viewed practice', (WidgetTester tester) async {
      List<PracticeConfig>? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: PracticeConfig.defaultPractices,
              initialSelectedPracticeId: 'focused_calm',
              onPracticesUpdated: (list) {
                updated = list;
              },
            ),
          ),
        ),
      );

      // Tap 'Copy'
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Practice'), findsOneWidget);
      expect(find.text('Focused Calm (Copy)'), findsOneWidget);

      // Tap 'Copy' in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Copy'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.length, 5);

      final copied = updated!.last;
      expect(copied.name, 'Focused Calm (Copy)');
      expect(copied.isSystem, isFalse);
      expect(copied.segmentIds, PracticeConfig.defaultPractices.first.segmentIds);
    });

    testWidgets('Rename and Delete action buttons disabled for System practices', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: PracticeConfig.defaultPractices,
              initialSelectedPracticeId: 'focused_calm',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // Tap 'Rename' when viewing a System practice -> Dialog should NOT open
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Practice'), findsNothing);

      // Tap 'Delete' when viewing a System practice -> Dialog should NOT open
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Practice'), findsNothing);
    });

    testWidgets('Mandatory segments S01, S02, S12, S15, S16 cannot be unchecked and required bubbles are dropped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: PracticeConfig.defaultPractices,
              initialSelectedPracticeId: 'focused_calm',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // Required bubbles are dropped for clean UI
      expect(find.text('Required'), findsNothing);

      // Verify S01 checkbox is checked and disabled (onChanged is null)
      final s01Finder = find.textContaining('S01 • External Arrival');
      expect(s01Finder, findsOneWidget);
      final s01Checkbox = tester.widget<Checkbox>(
        find.descendant(
          of: find.ancestor(of: s01Finder, matching: find.byType(Row)),
          matching: find.byType(Checkbox),
        ),
      );
      expect(s01Checkbox.value, isTrue);
      expect(s01Checkbox.onChanged, isNull);
    });

    testWidgets('Name uniqueness safeguard prevents duplicate practice names on Add, Copy, and Rename', (WidgetTester tester) async {
      final customPractice = PracticeConfig(
        id: 'custom_1',
        name: 'My Practice',
        subtitle: 'Test',
        isSystem: false,
        isIncluded: true,
        segmentIds: ['S01', 'S02', 'S03', 'S08', 'S12', 'S13', 'S15', 'S16'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: [...PracticeConfig.defaultPractices, customPractice],
              initialSelectedPracticeId: 'custom_1',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // 1. Try to Add with existing name 'Focused Calm' (System practice)
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
        'focused calm',
      ); // Case-insensitive
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('A practice with this name already exists'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 2. Try to Rename to existing name 'Metta / Compassion'
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
        'Metta / Compassion',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('A practice with this name already exists'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Practice Name is color-coded System blue and Custom green on Manage Practices screen', (WidgetTester tester) async {
      final customPractice = PracticeConfig(
        id: 'custom_1',
        name: 'Custom Calm',
        subtitle: 'Test',
        isSystem: false,
        isIncluded: true,
        segmentIds: ['S01', 'S02', 'S03', 'S08', 'S12', 'S13', 'S15', 'S16'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: [...PracticeConfig.defaultPractices, customPractice],
              initialSelectedPracticeId: 'focused_calm',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // System practice name must be styled with systemBlue
      final fcText = tester.widget<Text>(find.text('Focused Calm'));
      expect(fcText.style?.color, const Color(0xFF1565C0)); // AppColors.systemBlue

      // Switch to Custom filter
      await tester.tap(find.text('Custom').first);
      await tester.pumpAndSettle();

      // Custom practice name must be styled with customGreen
      final customText = tester.widget<Text>(find.text('Custom Calm'));
      expect(customText.style?.color, const Color(0xFF2E7D32)); // AppColors.customGreen
    });

    testWidgets('Editable subtitle text field allows editing and persisting custom practice subtitle', (WidgetTester tester) async {
      List<PracticeConfig>? updated;
      final customPractice = PracticeConfig(
        id: 'custom_1',
        name: 'Custom Calm',
        subtitle: 'Initial Subtitle',
        isSystem: false,
        isIncluded: true,
        segmentIds: ['S01', 'S02', 'S03', 'S08', 'S12', 'S13', 'S15', 'S16'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: [customPractice],
              initialSelectedPracticeId: 'custom_1',
              onPracticesUpdated: (list) {
                updated = list;
              },
            ),
          ),
        ),
      );

      // Find the subtitle TextField
      final subtitleField = find.widgetWithText(TextField, 'Initial Subtitle');
      expect(subtitleField, findsOneWidget);

      // Edit the subtitle
      await tester.enterText(subtitleField, 'Brand New Clinical Intention');
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.first.subtitle, 'Brand New Clinical Intention');
    });

    testWidgets('Safeguard: Custom practice must retain at least one segment between S03 and S11', (WidgetTester tester) async {
      final customPractice = PracticeConfig(
        id: 'custom_minimal',
        name: 'Minimal Practice',
        subtitle: 'Minimal',
        isSystem: false,
        isIncluded: true,
        // Only one segment in S03-S11: 'S03'
        segmentIds: ['S01', 'S02', 'S03', 'S12', 'S15', 'S16'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: [customPractice],
              initialSelectedPracticeId: 'custom_minimal',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // Find the checkbox for S03
      final s03RowFinder = find.textContaining('S03 • Natural Breath Flow');
      expect(s03RowFinder, findsOneWidget);

      // Tap on S03 row checkbox
      final s03Checkbox = find.descendant(
        of: find.ancestor(of: s03RowFinder, matching: find.byType(Row)),
        matching: find.byType(Checkbox),
      );
      expect(s03Checkbox, findsOneWidget);

      await tester.ensureVisible(s03Checkbox);
      await tester.tap(s03Checkbox);
      await tester.pumpAndSettle();

      // SnackBar safeguard must trigger
      expect(
        find.text('A practice must include at least one settling or core segment (S03–S11).'),
        findsOneWidget,
      );
    });

    testWidgets('Segment Detail Modal displays phase, code, title, rationale, and example script', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: PracticeConfig.defaultPractices,
              initialSelectedPracticeId: 'focused_calm',
              onPracticesUpdated: (_) {},
            ),
          ),
        ),
      );

      // Tap on S01 row to open detail modal
      await tester.tap(find.textContaining('S01 • External Arrival'));
      await tester.pumpAndSettle();

      expect(find.text('Phase 1: Arrival, Agency & Safety Setup'), findsWidgets);
      expect(find.text('S01 • External Arrival'), findsWidgets);
      expect(find.text('Clinical Rationale & Function'), findsOneWidget);
      expect(find.text('Example Guidance Script'), findsOneWidget);
      expect(
        find.textContaining('Serves as a perceptual bridge from daily tasks'),
        findsOneWidget,
      );
      expect(
        find.textContaining('fade into the background'),
        findsOneWidget,
      );
    });
  });

  group('4. Home Screen Integration', () {
    testWidgets('Home Screen Practice Stepper only cycles through isIncluded practices', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Exclude Trauma-Informed and Metta
      final practices = [
        PracticeConfig.defaultPractices[0].copyWith(isIncluded: true),  // Focused Calm
        PracticeConfig.defaultPractices[1].copyWith(isIncluded: false), // Trauma-Informed (excluded)
        PracticeConfig.defaultPractices[2].copyWith(isIncluded: true),  // Open Awareness
        PracticeConfig.defaultPractices[3].copyWith(isIncluded: false), // Metta (excluded)
      ];

      await PreferencesService.savePractices(practices);

      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      // Home Screen shows Focused Calm
      expect(find.text('Focused Calm'), findsWidgets);

      // Tap next chevron on Practice Card
      final nextChevron = find.descendant(
        of: find.byType(PracticeStepperCard),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(nextChevron);
      await tester.pumpAndSettle();

      // Should skip Trauma-Informed and jump straight to Open Awareness
      expect(find.text('Open Awareness / Insight'), findsWidgets);
      expect(find.text('Trauma-Informed Regulation'), findsNothing);

      // Tap next again -> Should cycle back to Focused Calm
      await tester.tap(nextChevron);
      await tester.pumpAndSettle();

      expect(find.text('Focused Calm'), findsWidgets);
    });

    testWidgets('Rename and Delete custom practice works and auto-enables Focused Calm if last included', (WidgetTester tester) async {
      final customPractice = PracticeConfig(
        id: 'custom_only_inc',
        name: 'My Special Practice',
        subtitle: 'Special',
        isSystem: false,
        isIncluded: true,
        segmentIds: ['S01', 'S02', 'S03', 'S08', 'S12', 'S13', 'S15', 'S16'],
      );

      final practices = [
        PracticeConfig.defaultPractices[0].copyWith(isIncluded: false),
        PracticeConfig.defaultPractices[1].copyWith(isIncluded: false),
        PracticeConfig.defaultPractices[2].copyWith(isIncluded: false),
        PracticeConfig.defaultPractices[3].copyWith(isIncluded: false),
        customPractice,
      ];

      List<PracticeConfig>? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagePracticesScreen(
              initialPractices: practices,
              initialSelectedPracticeId: 'custom_only_inc',
              onPracticesUpdated: (list) {
                updated = list;
              },
            ),
          ),
        ),
      );

      // Rename
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Practice'), findsOneWidget);
      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
        'My Renamed Practice',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.last.name, 'My Renamed Practice');

      // Delete the only included practice
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Practice'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Safeguard: Focused Calm must be auto-enabled
      final fc = updated!.firstWhere((p) => p.id == 'focused_calm');
      expect(fc.isIncluded, isTrue);
    });

    testWidgets('Tapping meditator icon opens ManagePracticesScreen (matching bell behavior)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      // Tap meditator icon on the Practice Stepper Card
      final meditatorIcon = find.descendant(
        of: find.byType(PracticeStepperCard),
        matching: find.byIcon(Icons.self_improvement),
      );
      expect(meditatorIcon, findsOneWidget);

      await tester.tap(meditatorIcon);
      await tester.pumpAndSettle();

      // ManagePracticesScreen is opened
      expect(find.text('Clinical Arc Segments'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Returns to Home Screen
      expect(find.text('Adaptive Guided Meditation'), findsOneWidget);
    });

    testWidgets('Settings Page contains entry points to Manage Practices and Manage Bells', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      // Tap Settings gear icon in header
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Settings screen is open
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Manage Practices'), findsOneWidget);
      expect(find.text('Manage Bells'), findsOneWidget);

      // Tap 'Manage Practices' from Settings
      await tester.tap(find.text('Manage Practices'));
      await tester.pumpAndSettle();

      expect(find.text('Clinical Arc Segments'), findsOneWidget);

      // Tap back -> returns to Settings!
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      // Tap 'Manage Bells' from Settings
      await tester.tap(find.text('Manage Bells'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Bells'), findsWidgets);

      // Tap back -> returns to Settings!
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Home Screen updates immediately when selected practice is excluded in Manage Practices', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      expect(find.text('Focused Calm'), findsWidgets);

      // Tap meditator icon on the Practice Stepper Card
      final meditatorIcon = find.descendant(
        of: find.byType(PracticeStepperCard),
        matching: find.byIcon(Icons.self_improvement),
      );
      await tester.tap(meditatorIcon);
      await tester.pumpAndSettle();

      // Toggle off 'Focused Calm'
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Home Screen should immediately switch to Trauma-Informed Regulation (the next included practice)
      expect(find.text('Trauma-Informed Regulation'), findsWidgets);
    });
  });
}
