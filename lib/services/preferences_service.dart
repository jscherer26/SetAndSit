import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bell_data.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';

class PreferencesService {
  static const String _keyPractices = 'set_and_sit_practices';
  static const String _keyVoices = 'set_and_sit_voices';
  static const String _keyDeveloperMode = 'pref_developer_mode';

  static SharedPreferences? _prefs;

  /// Returns whether Developer Mode is enabled.
  static Future<bool> isDeveloperMode() async {
    final prefs = await getPrefs();
    return prefs.getBool(_keyDeveloperMode) ?? false;
  }

  /// Sets Developer Mode state.
  static Future<void> setDeveloperMode(bool enabled) async {
    final prefs = await getPrefs();
    await prefs.setBool(_keyDeveloperMode, enabled);
  }

  /// Ensures Developer Mode always starts as false on fresh application launch.
  static Future<void> resetDeveloperModeOnStartup() async {
    try {
      final prefs = await getPrefs();
      await prefs.setBool(_keyDeveloperMode, false);
    } catch (_) {}
  }

  /// Visible for testing to reset cached instance when mock values change
  @visibleForTesting
  static void resetCache() {
    _prefs = null;
  }

  /// Pre-warms or gets cached SharedPreferences instance
  static Future<SharedPreferences> getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Explicit initialization helper
  static Future<void> init() async {
    await getPrefs();
  }

  /// Loads voices from local storage, returning defaults if not found.
  /// Automatically purges any retired voices (e.g. legacy 'kia') and migrates storage.
  static Future<List<VoiceConfig>> loadVoices() async {
    final prefs = await getPrefs();
    final raw = prefs.getString(_keyVoices);
    if (raw == null) {
      return VoiceConfig.defaultVoices;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final voices = list
          .map((e) => VoiceConfig.fromJson(e as Map<String, dynamic>))
          .where((v) => v.id.toLowerCase() != 'kia')
          .toList();

      for (final def in VoiceConfig.defaultVoices) {
        if (!voices.any((v) => v.id == def.id)) {
          voices.insert(0, def);
        }
      }

      if (voices.length != list.length) {
        await saveVoices(voices);
      }

      return voices.isNotEmpty ? voices : VoiceConfig.defaultVoices;
    } catch (_) {
      return VoiceConfig.defaultVoices;
    }
  }

  /// Saves the list of voices to local storage.
  static Future<void> saveVoices(List<VoiceConfig> voices) async {
    final prefs = await getPrefs();
    final jsonList = voices.map((v) => v.toJson()).toList();
    await prefs.setString(_keyVoices, jsonEncode(jsonList));
  }

  /// Loads practices from local storage, returning defaults if not found.
  static Future<List<PracticeConfig>> loadPractices() async {
    final prefs = await getPrefs();
    final raw = prefs.getString(_keyPractices);
    if (raw == null) {
      return PracticeConfig.defaultPractices;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      var practices = list
          .map((e) => PracticeConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      if (practices.isEmpty) {
        return PracticeConfig.defaultPractices;
      }

      // Sync system practices with updated system defaults (e.g. renamed "Trauma-Sensitive Grounding")
      var changed = false;
      practices = practices.map((p) {
        if (p.isSystem) {
          final sysDefault = PracticeConfig.defaultPractices.cast<PracticeConfig?>().firstWhere(
            (def) => def?.id == p.id,
            orElse: () => null,
          );
          if (sysDefault != null && (sysDefault.name != p.name || sysDefault.subtitle != p.subtitle)) {
            changed = true;
            return p.copyWith(name: sysDefault.name, subtitle: sysDefault.subtitle);
          }
        }
        return p;
      }).toList();

      if (changed) {
        await savePractices(practices);
      }

      return practices;
    } catch (_) {
      return PracticeConfig.defaultPractices;
    }
  }

  /// Saves the list of practices to local storage.
  static Future<void> savePractices(List<PracticeConfig> practices) async {
    final prefs = await getPrefs();
    final jsonList = practices.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPractices, jsonEncode(jsonList));
  }

