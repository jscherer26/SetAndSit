import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/audio_models.dart';

class AudioManifestService {
  static Map<String, List<ScriptVariant>>? _cachedScriptBank;
  static Map<String, Map<String, Map<String, double>>>? _cachedDurations;
  static bool _isDeveloperMode = false;
  static Map<String, dynamic>? _cachedStagedChanges;

  static bool get isDeveloperMode => _isDeveloperMode;

  static void setDeveloperMode(bool enabled) {
    _isDeveloperMode = enabled;
    if (enabled && _cachedStagedChanges == null) {
      loadStagedChanges();
    }
  }

  static int get stagedVariantsCount {
    if (_cachedStagedChanges == null) return 0;
    final variants = _cachedStagedChanges!['variants'];
    if (variants is Map) return variants.length;
    return 0;
  }

  static Map<String, dynamic>? get stagedChanges => _cachedStagedChanges;

  @visibleForTesting
  static void setMockStagedChanges(Map<String, dynamic>? data) {
    _cachedStagedChanges = data;
  }

  /// Loads staged changes from changes_manifest.json or staged_changes.json
  static Future<void> loadStagedChanges() async {
    try {
      String? jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/audio/changes_manifest.json');
      } catch (_) {
        try {
          jsonStr = await rootBundle.loadString('assets/raw/staged_changes.json');
        } catch (_) {}
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        _cachedStagedChanges = data;
        debugPrint('[AudioManifestService] Loaded staged changes with $stagedVariantsCount variants.');
      }
    } catch (e) {
      debugPrint('[AudioManifestService] Error loading staged changes: $e');
    }
  }

  /// Loads session_manifest.json, audio_durations.json, and staged changes
  static Future<void> initialize({bool? developerMode}) async {
    if (developerMode != null) {
      _isDeveloperMode = developerMode;
    }

    if (_cachedScriptBank != null && _cachedDurations != null) {
      if (_isDeveloperMode && _cachedStagedChanges == null) {
        await loadStagedChanges();
      }
      return;
    }

    try {
      final manifestJson = await rootBundle.loadString('assets/raw/session_manifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestJson);
      final manifest = SessionManifest.fromJson(manifestMap);
      _cachedScriptBank = manifest.scriptBank;

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

      if (_isDeveloperMode) {
        await loadStagedChanges();
      }
    } catch (e) {
      debugPrint('[AudioManifestService] Error initializing audio manifests: $e');
      _cachedScriptBank ??= {};
      _cachedDurations ??= {};
    }
  }

  /// Returns script variants for a segment code (e.g. 'S01')
  /// When Developer Mode is on, staged text overrides are applied.
  static List<ScriptVariant> getVariantsForSegment(String segmentCode) {
    final list = _cachedScriptBank?[segmentCode] ?? [];
    if (!_isDeveloperMode || _cachedStagedChanges == null) {
      return list;
    }

    final variantsMap = _cachedStagedChanges!['variants'];
    if (variantsMap is! Map<String, dynamic>) {
      return list;
    }

    return list.map((v) {
      final key = '${segmentCode}_${v.variantId}';
      final staged = variantsMap[key];
      if (staged is Map<String, dynamic>) {
        return ScriptVariant(
          variantId: v.variantId,
          variantName: v.variantName,
          active: v.active,
          text: staged['text'] as String? ?? v.text,
          wordCount: (staged['word_count'] as num?)?.toInt() ?? v.wordCount,
        );
      }
      return v;
    }).toList();
  }

  /// Checks if a staged replacement exists for this variant
  static bool hasStagedAudio({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    if (!_isDeveloperMode || _cachedStagedChanges == null) return false;
    final key = '${segmentCode}_$variantId';
    final staged = _cachedStagedChanges!['variants']?[key];
    if (staged is Map<String, dynamic>) {
      final durations = staged['durations'];
      if (durations is Map<String, dynamic>) {
        final vNorm = voice.toLowerCase();
        return durations.containsKey(vNorm);
      }
      return true;
    }
    return false;
  }

  /// Returns the exact audio duration for a voice, segment code, and variant.
  /// When in Developer Mode, staged durations take precedence.
  static double getAudioDuration({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    final vNorm = voice.toLowerCase();
    if (_isDeveloperMode && _cachedStagedChanges != null) {
      final key = '${segmentCode}_$variantId';
      final staged = _cachedStagedChanges!['variants']?[key];
      if (staged is Map<String, dynamic>) {
        final durations = staged['durations'];
        if (durations is Map<String, dynamic>) {
          final dur = durations[vNorm];
          if (dur != null) {
            final sec = (dur as num).toDouble();
            if (sec > 0) return sec;
          }
        }
      }
    }

    final sec = _cachedDurations?[vNorm]?[segmentCode]?[variantId];
    if (sec != null && sec > 0) return sec;
    // Default fallback based on segment type
    return segmentCode == 'S16' ? 4.5 : 10.0;
  }

  /// Resolves the full Flutter asset path for a voice persona file.
  /// When Developer Mode is on, checks for staged replacement in changes/.
  static String getAudioAssetPath({
    required String voice,
    required String segmentCode,
    required String variantId,
  }) {
    final vNorm = voice.toLowerCase();
    if (_isDeveloperMode && hasStagedAudio(voice: voice, segmentCode: segmentCode, variantId: variantId)) {
      return 'assets/audio/$vNorm/changes/${segmentCode}_$variantId.mp3';
    }
    return 'assets/audio/$vNorm/${segmentCode}_$variantId.mp3';
  }
}
