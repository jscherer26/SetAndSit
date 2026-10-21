import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/audio_models.dart';

class AudioManifestService {
  static Map<String, List<ScriptVariant>>? _cachedScriptBank;
  static Map<String, Map<String, Map<String, double>>>? _cachedDurations;

  /// Loads both session_manifest.json and audio_durations.json
  static Future<void> initialize() async {
    if (_cachedScriptBank != null && _cachedDurations != null) return;

    try {
      final manifestJson = await rootBundle.loadString('assets/raw/session_manifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestJson);

      final bankMap = manifestMap['script_bank'] as Map<String, dynamic>? ?? {};
      final parsedBank = <String, List<ScriptVariant>>{};

      bankMap.forEach((segKey, listRaw) {
        if (listRaw is List) {
          parsedBank[segKey] = listRaw
              .map((item) => ScriptVariant.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      });
      _cachedScriptBank = parsedBank;

      final durationsJson = await rootBundle.loadString('assets/raw/audio_durations.json');
      final Map<String, dynamic> durMap = jsonDecode(durationsJson);

      final parsedDurations = <String, Map<String, Map<String, double>>>{};
      durMap.forEach((voiceKey, segsRaw) {
        final vNorm = voiceKey.toLowerCase();
        parsedDurations[vNorm] = {};
        if (segsRaw is Map<String, dynamic>) {
          segsRaw.forEach((segCode, varsRaw) {
            parsedDurations[vNorm]![segCode] = {};
            if (varsRaw is Map<String, dynamic>) {
              varsRaw.forEach((varCode, secVal) {
                parsedDurations[vNorm]![segCode]![varCode] = (secVal as num).toDouble();
              });
            }
          });
        }
      });
      _cachedDurations = parsedDurations;
    } catch (_) {
      _cachedScriptBank ??= {};
      _cachedDurations ??= {};
    }
  }

  /// Returns script variants for a segment code (e.g. 'S01')
  static List<ScriptVariant> getVariantsForSegment(String segmentCode) {
    return _cachedScriptBank?[segmentCode] ?? [];
  }

  /// Returns the exact audio duration for a voice, segment code, and variant
  static double getAudioDuration({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    final vNorm = voice.toLowerCase();
    final sec = _cachedDurations?[vNorm]?[segmentCode]?[variantId];
    if (sec != null && sec > 0) return sec;
    // Default fallback based on segment type
    return segmentCode == 'S16' ? 4.5 : 10.0;
  }

  /// Resolves the full Flutter asset path for a voice persona file
  static String getAudioAssetPath({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    // Files are located in assets/audio/Kia/ or assets/audio/Grace/
    final voiceCapitalized = voice.toLowerCase() == 'kia' ? 'Kia' : 'Grace';
    return 'assets/audio/$voiceCapitalized/${segmentCode}_$variantId.mp3';
  }
}
