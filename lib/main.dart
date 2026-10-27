import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/bell_data.dart';
import 'engine/session_queue_engine.dart';
import 'models/audio_models.dart';
import 'models/practice_config.dart';
import 'models/voice_config.dart';
import 'screens/about_screen.dart';
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

  try {
    await PreferencesService.init();
    await PreferencesService.resetDeveloperModeOnStartup();
    savedState = await PreferencesService.loadState();
    voices = await PreferencesService.loadVoices();
    practices = await PreferencesService.loadPractices();
  } catch (e, stack) {
    debugPrint('[SetAndSit] Error loading preferences: $e\n$stack');
  }

  // Run app unconditionally so UI renders even if preferences encountered an error
  runApp(SetAndSitApp(
    initialState: savedState,
    initialVoices: voices,
    initialPractices: practices,
    initialDeveloperMode: false,
  ));

  // Non-blocking initialization after runApp
  AudioManifestService.initialize(developerMode: false).catchError((e) {
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
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            // When opened on a mobile device's browser, fill the screen normally
            if (constraints.maxWidth <= 500) {
              return child ?? const SizedBox.shrink();
            }
            // On desktop/laptop web browsers, constrain to phone width and center with a backdrop
            const double maxAppWidth = 440;
            return Container(
              color: const Color(0xFF1E201E),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: maxAppWidth),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(maxAppWidth, constraints.maxHeight),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
  about,
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

  int _practiceDurationMinutes = 3;
  double _instructionDensity = 3.0;
  double _redirectionDensity = 3.0;
  int _preparationDelaySeconds = 3;
  String _practiceMode = 'Guided';

  List<AudioSegment> _bells = BellData.defaultBells;
  String _selectedBellId = 'bell_meditation';

  List<PracticeConfig> _practices = PracticeConfig.defaultPractices;
  String _selectedPracticeId = 'focused_calm';
  String _selectedPractice = ClinicalArchetype.focusedCalm.title;
  List<VoiceConfig> _voices = VoiceConfig.defaultVoices;
  String _selectedVoiceId = 'grace';
  int _voiceIndex = 0;

  int _clockHour = 8;
  int _clockMinute = 3;
  bool _isAm = true;
  bool _isInitialized = false;
  bool _isDeveloperMode = false;

  List<SessionItem> _activeSessionQueue = [];
  int _activeTargetSeconds = 180;

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
      final roundedMinute = now.second >= 30 ? now.minute + 1 : now.minute;
      final base = DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
      final initialEnd =
          base.add(Duration(minutes: saved.practiceDurationMinutes));
      initHour = initialEnd.hour % 12 == 0 ? 12 : initialEnd.hour % 12;
      initMinute = initialEnd.minute;
      initIsAm = initialEnd.hour < 12;
    }

    var practice = saved.selectedPractice;
    if (practice == 'Breath' || practice == 'Breath Awareness' || practice == 'Guided') {
      practice = ClinicalArchetype.focusedCalm.title;
    } else if (practice == 'Trauma-Informed Regulation') {
      practice = ClinicalArchetype.traumaInformed.title;
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

    final cleanedVoices = voices.where((v) => v.id.toLowerCase() != 'kia').toList();
    final effectiveVoices = cleanedVoices.isNotEmpty ? cleanedVoices : VoiceConfig.defaultVoices;

    final savedVoiceId = (saved.selectedVoiceId != null && saved.selectedVoiceId!.toLowerCase() != 'kia')
        ? saved.selectedVoiceId
        : null;
    var voiceMatch = savedVoiceId != null
        ? effectiveVoices.cast<VoiceConfig?>().firstWhere(
            (v) => v?.id == savedVoiceId && v?.isIncluded == true,
            orElse: () => null,
          )
        : null;
    if (voiceMatch == null &&
        saved.selectedVoiceIndex >= 0 &&
        saved.selectedVoiceIndex < effectiveVoices.length) {
      final candidate = effectiveVoices[saved.selectedVoiceIndex];
      if (candidate.isIncluded && candidate.id.toLowerCase() != 'kia') {
        voiceMatch = candidate;
      }
    }
    voiceMatch ??= effectiveVoices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.isIncluded == true,
      orElse: () => null,
    );
    final resolvedVoice = voiceMatch ??
        (effectiveVoices.isNotEmpty ? effectiveVoices.first : VoiceConfig.defaultVoices.first);

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
    _voices = effectiveVoices;
    _selectedVoiceId = resolvedVoice.id;
    final resolvedIdx = effectiveVoices.indexWhere((v) => v.id == resolvedVoice.id);
    _voiceIndex = resolvedIdx >= 0 ? resolvedIdx : 0;
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
    _voices = _voices.where((v) => v.id.toLowerCase() != 'kia').toList();
    if (_voices.isEmpty) {
      _voices = VoiceConfig.defaultVoices;
    }
    if (_selectedVoiceId.toLowerCase() == 'kia') {
      _selectedVoiceId = _voices.first.id;
    }
    final match = _voices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.id == _selectedVoiceId && v?.isIncluded == true,
      orElse: () => null,
    );
    if (match != null) {
      final idx = _voices.indexWhere((v) => v.id == match.id);
      _voiceIndex = idx >= 0 ? idx : 0;
      return;
    }

    final firstIncluded = _voices.cast<VoiceConfig?>().firstWhere(
      (v) => v?.isIncluded == true,
      orElse: () => null,
    );
    if (firstIncluded != null) {
      _selectedVoiceId = firstIncluded.id;
      final idx = _voices.indexWhere((v) => v.id == firstIncluded.id);
      _voiceIndex = idx >= 0 ? idx : 0;
      return;
    }

    if (_voices.isNotEmpty) {
      _selectedVoiceId = _voices.first.id;
      _voiceIndex = 0;
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
      final roundedMinute = now.second >= 30 ? now.minute + 1 : now.minute;
      final base = DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
      final newTarget = base.add(Duration(minutes: _practiceDurationMinutes));
      setState(() {
        _clockHour = newTarget.hour % 12 == 0 ? 12 : newTarget.hour % 12;
        _clockMinute = newTarget.minute;
        _isAm = newTarget.hour < 12;
      });
      _persistState();
    }
  }

  void _updatePracticeDuration(int newDurationMinutes) {
    final now = DateTime.now();
    final roundedMinute = now.second >= 30 ? now.minute + 1 : now.minute;
    final base = DateTime(now.year, now.month, now.day, now.hour, roundedMinute);
    final newTarget = base.add(Duration(minutes: newDurationMinutes));
    setState(() {
      _practiceDurationMinutes = newDurationMinutes;
      _clockHour = newTarget.hour % 12 == 0 ? 12 : newTarget.hour % 12;
      _clockMinute = newTarget.minute;
      _isAm = newTarget.hour < 12;
    });
    _persistState();
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
              final idx = _voices.indexWhere((v) => v.id == id);
              _voiceIndex = idx >= 0 ? idx : 0;
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
            setState(() {
              _voiceIndex = idx;
              if (idx >= 0 && idx < _voices.length) {
                _selectedVoiceId = _voices[idx].id;
              }
            });
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
            _updatePracticeDuration(val);
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
          onOpenAbout: () {
            setState(() {
              _previousScreen = AppScreen.settings;
              _currentScreen = AppScreen.about;
            });
            _persistState();
          },
        );

      case AppScreen.about:
        return AboutScreen(
          onBack: () {
            setState(() => _currentScreen = _previousScreen);
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