  static Future<void> saveState(SavedState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pref_duration', state.practiceDurationMinutes);
      await prefs.setDouble('pref_instruction_density', state.instructionDensity);
      await prefs.setDouble('pref_redirection_density', state.redirectionDensity);
      await prefs.setInt('pref_prep_delay', state.preparationDelaySeconds);
      await prefs.setString('pref_practice_mode', state.practiceMode);
      await prefs.setString('pref_selected_bell_id', state.selectedBellId);
      await prefs.setString('pref_selected_practice_id', state.selectedPracticeId ?? 'focused_calm');
      await prefs.setString('pref_selected_practice_name', state.selectedPractice);
      await prefs.setString('pref_selected_voice_id', state.selectedVoiceId ?? 'grace');
      await prefs.setInt('pref_selected_voice_idx', state.selectedVoiceIndex);
      await prefs.setInt('pref_clock_hour', state.targetClockTimeHour);
      await prefs.setInt('pref_clock_minute', state.targetClockTimeMinute);
      await prefs.setBool('pref_clock_is_am', state.targetClockTimeIsAm);
    } catch (e) {
      debugPrint('[PreferencesService] Error during disk save: $e');
    }
  }

  static Future<SavedState> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var duration = prefs.getInt('pref_duration');
      if (duration == null || duration == 20) {
        duration = 3;
        await prefs.setInt('pref_duration', 3);
      }
      final instruction = prefs.getDouble('pref_instruction_density') ?? 3.0;
      final redirection = prefs.getDouble('pref_redirection_density') ?? 3.0;
      var delay = prefs.getInt('pref_prep_delay');
      if (delay == null || delay == 10) {
        delay = 3;
        await prefs.setInt('pref_prep_delay', 3);
      }
      final mode = prefs.getString('pref_practice_mode') ?? 'Guided';
      final bellId = prefs.getString('pref_selected_bell_id') ?? 'bell_meditation';
      final practiceId = prefs.getString('pref_selected_practice_id') ?? 'focused_calm';
      var practiceName = prefs.getString('pref_selected_practice_name') ?? 'Focused Calm';
      if (practiceName == 'Trauma-Informed Regulation') {
        practiceName = 'Trauma-Sensitive Grounding';
        await prefs.setString('pref_selected_practice_name', 'Trauma-Sensitive Grounding');
      }
      var voiceId = prefs.getString('pref_selected_voice_id') ?? 'grace';
      if (voiceId.toLowerCase() == 'kia') {
        voiceId = 'grace';
        await prefs.setString('pref_selected_voice_id', 'grace');
      }
      final voiceIdx = prefs.getInt('pref_selected_voice_idx') ?? 0;
      final clockHour = prefs.getInt('pref_clock_hour') ?? 8;
      final clockMin = prefs.getInt('pref_clock_minute') ?? 3;
      final clockIsAm = prefs.getBool('pref_clock_is_am') ?? true;

      return SavedState(
        practiceDurationMinutes: duration,
        instructionDensity: instruction,
        redirectionDensity: redirection,
        preparationDelaySeconds: delay,
        practiceMode: mode,
        bells: BellData.defaultBells,
        selectedBellId: bellId,
        selectedPractice: practiceName,
        selectedPracticeId: practiceId,
        selectedVoiceIndex: voiceIdx,
        selectedVoiceId: voiceId,
        targetClockTimeHour: clockHour,
        targetClockTimeMinute: clockMin,
        targetClockTimeIsAm: clockIsAm,
      );
    } catch (e) {
      debugPrint('[PreferencesService] Error during disk load: $e');
      return SavedState(
        practiceDurationMinutes: 3,
        instructionDensity: 3.0,
        redirectionDensity: 3.0,
        preparationDelaySeconds: 3,
        practiceMode: 'Guided',
        bells: BellData.defaultBells,
        selectedBellId: 'bell_meditation',
        selectedPractice: 'Focused Calm',
        selectedPracticeId: 'focused_calm',
        selectedVoiceIndex: 0,
        selectedVoiceId: 'grace',
        targetClockTimeHour: 8,
        targetClockTimeMinute: 3,
        targetClockTimeIsAm: true,
      );
    }
  }
}

class SavedState {
  final int practiceDurationMinutes;
  final double instructionDensity;
  final double redirectionDensity;
  final int preparationDelaySeconds;
  final String practiceMode;
  final List<AudioSegment> bells;
  final String selectedBellId;
  final String selectedPractice;
  final String? selectedPracticeId;
  final int selectedVoiceIndex;
  final String? selectedVoiceId;
  final int targetClockTimeHour;
  final int targetClockTimeMinute;
  final bool targetClockTimeIsAm;

  SavedState({
    required this.practiceDurationMinutes,
    required this.instructionDensity,
    required this.redirectionDensity,
    this.preparationDelaySeconds = 3,
    this.practiceMode = 'Guided',
    required this.bells,
    required this.selectedBellId,
    required this.selectedPractice,
    this.selectedPracticeId,
    required this.selectedVoiceIndex,
    this.selectedVoiceId,
    required this.targetClockTimeHour,
    required this.targetClockTimeMinute,
    required this.targetClockTimeIsAm,
  });

  SavedState copyWith({
    int? practiceDurationMinutes,
    double? instructionDensity,
    double? redirectionDensity,
    int? preparationDelaySeconds,
    String? practiceMode,
    List<AudioSegment>? bells,
    String? selectedBellId,
    String? selectedPractice,
    String? selectedPracticeId,
    int? selectedVoiceIndex,
    String? selectedVoiceId,
    int? targetClockTimeHour,
    int? targetClockTimeMinute,
    bool? targetClockTimeIsAm,
  }) {
    return SavedState(
      practiceDurationMinutes:
          practiceDurationMinutes ?? this.practiceDurationMinutes,
      instructionDensity: instructionDensity ?? this.instructionDensity,
      redirectionDensity: redirectionDensity ?? this.redirectionDensity,
      preparationDelaySeconds:
          preparationDelaySeconds ?? this.preparationDelaySeconds,
      practiceMode: practiceMode ?? this.practiceMode,
      bells: bells ?? this.bells,
      selectedBellId: selectedBellId ?? this.selectedBellId,
      selectedPractice: selectedPractice ?? this.selectedPractice,
      selectedPracticeId: selectedPracticeId ?? this.selectedPracticeId,
      selectedVoiceIndex: selectedVoiceIndex ?? this.selectedVoiceIndex,
      selectedVoiceId: selectedVoiceId ?? this.selectedVoiceId,
      targetClockTimeHour: targetClockTimeHour ?? this.targetClockTimeHour,
      targetClockTimeMinute:
          targetClockTimeMinute ?? this.targetClockTimeMinute,
      targetClockTimeIsAm: targetClockTimeIsAm ?? this.targetClockTimeIsAm,
    );
  }
}
