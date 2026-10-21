import 'package:flutter/material.dart';
import 'data/bell_data.dart';
import 'engine/session_queue_engine.dart';
import 'models/audio_models.dart';
import 'screens/bell_configuration_screen.dart';
import 'screens/configuration_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/session_debug_screen.dart';
import 'screens/settings_screen.dart';
import 'services/audio_manifest_service.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SetAndSitApp());
}

class SetAndSitApp extends StatelessWidget {
  const SetAndSitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Set&Sit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.darkOlive,
          primary: AppColors.darkOlive,
        ),
        useMaterial3: true,
      ),
      home: const RootControllerScreen(),
    );
  }
}

enum AppScreen {
  configuration,
  settings,
  bellSettings,
  practice,
  sessionDebug,
}

class RootControllerScreen extends StatefulWidget {
  const RootControllerScreen({super.key});

  @override
  State<RootControllerScreen> createState() => _RootControllerScreenState();
}

class _RootControllerScreenState extends State<RootControllerScreen>
    with WidgetsBindingObserver {
  AppScreen _currentScreen = AppScreen.configuration;

  int _practiceDurationMinutes = 20;
  double _instructionDensity = 3.0;
  double _redirectionDensity = 3.0;

  List<AudioSegment> _bells = BellData.defaultBells;
  String _selectedBellId = 'bell_meditation';

  String _selectedPractice = ClinicalArchetype.focusedCalm.title;
  int _voiceIndex = 0; // 0: Kia (Male), 1: Grace (Female)

  int _clockHour = 8;
  int _clockMinute = 20;
  bool _isAm = true;

  List<SessionItem> _activeSessionQueue = [];
  int _activeTargetSeconds = 1200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureFutureTargetTime();
    }
  }

  void _loadInitialState() async {
    await AudioManifestService.initialize();
    final saved = await PreferencesService.loadState();

    if (mounted) {
      final now = DateTime.now();
      final initialEnd =
          now.add(Duration(minutes: saved.practiceDurationMinutes));
      final initHour = initialEnd.hour % 12 == 0 ? 12 : initialEnd.hour % 12;
      final initMinute = initialEnd.minute;
      final initIsAm = initialEnd.hour < 12;

      // Migrate legacy string if needed
      var practice = saved.selectedPractice;
      if (practice == 'Breath' || practice == 'Breath Awareness' || practice == 'Guided') {
        practice = ClinicalArchetype.focusedCalm.title;
      }

      setState(() {
        _practiceDurationMinutes = saved.practiceDurationMinutes;
        _instructionDensity = saved.instructionDensity;
        _redirectionDensity = saved.redirectionDensity;
        _bells = saved.bells;
        _selectedBellId = saved.selectedBellId;
        _selectedPractice = practice;
        _voiceIndex = saved.selectedVoiceIndex;
        _clockHour = initHour;
        _clockMinute = initMinute;
        _isAm = initIsAm;
      });
    }
  }

  void _ensureFutureTargetTime() {
    final now = DateTime.now();
    final hour24 = _isAm
        ? (_clockHour == 12 ? 0 : _clockHour)
        : (_clockHour == 12 ? 12 : _clockHour + 12);
    final target =
        DateTime(now.year, now.month, now.day, hour24, _clockMinute);
    if (!target.isAfter(now)) {
      final newTarget = now.add(Duration(minutes: _practiceDurationMinutes));
      setState(() {
        _clockHour = newTarget.hour % 12 == 0 ? 12 : newTarget.hour % 12;
        _clockMinute = newTarget.minute;
        _isAm = newTarget.hour < 12;
      });
      _persistState();
    }
  }

  void _persistState() {
    PreferencesService.saveState(
      SavedState(
        practiceDurationMinutes: _practiceDurationMinutes,
        instructionDensity: _instructionDensity,
        redirectionDensity: _redirectionDensity,
        bells: _bells,
        selectedBellId: _selectedBellId,
        selectedPractice: _selectedPractice,
        selectedVoiceIndex: _voiceIndex,
        targetClockTimeHour: _clockHour,
        targetClockTimeMinute: _clockMinute,
        targetClockTimeIsAm: _isAm,
      ),
    );
  }

  void _startPractice({
    required int targetSeconds,
    required String practiceType,
    required AudioSegment bell,
  }) {
    final minutes = targetSeconds / 60.0;
    if (minutes < 1.0 || minutes > 90.0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Duration'),
          content: const Text(
            'Meditation duration must be between 1 and 90 minutes. Please adjust your finish time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    List<SessionItem> queue;
    if (practiceType == 'Silent') {
      queue = SessionQueueEngine.generateSilentSessionQueue(
        targetDurationSeconds: targetSeconds,
        selectedBell: bell,
      );
    } else {
      final archetype = ClinicalArchetype.fromTitle(practiceType);
      final voicePersona = _voiceIndex == 1 ? 'grace' : 'kia';
      queue = SessionQueueEngine.generateGuidedSessionQueue(
        targetDurationSeconds: targetSeconds,
        archetype: archetype,
        voicePersona: voicePersona,
        selectedBell: bell,
      );
    }

    if (queue.isEmpty) {
      // Duration too short warning
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duration Too Short'),
          content: const Text(
            'The selected duration is too short for starting and ending bells. Please select a longer duration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _activeTargetSeconds = targetSeconds;
      _activeSessionQueue = queue;
      _currentScreen = AppScreen.practice;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case AppScreen.configuration:
        return ConfigurationScreen(
          practiceDurationMinutes: _practiceDurationMinutes,
          onEnsureFutureTime: _ensureFutureTargetTime,
          onOpenSettings: () {
            setState(() => _currentScreen = AppScreen.settings);
          },
          bells: _bells,
          selectedBellId: _selectedBellId,
          onSelectedBellChanged: (id) {
            setState(() => _selectedBellId = id);
            _persistState();
          },
          onOpenBellSettings: () {
            setState(() => _currentScreen = AppScreen.bellSettings);
          },
          selectedType: _selectedPractice,
          onSelectedTypeChanged: (type) {
            setState(() => _selectedPractice = type);
            _persistState();
          },
          voiceIndex: _voiceIndex,
          onVoiceIndexChanged: (idx) {
            setState(() => _voiceIndex = idx);
            _persistState();
          },
          clockHour: _clockHour,
          clockMinute: _clockMinute,
          isAm: _isAm,
          onClockTimeChanged: (h, m, am) {
            setState(() {
              _clockHour = h;
              _clockMinute = m;
              _isAm = am;
            });
            _persistState();
          },
          onBeginPractice: (targetSec, practiceType, bell) {
            _startPractice(
              targetSeconds: targetSec,
              practiceType: practiceType,
              bell: bell,
            );
          },
        );

      case AppScreen.settings:
        return SettingsScreen(
          practiceDurationMinutes: _practiceDurationMinutes,
          instructionDensity: _instructionDensity,
          redirectionDensity: _redirectionDensity,
          onPracticeDurationChanged: (val) {
            setState(() => _practiceDurationMinutes = val);
            _persistState();
          },
          onInstructionDensityChanged: (val) {
            setState(() => _instructionDensity = val);
            _persistState();
          },
          onRedirectionDensityChanged: (val) {
            setState(() => _redirectionDensity = val);
            _persistState();
          },
          onBack: () {
            _ensureFutureTargetTime();
            setState(() => _currentScreen = AppScreen.configuration);
          },
        );

      case AppScreen.bellSettings:
        return BellConfigurationScreen(
          bells: _bells,
          selectedBellId: _selectedBellId,
          onBellSelected: (id) {
            setState(() => _selectedBellId = id);
            _persistState();
          },
          onBellUpdated: (updated) {
            setState(() {
              final idx = _bells.indexWhere((b) => b.id == updated.id);
              if (idx != -1) {
                _bells[idx] = updated;
              }
            });
            _persistState();
          },
          onBack: () {
            setState(() => _currentScreen = AppScreen.configuration);
          },
        );

      case AppScreen.practice:
        final currentBell = _bells.firstWhere(
          (b) => b.id == _selectedBellId,
          orElse: () => _bells.first,
        );

        return PracticeScreen(
          sessionQueue: _activeSessionQueue,
          targetDurationSeconds: _activeTargetSeconds,
          selectedMeditationType: _selectedPractice == 'Silent'
              ? 'Silent'
              : (_selectedPractice == 'Breath'
                  ? 'Breath Awareness'
                  : _selectedPractice),
          buildDebugScreen: () => SessionDebugScreen(
            targetSeconds: _activeTargetSeconds,
            selectedType: _selectedPractice == 'Silent'
                ? 'Silent'
                : (_selectedPractice == 'Breath'
                    ? 'Breath Awareness'
                    : _selectedPractice),
            instructionDensity: _instructionDensity,
            redirectionDensity: _redirectionDensity,
            selectedBell: currentBell,
            sessionQueue: _activeSessionQueue,
            onBack: () {},
          ),
          onEndSession: () {
            setState(() => _currentScreen = AppScreen.configuration);
          },
        );

      case AppScreen.sessionDebug:
        final currentBell = _bells.firstWhere(
          (b) => b.id == _selectedBellId,
          orElse: () => _bells.first,
        );

        return SessionDebugScreen(
          targetSeconds: _activeTargetSeconds,
          selectedType: _selectedPractice == 'Silent'
              ? 'Silent'
              : (_selectedPractice == 'Breath'
                  ? 'Breath Awareness'
                  : _selectedPractice),
          instructionDensity: _instructionDensity,
          redirectionDensity: _redirectionDensity,
          selectedBell: currentBell,
          sessionQueue: _activeSessionQueue,
          onBack: () {
            setState(() => _currentScreen = AppScreen.practice);
          },
        );
    }
  }
}
