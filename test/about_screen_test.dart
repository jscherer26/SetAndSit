import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:setandsit/main.dart';
import 'package:setandsit/screens/about_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pref_clock_hour': 0,
      'pref_clock_minute': 0,
      'pref_clock_is_am': true,
      'pref_duration': 3,
      'pref_prep_delay': 3,
    });
    PackageInfo.setMockInitialValues(
      appName: 'Set&Sit',
      packageName: 'com.example.setandsit',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('AboutScreen renders app title, version, and pre-release badge', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: AboutScreen(onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About Set&Sit'), findsOneWidget);
    expect(find.text('Set&Sit'), findsOneWidget);
    expect(find.text('v0.1.0 (Build 1)'), findsOneWidget);
    expect(find.text('Pre-Release'), findsOneWidget);
  });

  testWidgets('AboutScreen renders mission statement and voice technology credits', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: AboutScreen(onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Trauma-sensitive practices designed to fit your unique timeframe.'),
      findsOneWidget,
    );
    expect(find.text('Voice Technology'), findsOneWidget);
    expect(
      find.text('Powered by ElevenLabs 11 v4 voice technology.'),
      findsOneWidget,
    );
  });

  testWidgets('AboutScreen renders Send Feedback and Open Source Licenses options', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: AboutScreen(onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send Feedback'), findsOneWidget);
    expect(
      find.text('Help us improve during pre-release by sharing your experience.'),
      findsOneWidget,
    );
    expect(find.text('Open Source Licenses'), findsOneWidget);
  });

  testWidgets('AboutScreen adapts seamlessly to dark mode theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AboutScreen(onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About Set&Sit'), findsOneWidget);
    expect(find.text('v0.1.0 (Build 1)'), findsOneWidget);
    expect(find.text('Pre-Release'), findsOneWidget);
  });

  testWidgets('Settings screen contains separate About Set&Sit tile and navigates to AboutScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SetAndSitApp());
    await tester.pumpAndSettle();

    // Tap settings gear icon on front screen
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);

    // Scroll to find the 'About Set&Sit' ListTile
    final aboutTileFinder = find.text('About Set&Sit');
    await tester.scrollUntilVisible(
      aboutTileFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(aboutTileFinder, findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    // Tap 'About Set&Sit'
    await tester.tap(aboutTileFinder);
    await tester.pumpAndSettle();

    // Verify on About screen
    expect(find.text('v0.1.0 (Build 1)'), findsOneWidget);
    expect(
      find.text('Trauma-sensitive practices designed to fit your unique timeframe.'),
      findsOneWidget,
    );

    // Tap back button on About screen
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Back on Settings screen
    expect(find.text('Settings'), findsOneWidget);
  });
}
