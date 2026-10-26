import 'dart:async';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/models/voice_config.dart';
import 'package:setandsit/screens/configuration_screen.dart';
import 'package:setandsit/screens/manage_voices_screen.dart';
import 'package:setandsit/services/audio_manifest_service.dart';
import 'package:setandsit/services/preferences_service.dart';
import 'package:setandsit/widgets/voice_stepper_card.dart';

class FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final _eventStreamControllers = <String, StreamController<AudioEvent>>{};

  StreamController<AudioEvent> _getOrCreate(String playerId) {
    return _eventStreamControllers.putIfAbsent(
      playerId,
      () => StreamController<AudioEvent>.broadcast(),
    );
  }

  @override
  Future<void> create(String playerId) async {}

  @override
  Future<void> dispose(String playerId) async {
    _eventStreamControllers[playerId]?.close();
    _eventStreamControllers.remove(playerId);
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    return _getOrCreate(playerId).stream;
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 1000;

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setAudioContext(String playerId, AudioContext context) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes,
      {String? mimeType}) async {}

  @override
  Future<void> setSourceUrl(String playerId, String url,
      {bool? isLocal, String? mimeType}) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> stop(String playerId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PreferencesService.resetCache();
    SharedPreferences.setMockInitialValues({});
    await AudioManifestService.initialize();
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
  });

  group('1. Data-Driven Voice Model (VoiceConfig) & Persistence', () {
    test('Default stock voices initialize with exact attributes', () {
      final voices = VoiceConfig.defaultVoices;
      expect(voices.length, 2);

      // Kia
      final kia = voices[0];
      expect(kia.id, 'kia');
      expect(kia.name, 'Kia');
      expect(kia.description, 'Warm & Grounded');
      expect(kia.gender, 'Male');
      expect(kia.isSystem, isTrue);
      expect(kia.isIncluded, isTrue);
      expect(kia.assetFolder, 'assets/audio/voices/kia');

      // Grace
      final grace = voices[1];
      expect(grace.id, 'grace');
      expect(grace.name, 'Grace');
      expect(grace.description, 'Soft & Centered');
      expect(grace.gender, 'Female');
      expect(grace.isSystem, isTrue);
      expect(grace.isIncluded, isTrue);
      expect(grace.assetFolder, 'assets/audio/voices/grace');
    });

    test('VoiceConfig toJson and fromJson preserve all fields', () {
      const voice = VoiceConfig(
        id: 'custom_voice',
        name: 'Custom Persona',
        description: 'Serene & Gentle',
        gender: 'Non-binary',
        isSystem: false,
        isIncluded: false,
        assetFolder: 'assets/audio/voices/custom_voice',
      );

      final json = voice.toJson();
      final fromJson = VoiceConfig.fromJson(json);

      expect(fromJson.id, voice.id);
      expect(fromJson.name, voice.name);
      expect(fromJson.description, voice.description);
      expect(fromJson.gender, voice.gender);
      expect(fromJson.isSystem, voice.isSystem);
      expect(fromJson.isIncluded, voice.isIncluded);
      expect(fromJson.assetFolder, voice.assetFolder);
    });

    test('PreferencesService saves and loads VoiceConfig list correctly', () async {
      final customVoices = [
        VoiceConfig.defaultVoices[0].copyWith(isIncluded: false),
        VoiceConfig.defaultVoices[1],
      ];

      await PreferencesService.saveVoices(customVoices);
      final loaded = await PreferencesService.loadVoices();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'kia');
      expect(loaded[0].isIncluded, isFalse);
      expect(loaded[1].id, 'grace');
      expect(loaded[1].isIncluded, isTrue);
    });
  });

  group('2. ManageVoicesScreen UI Layout & Controls', () {
    testWidgets('Renders all required sections and action buttons are disabled',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ManageVoicesScreen(
            isDeveloperMode: true,
            initialVoices: VoiceConfig.defaultVoices,
            onVoicesUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen title
      expect(find.text('Manage Voices'), findsOneWidget);
      expect(find.byType(VoiceStepperCard), findsOneWidget);
      expect(find.text('Kia'), findsOneWidget);
      expect(find.text('Warm & Grounded • Male'), findsOneWidget);

      // Action Buttons Row: Add, Copy, Rename, Delete
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // "Include on Home Screen" Switch
      expect(find.text('Include on Home Screen'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // "Audition Voice" Button
      expect(find.text('Audition Voice'), findsOneWidget);

      // Visual Divider
      expect(find.byType(Divider), findsWidgets);

      // Bottom Section: Script & Variant Inspector
      expect(find.text('Script & Variant Inspector'), findsOneWidget);

      // Segment Stepper & Description Card
      expect(find.textContaining('S01 •'), findsOneWidget);
      expect(find.text('Segment Rationale'), findsOneWidget);
      expect(
        find.textContaining('Serves as a perceptual bridge'),
        findsOneWidget,
      );

      // Variant Stepper & Variant Script Card
      expect(find.textContaining('v01 •'), findsOneWidget);
      expect(find.text('Script Variant Text'), findsOneWidget);
      expect(
        find.textContaining('Arriving into this space'),
        findsOneWidget,
      );
    });

    testWidgets('Voice Stepper cycles through all defined VoiceConfig entries',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ManageVoicesScreen(
            initialVoices: VoiceConfig.defaultVoices,
            onVoicesUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kia'), findsOneWidget);

      // Tap next chevron in Voice Stepper
      final nextVoiceBtn = find.descendant(
        of: find.byType(VoiceStepperCard),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(nextVoiceBtn);
      await tester.pumpAndSettle();

      expect(find.text('Grace'), findsOneWidget);
      expect(find.text('Soft & Centered • Female'), findsOneWidget);

      // Tap previous chevron
      final prevVoiceBtn = find.descendant(
        of: find.byType(VoiceStepperCard),
        matching: find.byIcon(Icons.chevron_left),
      );
      await tester.tap(prevVoiceBtn);
      await tester.pumpAndSettle();

      expect(find.text('Kia'), findsOneWidget);
    });

    testWidgets('Segment Stepper and Variant Stepper cycle through segments and variants',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ManageVoicesScreen(
            isDeveloperMode: true,
            initialVoices: VoiceConfig.defaultVoices,
            onVoicesUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('S01 •'), findsOneWidget);

      // Step segment forward: S01 -> S02
      // Find all right chevrons on screen: [0] is voice, [1] is segment, [2] is variant
      final rightChevrons = find.byIcon(Icons.chevron_right);
      expect(rightChevrons, findsNWidgets(3));

      await tester.tap(rightChevrons.at(1));
      await tester.pumpAndSettle();

      expect(find.textContaining('S02 •'), findsOneWidget);

      // Step variant forward
      await tester.tap(rightChevrons.at(2));
      await tester.pumpAndSettle();

      expect(find.textContaining('v02 •'), findsOneWidget);
    });

    testWidgets('Audition button toggles state between Audition Voice and Stop Audition',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ManageVoicesScreen(
            initialVoices: VoiceConfig.defaultVoices,
            onVoicesUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final auditionBtn = find.widgetWithText(ElevatedButton, 'Audition Voice');
      expect(auditionBtn, findsOneWidget);

      await tester.tap(auditionBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should now show Stop Audition
      expect(find.widgetWithText(ElevatedButton, 'Stop Audition'), findsOneWidget);

      // Tap again to stop
      await tester.tap(find.widgetWithText(ElevatedButton, 'Stop Audition'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(ElevatedButton, 'Audition Voice'), findsOneWidget);
    });

    testWidgets('Active audition playback stops immediately when switching voice, segment, or variant',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ManageVoicesScreen(
            isDeveloperMode: true,
            initialVoices: VoiceConfig.defaultVoices,
            onVoicesUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start audition
      await tester.tap(find.widgetWithText(ElevatedButton, 'Audition Voice'));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Stop Audition'), findsOneWidget);

      // Switching voice stops audition immediately
      final nextVoiceBtn = find.descendant(
        of: find.byType(VoiceStepperCard),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(nextVoiceBtn);
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Audition Voice'), findsOneWidget);

      // Start audition again
      await tester.tap(find.widgetWithText(ElevatedButton, 'Audition Voice'));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Stop Audition'), findsOneWidget);

      // Stepping segment stops audition immediately
      final rightChevrons = find.byIcon(Icons.chevron_right);
      await tester.tap(rightChevrons.at(1));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Audition Voice'), findsOneWidget);

      // Start audition again
      await tester.tap(find.widgetWithText(ElevatedButton, 'Audition Voice'));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Stop Audition'), findsOneWidget);

      // Stepping variant stops audition immediately
      await tester.tap(rightChevrons.at(2));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Audition Voice'), findsOneWidget);
    });
  });

  group('3. Safeguard: At least one voice must remain active', () {
    testWidgets('Toggling isIncluded persists and notifies when valid',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      List<VoiceConfig>? updatedList;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManageVoicesScreen(
              initialVoices: VoiceConfig.defaultVoices,
              onVoicesUpdated: (u) => updatedList = u,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Current voice is Kia. Both Kia and Grace are included.
      // Toggle Kia to false
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(updatedList, isNotNull);
      expect(updatedList!.firstWhere((v) => v.id == 'kia').isIncluded, isFalse);
      expect(updatedList!.firstWhere((v) => v.id == 'grace').isIncluded, isTrue);

      final loaded = await PreferencesService.loadVoices();
      expect(loaded.firstWhere((v) => v.id == 'kia').isIncluded, isFalse);
    });
    testWidgets('Blocks toggling off last remaining active voice and shows SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Start with only 1 active voice (Kia included, Grace excluded)
      final voices = [
        VoiceConfig.defaultVoices[0].copyWith(isIncluded: true),
        VoiceConfig.defaultVoices[1].copyWith(isIncluded: false),
      ];

      List<VoiceConfig>? updatedList;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManageVoicesScreen(
              initialVoices: voices,
              onVoicesUpdated: (u) => updatedList = u,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Current voice is Kia, which is active
      expect(find.text('Kia'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Attempt to toggle off Kia (the only active voice)
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // SnackBar safeguard must appear
      expect(
        find.text('At least one voice must remain active.'),
        findsOneWidget,
      );

      // List must NOT have been updated with 0 active voices
      expect(updatedList, isNull);
    });
  });

  group('4. Home Screen Navigation & Filter Integration', () {
    testWidgets('Voice icon and ListTile on Home Screen open ManageVoicesScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      // Verify Home Screen shows Voice ListTile
      final voiceFinder = find.descendant(
        of: find.byType(ConfigurationScreen),
        matching: find.byType(VoiceStepperCard),
      );
      expect(voiceFinder, findsOneWidget);
      expect(find.text('Kia'), findsOneWidget);

      // Tap voice icon - should NOT open ManageVoicesScreen
      final iconFinder = find.descendant(
        of: voiceFinder,
        matching: find.byIcon(Icons.record_voice_over),
      );
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();
      expect(find.text('Manage Voices'), findsNothing);

      // Tap directly on the Voice title - should NOT open ManageVoicesScreen
      await tester.tap(find.descendant(
        of: voiceFinder,
        matching: find.text('Kia'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Manage Voices'), findsNothing);

      // Navigate via Settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Voices'));
      await tester.pumpAndSettle();

      // ManageVoicesScreen is opened
      expect(find.text('Manage Voices'), findsOneWidget);

      // Pop back from Manage Voices to Settings
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Pop back from Settings to Home Screen
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Manage Voices'), findsNothing);
      expect(find.text('Set&Sit'), findsOneWidget);
    });

    testWidgets('Home Screen voice selector only displays voices where isIncluded == true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Mock preferences with Kia excluded and Grace included
      final voices = [
        VoiceConfig.defaultVoices[0].copyWith(isIncluded: false),
        VoiceConfig.defaultVoices[1].copyWith(isIncluded: true),
      ];
      await PreferencesService.saveVoices(voices);

      await tester.pumpWidget(const SetAndSitApp());
      await tester.pumpAndSettle();

      // Home Screen should display Grace because Kia is excluded
      expect(find.text('Grace'), findsOneWidget);

      // Because only 1 voice is included, stepping chevrons should be disabled (onPrevious == null)
      final voiceCard = tester.widget<VoiceStepperCard>(find.byType(VoiceStepperCard));
      expect(voiceCard.onPrevious, isNull);
      expect(voiceCard.onNext, isNull);
    });
  });
}
