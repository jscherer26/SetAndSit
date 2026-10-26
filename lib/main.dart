import 'package:flutter/material.dart';
import 'data/bell_data.dart';
import 'engine/session_queue_engine.dart';
import 'models/audio_models.dart';
import 'models/practice_config.dart';
import 'models/voice_config.dart';
import 'screens/bell_configuration_screen.dart';
import 'screens/configuration_screen.dart';
import 'screens/manage_practices_screen.dart';
import 'screens/manage_voices_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/session_debug_screen.dart';
import 'screens/settings_screen.dart';
import 'services/audio_manifest_service.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SavedState? savedState;
  List<VoiceConfig>? voices;
  List<PracticeConfig>? practices;
  bool isDevMode = false;

  try {
    await PreferencesService.init();
    savedState = await PreferencesService.loadState();
    voices = await PreferencesService.loadVoices();
    practices = await PreferencesService.loadPractices();
    isDevMode = await PreferencesService.isDeveloperMode();
  } catch (e, stack) {
    debugPrint('[SetAndSit] Error loading preferences: $e\n$stack');
  }

  // Run app unconditionally so UI renders even if preferences encountered an error
  runApp(SetAndSitApp(
    initialState: savedState,
    initialVoices: voices,
    initialPractices: practices,
    initialDeveloperMode: isDevMode,
  ));

  // Non-blocking initialization after runApp
  AudioManifestService.initialize(developerMode: isDevMode).catchError((e) {
    debugPrint('[SetAndSit] AudioManifestService error: $e');
  });
}

class SetAndSitApp extends StatelessWidget {
  final SavedState? initialState;
  final List<VoiceConfig>? initialVoices;
  final List<PracticeConfig>? initialPractices;
  final bool? initialDeveloperMode;

  const SetAndSitApp({
    super.key,
    this.initialState,
    this.initialVoices,
    this.initialPractices,
    this.initialDeveloperMode,
  });

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
      home: RootControllerScreen(
        initialState: initialState,
        initialVoices: initialVoices,
        initialPractices: initialPractices,
        initialDeveloperMode: initialDeveloperMode,
      ),
    );
  }
}

enum AppScreen {
  configuration,
  settings,
  bellSettings,
  managePractices,
  manageVoices,
  practice,
  sessionDebug,
}

class RootControllerScreen extends StatefulWidget {
  final SavedState? initialState;
  final List<VoiceConfig>? initialVoices;
  final List<PracticeConfig>? initialPractices;
  final bool? initialDeveloperMode;

  const RootControllerScreen({
    super.key,
    this.initialState,
    this.initialVoices,
    this.initialPractices,
    this.initialDeveloperMode,
  });

  @override
  State<RootControllerScreen> createState() => _RootControllerScreenState();
}

