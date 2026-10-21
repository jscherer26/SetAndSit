import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bell_data.dart';
import '../models/audio_models.dart';

class PreferencesService {
  static const String _keySettings = 'set_and_sit_settings';

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
      selectedVoiceIndex: selectedVoiceIndex ?? this.selectedVoiceIndex,
      targetClockTimeHour: targetClockTimeHour ?? this.targetClockTimeHour,
      targetClockTimeMinute:
          targetClockTimeMinute ?? this.targetClockTimeMinute,
      targetClockTimeIsAm: targetClockTimeIsAm ?? this.targetClockTimeIsAm,
    );
  }
}
