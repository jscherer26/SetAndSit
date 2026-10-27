// ignore_for_file: constant_identifier_names

// 16-Segment Clinical Meditation Taxonomy (S01 - S16)
enum ClinicalSegment {
  S01('S01', 'External Arrival', 'Arrival & Agency', false),
  S02('S02', 'Permission and Choice', 'Arrival & Agency', false),
  S03('S03', 'Breath Orientation', 'Arrival & Agency', false),
  S04('S04', 'Somatic Grounding', 'Arrival & Agency', false),
  S05('S05', 'Safety / Resource Priming', 'Arrival & Agency', false),
  S06('S06', 'Paced Breathing', 'Attentional Anchoring', false),
  S07('S07', 'Vagal Release', 'Attentional Anchoring', false),
  S08('S08', 'Single-Point Anchor', 'Attentional Anchoring', false),
  S09('S09', 'Open Sky', 'State Cultivation', false),
  S10('S10', 'Mental Noting', 'State Cultivation', false),
  S11('S11', 'Metta', 'State Cultivation', false),
  S12('S12', 'Silent Integration Window', 'Deep Silence', false),
  S13('S13', 'Physical Re-Awakening', 'Re-Orientation & Close', false),
  S14('S14', 'Meaning Transfer', 'Re-Orientation & Close', false),
  S15('S15', 'External Reorientation', 'Re-Orientation & Close', false),
  S16('S16', 'Closing Guidance', 'Re-Orientation & Close', false);

  final String code;
  final String title;
  final String phase;
  final bool isSilence;

  const ClinicalSegment(this.code, this.title, this.phase, this.isSilence);

  static ClinicalSegment fromCode(String code) {
    return ClinicalSegment.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ClinicalSegment.S01,
    );
  }
}

// 4 Official Practice Archetypes
enum ClinicalArchetype {
  focusedCalm(
    id: 'focused_calm',
    title: 'Focused Calm',
    subtitle: 'Attentional stability, interoceptive baseline, parasympathetic deceleration',
    pipeline: [
      ClinicalSegment.S01,
      ClinicalSegment.S02,
      ClinicalSegment.S03,
      ClinicalSegment.S04,
      ClinicalSegment.S06,
      ClinicalSegment.S07,
      ClinicalSegment.S08,
      ClinicalSegment.S12,
      ClinicalSegment.S13,
      ClinicalSegment.S15,
      ClinicalSegment.S16,
    ],
  ),
  traumaInformed(
    id: 'trauma_informed',
    title: 'Trauma-Sensitive Grounding',
    subtitle: 'High agency, explicit somatic safe-harbor, bypasses vulnerable breath focus',
    pipeline: [
      ClinicalSegment.S01,
      ClinicalSegment.S02,
      ClinicalSegment.S04,
      ClinicalSegment.S05,
      ClinicalSegment.S07,
      ClinicalSegment.S08,
      ClinicalSegment.S10,
      ClinicalSegment.S12,
      ClinicalSegment.S13,
      ClinicalSegment.S14,
      ClinicalSegment.S15,
      ClinicalSegment.S16,
    ],
  ),
  openAwareness(
    id: 'open_awareness',
    title: 'Open Awareness / Insight',
    subtitle: 'Decentering, panoramic awareness, non-reactive metacognitive inquiry',
    pipeline: [
      ClinicalSegment.S01,
      ClinicalSegment.S02,
      ClinicalSegment.S03,
      ClinicalSegment.S04,
      ClinicalSegment.S08,
      ClinicalSegment.S09,
      ClinicalSegment.S10,
      ClinicalSegment.S12,
      ClinicalSegment.S13,
      ClinicalSegment.S15,
      ClinicalSegment.S16,
    ],
  ),
  mettaCompassion(
    id: 'metta_compassion',
    title: 'Metta / Compassion',
    subtitle: 'Ventral vagal activation, relational warmth, pro-social imagery, meaning transfer',
    pipeline: [
      ClinicalSegment.S01,
      ClinicalSegment.S02,
      ClinicalSegment.S03,
      ClinicalSegment.S04,
      ClinicalSegment.S07,
      ClinicalSegment.S11,
      ClinicalSegment.S12,
      ClinicalSegment.S13,
      ClinicalSegment.S14,
      ClinicalSegment.S15,
      ClinicalSegment.S16,
    ],
  );

  final String id;
  final String title;
  final String subtitle;
  final List<ClinicalSegment> pipeline;

  const ClinicalArchetype({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.pipeline,
  });

