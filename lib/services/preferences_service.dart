import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bell_data.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';

class PreferencesService {
  static const String _keySettings = 'set_and_sit_settings';
  static const String _keyPractices = 'set_and_sit_practices';

  /// Loads practices from local storage, returning defaults if not found.
  static Future<List<PracticeConfig>> loadPractices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPractices);
    if (raw == null) {
      return PracticeConfig.defaultPractices;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final practices = list
          .map((e) => PracticeConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      return practices.isNotEmpty ? practices : PracticeConfig.defaultPractices;
    } catch (_) {
      return PracticeConfig.defaultPractices;
    }
  }

  /// Saves the list of practices to local storage.
  static Future<void> savePractices(List<PracticeConfig> practices) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = practices.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPractices, jsonEncode(jsonList));
  }

  static Future<SavedState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySettings);
    if (raw == null) {
      return SavedState(
        practiceDurationMinutes: 20,
        instructionDensity: 3.0,
        redirectionDensity: 3.0,
        bells: BellData.defaultBells,
        selectedBellId: 'bell_meditation',
        selectedPractice: 'Guided',
        selectedPracticeId: 'focused_calm',
        selectedVoiceIndex: 0,
        targetClockTimeHour: 8,
        targetClockTimeMinute: 20,
        targetClockTimeIsAm: true,
      );
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;

      int practiceDurationMinutes =
          (map['practiceDurationMinutes'] as num?)?.toInt() ?? 20;
      if (practiceDurationMinutes < 1) practiceDurationMinutes = 1;
      if (practiceDurationMinutes > 90) practiceDurationMinutes = 90;

      double instructionDensity = 3.0;
      double redirectionDensity = 3.0;

      if (map['instructionDensity'] != null) {
        instructionDensity = (map['instructionDensity'] as num).toDouble();
      }

      if (map['redirectionDensity'] != null) {
        redirectionDensity = (map['redirectionDensity'] as num).toDouble();
      }

      List<AudioSegment> bells = BellData.defaultBells;
      if (map['bells'] != null) {
        final list = map['bells'] as List<dynamic>;
        bells = list
            .map((e) => AudioSegment.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return SavedState(
        practiceDurationMinutes: practiceDurationMinutes,
        instructionDensity: instructionDensity,
        redirectionDensity: redirectionDensity,
        bells: bells.isNotEmpty ? bells : BellData.defaultBells,
        selectedBellId: (map['selectedBellId'] as String?) ?? 'bell_meditation',
        selectedPractice: (map['selectedPractice'] as String?) ?? 'Guided',
        selectedPracticeId: (map['selectedPracticeId'] as String?) ?? 'focused_calm',
        selectedVoiceIndex: (map['selectedVoiceIndex'] as num?)?.toInt() ?? 0,
        targetClockTimeHour: (map['targetClockTimeHour'] as num?)?.toInt() ?? 8,
        targetClockTimeMinute:
            (map['targetClockTimeMinute'] as num?)?.toInt() ?? 20,
        targetClockTimeIsAm: (map['targetClockTimeIsAm'] as bool?) ?? true,
      );
    } catch (_) {
      return SavedState(
        practiceDurationMinutes: 20,
        instructionDensity: 3.0,
        redirectionDensity: 3.0,
        bells: BellData.defaultBells,
        selectedBellId: 'bell_meditation',
        selectedPractice: 'Guided',
        selectedPracticeId: 'focused_calm',
        selectedVoiceIndex: 0,
        targetClockTimeHour: 8,
        targetClockTimeMinute: 20,
        targetClockTimeIsAm: true,
      );
    }
  }

  static Future<void> saveState(SavedState state) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'practiceDurationMinutes': state.practiceDurationMinutes,
      'instructionDensity': state.instructionDensity,
      'redirectionDensity': state.redirectionDensity,
      'bells': state.bells.map((e) => e.toJson()).toList(),
      'selectedBellId': state.selectedBellId,
      'selectedPractice': state.selectedPractice,
      'selectedPracticeId': state.selectedPracticeId,
      'selectedVoiceIndex': state.selectedVoiceIndex,
      'targetClockTimeHour': state.targetClockTimeHour,
      'targetClockTimeMinute': state.targetClockTimeMinute,
      'targetClockTimeIsAm': state.targetClockTimeIsAm,
    };
    await prefs.setString(_keySettings, jsonEncode(map));
  }
}

class SavedState {
  final int practiceDurationMinutes;
  final double instructionDensity;
  final double redirectionDensity;
  final List<AudioSegment> bells;
  final String selectedBellId;
  final String selectedPractice;
  final String? selectedPracticeId;
  final int selectedVoiceIndex;
  final int targetClockTimeHour;
  final int targetClockTimeMinute;
  final bool targetClockTimeIsAm;

  SavedState({
    required this.practiceDurationMinutes,
    required this.instructionDensity,
    required this.redirectionDensity,
    required this.bells,
    required this.selectedBellId,
    required this.selectedPractice,
    this.selectedPracticeId,
    required this.selectedVoiceIndex,
    required this.targetClockTimeHour,
    required this.targetClockTimeMinute,
    required this.targetClockTimeIsAm,
  });

  SavedState copyWith({
    int? practiceDurationMinutes,
    double? instructionDensity,
    double? redirectionDensity,
    List<AudioSegment>? bells,
    String? selectedBellId,
    String? selectedPractice,
    String? selectedPracticeId,
    int? selectedVoiceIndex,
    int? targetClockTimeHour,
    int? targetClockTimeMinute,
    bool? targetClockTimeIsAm,
  }) {
    return SavedState(
      practiceDurationMinutes:
          practiceDurationMinutes ?? this.practiceDurationMinutes,
      instructionDensity: instructionDensity ?? this.instructionDensity,
      redirectionDensity: redirectionDensity ?? this.redirectionDensity,
      bells: bells ?? this.bells,
      selectedBellId: selectedBellId ?? this.selectedBellId,
      selectedPractice: selectedPractice ?? this.selectedPractice,
      selectedPracticeId: selectedPracticeId ?? this.selectedPracticeId,
      selectedVoiceIndex: selectedVoiceIndex ?? this.selectedVoiceIndex,
      targetClockTimeHour: targetClockTimeHour ?? this.targetClockTimeHour,
      targetClockTimeMinute:
          targetClockTimeMinute ?? this.targetClockTimeMinute,
      targetClockTimeIsAm: targetClockTimeIsAm ?? this.targetClockTimeIsAm,
    );
  }
}