class _RootControllerScreenState extends State<RootControllerScreen>
    with WidgetsBindingObserver {
  AppScreen _currentScreen = AppScreen.configuration;
  AppScreen _previousScreen = AppScreen.configuration;

  int _practiceDurationMinutes = 20;
  double _instructionDensity = 3.0;
  double _redirectionDensity = 3.0;
  int _preparationDelaySeconds = 10;
  String _practiceMode = 'Guided';

  List<AudioSegment> _bells = BellData.defaultBells;
  String _selectedBellId = 'bell_meditation';

  List<PracticeConfig> _practices = PracticeConfig.defaultPractices;
  String _selectedPracticeId = 'focused_calm';
  String _selectedPractice = ClinicalArchetype.focusedCalm.title;
  List<VoiceConfig> _voices = VoiceConfig.defaultVoices;
  String _selectedVoiceId = 'kia';
  int _voiceIndex = 0; // 0: Kia (Male), 1: Grace (Female)

  int _clockHour = 8;
  int _clockMinute = 20;
  bool _isAm = true;
  bool _isInitialized = false;
  bool _isDeveloperMode = false;

  List<SessionItem> _activeSessionQueue = [];
  int _activeTargetSeconds = 1200;

  @override
  void initState() {
    super.initState();
    if (widget.initialDeveloperMode != null) {
      _isDeveloperMode = widget.initialDeveloperMode!;
    }
    if (widget.initialState != null &&
        widget.initialVoices != null &&
        widget.initialPractices != null) {
      _practiceDurationMinutes = widget.initialState!.practiceDurationMinutes;
      _applyLoadedState(
        saved: widget.initialState!,
        voices: widget.initialVoices!,
        practices: widget.initialPractices!,
      );
      _isInitialized = true;
    } else {
      _loadInitialState();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentScreen == AppScreen.configuration) {
        _ensureFutureTargetTime();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _persistState();
    }
  }

  void _applyLoadedState({
    required SavedState saved,
    required List<VoiceConfig> voices,
    required List<PracticeConfig> practices,
  }) {
    final now = DateTime.now();

    // Check if the saved target clock time represents a valid future time (within 1 to 90 minutes)
    final savedHour24 = saved.targetClockTimeIsAm
        ? (saved.targetClockTimeHour == 12 ? 0 : saved.targetClockTimeHour)
        : (saved.targetClockTimeHour == 12 ? 12 : saved.targetClockTimeHour + 12);
    var savedTarget = DateTime(
      now.year,
      now.month,
      now.day,
      savedHour24,
      saved.targetClockTimeMinute,
    );

    // If the saved target clock time is in the past for today, advance it by 1 day
    // to match midnight rollover logic used across the app
    if (!savedTarget.isAfter(now)) {
      savedTarget = savedTarget.add(const Duration(days: 1));
    }

    int initHour;
    int initMinute;
    bool initIsAm;

    final diffSeconds = savedTarget.difference(now).inSeconds;
    if (diffSeconds >= 60 && diffSeconds <= 90 * 60) {
      initHour = saved.targetClockTimeHour;
      initMinute = saved.targetClockTimeMinute;
      initIsAm = saved.targetClockTimeIsAm;
    } else {
      final initialEnd =
          now.add(Duration(minutes: saved.practiceDurationMinutes));
      initHour = initialEnd.hour % 12 == 0 ? 12 : initialEnd.hour % 12;
      initMinute = initialEnd.minute;
      initIsAm = initialEnd.hour < 12;
    }

    var practice = saved.selectedPractice;
    if (practice == 'Breath' || practice == 'Breath Awareness' || practice == 'Guided') {
      practice = ClinicalArchetype.focusedCalm.title;
    }

    final savedId = saved.selectedPracticeId;
    var match = practices.cast<PracticeConfig?>().firstWhere(
      (p) => p?.id == savedId && p?.isIncluded == true,
      orElse: () => null,
    );
    match ??= practices.cast<PracticeConfig?>().firstWhere(
      (p) => p?.name == practice && p?.isIncluded == true,
      orElse: () => null,
    );
    match ??= practices.cast<PracticeConfig?>().firstWhere(
      (p) => p?.isIncluded == true,
      orElse: () => null,
    );
    final resolved = match ?? (practices.isNotEmpty ? practices.first : PracticeConfig.defaultPractices.first);

    final savedVoiceId = saved.selectedVoiceId ??
        (saved.selectedVoiceIndex == 1 ? 'grace' : 'kia');
    var voiceMatch = voices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.id == savedVoiceId && v?.isIncluded == true,
      orElse: () => null,
    );
    voiceMatch ??= voices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.isIncluded == true,
      orElse: () => null,
    );
    final resolvedVoice = voiceMatch ??
        (voices.isNotEmpty ? voices.first : VoiceConfig.defaultVoices.first);

    _practiceDurationMinutes = saved.practiceDurationMinutes;
    _instructionDensity = saved.instructionDensity;
    _redirectionDensity = saved.redirectionDensity;
    _preparationDelaySeconds = saved.preparationDelaySeconds;
    _practiceMode = saved.practiceMode;
    _bells = saved.bells;
    _selectedBellId = saved.selectedBellId;
    _practices = practices;
    _selectedPracticeId = resolved.id;
    _selectedPractice = resolved.name;
    _voices = voices;
    _selectedVoiceId = resolvedVoice.id;
    _voiceIndex = resolvedVoice.id == 'grace' ? 1 : 0;
    _clockHour = initHour;
    _clockMinute = initMinute;
    _isAm = initIsAm;
    _isInitialized = true;
  }

  void _loadInitialState() async {
    try {
      final voices = await PreferencesService.loadVoices();
      final practices = await PreferencesService.loadPractices();
      final saved = await PreferencesService.loadState();
      final isDev = await PreferencesService.isDeveloperMode();

      if (mounted) {
        setState(() {
          _isDeveloperMode = isDev;
          _applyLoadedState(
            saved: saved,
            voices: voices,
            practices: practices,
          );
        });
      }
    } catch (e, stack) {
      debugPrint('[RootControllerScreen] Error in _loadInitialState: $e\n$stack');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _ensureValidSelectedVoice() {
    final match = _voices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.id == _selectedVoiceId && v?.isIncluded == true,
      orElse: () => null,
    );
    if (match != null) {
      _voiceIndex = match.id == 'grace' ? 1 : 0;
      return;
    }

    final firstIncluded = _voices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.isIncluded == true,
      orElse: () => null,
    );
    if (firstIncluded != null) {
      _selectedVoiceId = firstIncluded.id;
      _voiceIndex = firstIncluded.id == 'grace' ? 1 : 0;
      return;
    }

    if (_voices.isNotEmpty) {
      _selectedVoiceId = _voices.first.id;
      _voiceIndex = _voices.first.id == 'grace' ? 1 : 0;
    }
  }

  void _ensureValidSelectedPractice() {
    final match = _practices.cast<PracticeConfig?>().firstWhere(
      (p) => p?.id == _selectedPracticeId && p?.isIncluded == true,
      orElse: () => null,
    );
    if (match != null) {
      _selectedPractice = match.name;
      return;
    }

    final firstIncluded = _practices.cast<PracticeConfig?>().firstWhere(
      (p) => p?.isIncluded == true,
      orElse: () => null,
    );
    if (firstIncluded != null) {
      _selectedPracticeId = firstIncluded.id;
      _selectedPractice = firstIncluded.name;
      return;
    }

    if (_practices.isNotEmpty) {
      _selectedPracticeId = _practices.first.id;
      _selectedPractice = _practices.first.name;
    }
  }

  void _ensureFutureTargetTime() {
    if (!_isInitialized) return;
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
        preparationDelaySeconds: _preparationDelaySeconds,
        practiceMode: _practiceMode,
        bells: _bells,
        selectedBellId: _selectedBellId,
        selectedPractice: _selectedPractice,
        selectedPracticeId: _selectedPracticeId,
        selectedVoiceIndex: _voiceIndex,
        selectedVoiceId: _selectedVoiceId,
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
    PracticeConfig? practiceConfig,
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
      final voicePersona = _selectedVoiceId;
      queue = SessionQueueEngine.generateGuidedSessionQueue(
        targetDurationSeconds: targetSeconds,
        practice: practiceConfig,
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
    return PopScope(
      canPop: _currentScreen == AppScreen.configuration,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentScreen == AppScreen.practice) return;
        setState(() {
          if (_currentScreen == AppScreen.manageVoices) {
            _ensureValidSelectedVoice();
          }
          _currentScreen = _previousScreen;
        });
        _persistState();
      },
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    switch (_currentScreen) {
      case AppScreen.configuration:
        return ConfigurationScreen(
          isDeveloperMode: _isDeveloperMode,
          onDeveloperModeChanged: (enabled) async {
            setState(() {
              _isDeveloperMode = enabled;
            });
            AudioManifestService.setDeveloperMode(enabled);
            await PreferencesService.setDeveloperMode(enabled);
          },
          practiceDurationMinutes: _practiceDurationMinutes,
          onEnsureFutureTime: _ensureFutureTargetTime,
          onOpenSettings: () {
            setState(() {
              _previousScreen = AppScreen.configuration;
              _currentScreen = AppScreen.settings;
            });
          },
          bells: _bells,
          selectedBellId: _selectedBellId,
          onSelectedBellChanged: (id) {
            setState(() => _selectedBellId = id);
            _persistState();
          },
          onOpenBellSettings: () {
            setState(() {
              _previousScreen = AppScreen.configuration;
              _currentScreen = AppScreen.bellSettings;
            });
          },
          selectedType: _practiceMode,
          onSelectedTypeChanged: (type) {
            setState(() => _practiceMode = type);
            _persistState();
          },
          practices: _practices,
          selectedPracticeId: _selectedPracticeId,
          onSelectedPracticeIdChanged: (id) {
            final p = _practices.firstWhere((p) => p.id == id);
            setState(() {
              _selectedPracticeId = id;
              _selectedPractice = p.name;
            });
            _persistState();
          },
          onOpenManagePractices: () {
            setState(() {
              _previousScreen = AppScreen.configuration;
              _currentScreen = AppScreen.managePractices;
            });
          },
          voices: _voices,
          selectedVoiceId: _selectedVoiceId,
          onSelectedVoiceIdChanged: (id) {
            setState(() {
              _selectedVoiceId = id;
              _voiceIndex = id == 'grace' ? 1 : 0;
            });
            _persistState();
          },
          onOpenManageVoices: () {
            setState(() {
              _previousScreen = AppScreen.configuration;
              _currentScreen = AppScreen.manageVoices;
            });
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
          onBeginPractice: (targetSec, practiceType, bell, practiceConfig) {
            _startPractice(
              targetSeconds: targetSec,
              practiceType: _practiceMode,
              bell: bell,
              practiceConfig: practiceConfig,
            );
          },
        );

      case AppScreen.managePractices:
        return ManagePracticesScreen(
          initialPractices: _practices,
          initialSelectedPracticeId: _selectedPracticeId,
          onPracticesUpdated: (updated) {
            setState(() {
              _practices = updated;
              _ensureValidSelectedPractice();
            });
            PreferencesService.savePractices(_practices);
            _persistState();
          },
          onBack: () {
            setState(() {
              _ensureValidSelectedPractice();
              _currentScreen = _previousScreen;
            });
            _persistState();
          },
        );

      case AppScreen.manageVoices:
        return ManageVoicesScreen(
          isDeveloperMode: _isDeveloperMode,
          initialVoices: _voices,
          initialSelectedVoiceId: _selectedVoiceId,
          onVoicesUpdated: (updated) {
            setState(() {
              _voices = updated;
              _ensureValidSelectedVoice();
            });
            PreferencesService.saveVoices(_voices);
            _persistState();
          },
          onBack: () {
            setState(() {
              _ensureValidSelectedVoice();
              _currentScreen = _previousScreen;
            });
            _persistState();
          },
        );

      case AppScreen.settings:
        return SettingsScreen(
          practiceDurationMinutes: _practiceDurationMinutes,
          instructionDensity: _instructionDensity,
          redirectionDensity: _redirectionDensity,
          preparationDelaySeconds: _preparationDelaySeconds,
          onPracticeDurationChanged: (val) {
            setState(() => _practiceDurationMinutes = val);
            _persistState();
          },
          onPreparationDelayChanged: (val) {
            setState(() => _preparationDelaySeconds = val);
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
            setState(() => _currentScreen = AppScreen.configuration);
            _persistState();
          },
          onOpenManagePractices: () {
            setState(() {
              _previousScreen = AppScreen.settings;
              _currentScreen = AppScreen.managePractices;
            });
            _persistState();
          },
          onOpenManageVoices: () {
            setState(() {
              _previousScreen = AppScreen.settings;
              _currentScreen = AppScreen.manageVoices;
            });
            _persistState();
          },
          onOpenBellSettings: () {
            setState(() {
              _previousScreen = AppScreen.settings;
              _currentScreen = AppScreen.bellSettings;
            });
            _persistState();
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
            setState(() => _currentScreen = _previousScreen);
          },
        );

      case AppScreen.practice:
        final currentBell = _bells.firstWhere(
          (b) => b.id == _selectedBellId,
          orElse: () => _bells.first,
        );

        final isGuided = _practiceMode != 'Silent';
        PracticeConfig? currentPracticeConfig;
        if (isGuided) {
          currentPracticeConfig = _practices.firstWhere(
            (p) => p.id == _selectedPracticeId,
            orElse: () => _practices.first,
          );
        }

        return PracticeScreen(
          isDeveloperMode: _isDeveloperMode,
          sessionQueue: _activeSessionQueue,
          targetDurationSeconds: _activeTargetSeconds,
          preparationDelaySeconds: _preparationDelaySeconds,
          targetClockHour: _clockHour,
          targetClockMinute: _clockMinute,
          targetClockIsAm: _isAm,
          onBuildQueue: (actualSeconds) {
            if (!isGuided) {
              return SessionQueueEngine.generateSilentSessionQueue(
                targetDurationSeconds: actualSeconds,
                selectedBell: currentBell,
              );
            } else {
              return SessionQueueEngine.generateGuidedSessionQueue(
                targetDurationSeconds: actualSeconds,
                practice: currentPracticeConfig,
                voicePersona: _selectedVoiceId,
                selectedBell: currentBell,
              );
            }
          },
          onPracticeStarted: (freshQueue, actualSeconds) {
            setState(() {
              _activeSessionQueue = freshQueue;
              _activeTargetSeconds = actualSeconds;
            });
          },
          selectedMeditationType: _practiceMode == 'Silent'
              ? 'Silent'
              : (_selectedPractice == 'Breath'
                  ? 'Breath Awareness'
                  : _selectedPractice),
          selectedBell: currentBell,
          buildDebugScreen: () => SessionDebugScreen(
            targetSeconds: _activeTargetSeconds,
            selectedType: _practiceMode == 'Silent'
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
          buildDebugScreenWithQueue: (liveQueue, liveTargetSeconds) => SessionDebugScreen(
            targetSeconds: liveTargetSeconds,
            selectedType: _practiceMode == 'Silent'
                ? 'Silent'
                : (_selectedPractice == 'Breath'
                    ? 'Breath Awareness'
                    : _selectedPractice),
            instructionDensity: _instructionDensity,
            redirectionDensity: _redirectionDensity,
            selectedBell: currentBell,
            sessionQueue: liveQueue,
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