  static ClinicalArchetype fromId(String id) {
    return ClinicalArchetype.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ClinicalArchetype.focusedCalm,
    );
  }

  static ClinicalArchetype fromTitle(String title) {
    return ClinicalArchetype.values.firstWhere(
      (e) => e.title == title,
      orElse: () => ClinicalArchetype.focusedCalm,
    );
  }
}

// Master Session Manifest model
class SessionManifest {
  final String app;
  final String schemaVersion;
  final String description;
  final Map<String, List<ScriptVariant>> scriptBank;

  SessionManifest({
    required this.app,
    required this.schemaVersion,
    required this.description,
    required this.scriptBank,
  });

  factory SessionManifest.fromJson(Map<String, dynamic> json) {
    final bankMap = json['script_bank'] as Map<String, dynamic>? ?? {};
    final parsedBank = <String, List<ScriptVariant>>{};

    bankMap.forEach((segKey, listRaw) {
      if (listRaw is List) {
        parsedBank[segKey] = listRaw
            .map((item) => ScriptVariant.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    });

    return SessionManifest(
      app: json['app'] as String? ?? '',
      schemaVersion: json['schema_version'] as String? ?? '',
      description: json['description'] as String? ?? '',
      scriptBank: parsedBank,
    );
  }
}

// Script variant from manifest
class ScriptVariant {
  final String variantId;
  final String variantName;
  final bool active;
  final String text;
  final int wordCount;

  ScriptVariant({
    required this.variantId,
    required this.variantName,
    required this.active,
    required this.text,
    required this.wordCount,
  });

  /// Returns cleaned, readable text removing any `[...]` brackets,
  /// formatting ellipses `...` into natural punctuation, and cleaning extra whitespace.
  String get cleanText {
    if (text.isEmpty) return '';
    var cleaned = text.replaceAll(RegExp(r'\[.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\.{2,}|\u2026'), ',');
    cleaned = cleaned.replaceAll(RegExp(r',\s*,'), ',');
    cleaned = cleaned.replaceAll(RegExp(r',\s*\.'), '.');
    cleaned = cleaned.replaceAll(RegExp(r'\.\s*,'), '.');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.endsWith(',')) {
      cleaned = '${cleaned.substring(0, cleaned.length - 1)}.';
    }
    return cleaned;
  }

  factory ScriptVariant.fromJson(Map<String, dynamic> json) => ScriptVariant(
        variantId: json['variant_id'] as String? ?? 'v01',
        variantName: json['variant_name'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        text: json['text'] as String? ?? '',
        wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      );
}

// Acoustic Bell model
class AudioSegment {
  final String id;
  final String title;
  final String filePath;
  final int durationSeconds;
  final int minDelayBefore;
  final int maxDelayBefore;
  final bool isEnabled;

  AudioSegment({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationSeconds,
    required this.minDelayBefore,
    required this.maxDelayBefore,
    this.isEnabled = true,
  });

  AudioSegment copyWith({
    String? id,
    String? title,
    String? filePath,
    int? durationSeconds,
    int? minDelayBefore,
    int? maxDelayBefore,
    bool? isEnabled,
  }) {
    return AudioSegment(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      minDelayBefore: minDelayBefore ?? this.minDelayBefore,
      maxDelayBefore: maxDelayBefore ?? this.maxDelayBefore,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'durationSeconds': durationSeconds,
        'minDelayBefore': minDelayBefore,
        'maxDelayBefore': maxDelayBefore,
        'isEnabled': isEnabled,
      };

  factory AudioSegment.fromJson(Map<String, dynamic> json) => AudioSegment(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['filePath'] as String,
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        minDelayBefore: (json['minDelayBefore'] as num).toInt(),
        maxDelayBefore: (json['maxDelayBefore'] as num).toInt(),
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}

// Playback Queue Items for execution
abstract class SessionItem {
  String get displayTitle;
  String get phaseName;
  String get text;
}

class PlayAudioItem extends SessionItem {
  final String id;
  @override
  final String displayTitle;
  @override
  final String phaseName;
  final String audioAssetPath;
  final double durationSeconds;
  final ClinicalSegment? segment;
  final bool isBell;
  @override
  final String text;
  final String? bellAssetPath;

  PlayAudioItem({
    required this.id,
    required this.displayTitle,
    required this.phaseName,
    required this.audioAssetPath,
    required this.durationSeconds,
    this.segment,
    this.isBell = false,
    this.text = '',
    this.bellAssetPath,
  });
}

class PauseSilenceItem extends SessionItem {
  final int durationSeconds;
  @override
  final String displayTitle;
  @override
  final String phaseName;
  @override
  final String text;

  PauseSilenceItem(
    this.durationSeconds, {
    this.displayTitle = 'Deep Integration Silence',
    this.phaseName = 'Deep Silence',
    this.text = '',
  });
}
