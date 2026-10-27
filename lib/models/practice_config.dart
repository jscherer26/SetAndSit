import 'audio_models.dart';

/// Mandatory segments that cannot be deselected in any practice.
const List<String> kMandatorySegmentIds = [
  'S01',
  'S02',
  'S12',
  'S15',
  'S16',
];

/// Clinical Arc Phases and their grouped segments (S01 - S16)
const Map<String, List<String>> kPhaseSegments = {
  'Phase 1: Arrival, Agency & Safety Setup': [
    'S01',
    'S02',
    'S03',
    'S04',
    'S05',
  ],
  'Phase 2: Down-Regulation & Attentional Anchoring': [
    'S06',
    'S07',
    'S08',
  ],
  'Phase 3: Core Practice & State Cultivation': [
    'S09',
    'S10',
    'S11',
  ],
  'Phase 4: Deep Integration Silence': [
    'S12',
  ],
  'Phase 5: Re-Orientation, Meaning & Close': [
    'S13',
    'S14',
    'S15',
    'S16',
  ],
};

/// 16-Segment Clinical Metadata (Phase, Title, Clinical Rationale, and Example Guidance)
const Map<String, Map<String, String>> kSegmentMetadata = {
  'S01': {
    'phase': 'Phase 1: Arrival, Agency & Safety Setup',
    'title': 'External Arrival',
    'rationale':
        'Serves as a perceptual bridge from daily tasks into the meditation container. Establishes environmental safety before internal attention is engaged.',
    'example':
        '“Letting ourselves settle into this space... seeing if it\'s possible to allow whatever happened earlier today to simply fade into the background.”',
  },
  'S02': {
    'phase': 'Phase 1: Arrival, Agency & Safety Setup',
    'title': 'Permission & Choice',
    'rationale':
        'Explicitly hands agency back to the practitioner regarding posture and eye closure, deactivating threat-monitoring or compliance pressure.',
    'example':
        '“And as we arrive, knowing you can adjust your posture at any time... exploring whether it feels right to let the eyes gently close, or simply keeping a soft gaze.”',
  },
  'S03': {
    'phase': 'Phase 1: Arrival, Agency & Safety Setup',
    'title': 'Natural Breath Flow',
    'rationale':
        'Directs attention to natural respiration without forcing deep breaths or pacing counts, establishing baseline interoception.',
    'example':
        '“Softly noticing the body as it breathes itself... resting your attention on that natural rise and fall, without needing to change a single thing.”',
  },
  'S04': {
    'phase': 'Phase 1: Arrival, Agency & Safety Setup',
    'title': 'Somatic Grounding',
    'rationale':
        'Directs awareness toward physical contact points and gravity to initiate parasympathetic settling through tactile support.',
    'example':
        '“Beginning by noticing the points of contact between your body and the surface beneath you—the weight of your seat, or the support of the floor.”',
  },
  'S05': {
    'phase': 'Phase 1: Arrival, Agency & Safety Setup',
    'title': 'Sensory & Environmental Anchor',
    'rationale':
        'Uses ambient sounds, textures, and room awareness as a stabilizing external anchor when internal focus feels intense.',
    'example':
        '“Tuning into the ambient sounds around you. Noticing sounds in the distance, then closer, without clinging to any single sound.”',
  },
  'S06': {
    'phase': 'Phase 2: Down-Regulation & Attentional Anchoring',
    'title': 'Restorative Breath Pacing',
    'rationale':
        'Invites a slightly longer, unhurried exhale and smooth respiratory rhythm to actively decelerate the autonomic nervous system.',
    'example':
        '“If it feels supportive, we might explore a slightly longer exhale... breathing in fully, and letting the air release just a bit slower.”',
  },
  'S07': {
    'phase': 'Phase 2: Down-Regulation & Attentional Anchoring',
    'title': 'Vagal & Somatic Release',
    'rationale':
        'Softens muscles around the eyes, jaw, throat, and belly to release physical holding and stimulate ventral vagal rest-and-digest pathways.',
    'example':
        '“Softly relaxing the muscles around your eyes and unclenching your jaw. Letting a gentle sigh out on your next exhale.”',
  },
  'S08': {
    'phase': 'Phase 2: Down-Regulation & Attentional Anchoring',
    'title': 'Focused Anchor & Wandering Return',
    'rationale':
        'Stabilizes attention on a single chosen anchor and normalizes mind-wandering as the natural workout of mindfulness.',
    'example':
        '“Wandering is natural. The moment you realize you were distracted IS the moment of mindfulness. Gently returning.”',
  },
  'S09': {
    'phase': 'Phase 3: Core Practice & State Cultivation',
    'title': 'Open Awareness & Decentering',
    'rationale':
        'Broadens attention from a single point to wide, sky-like observation of thoughts, feelings, and sensations passing without attachment.',
    'example':
        '“Expanding your awareness to whatever arises in this moment—thoughts, feelings, or sensations—watching them pass like clouds.”',
  },
  'S10': {
    'phase': 'Phase 3: Core Practice & State Cultivation',
    'title': 'Mental Noting & Labeling',
    'rationale':
        'Introduces gentle mental labels (such as "thinking", "worrying", or "planning") to create cognitive distance and reduce emotional reactivity.',
    'example':
        '“If a strong emotion arises, silently naming it with a soft inner voice—such as \'thinking\', \'worrying\', or \'planning\'.”',
  },
  'S11': {
    'phase': 'Phase 3: Core Practice & State Cultivation',
    'title': 'Metta / Loving-Kindness',
    'rationale':
        'Generates intentional warmth, self-compassion, and silent benevolent wishes to stimulate pro-social calm and soften the inner critic.',
    'example':
        '“Offering yourself these silent phrases: May I be safe. May I be peaceful. May I live with ease.”',
  },
  'S12': {
    'phase': 'Phase 4: Deep Integration Silence',
    'title': 'Silent Integration Window',
    'rationale':
        'Provides an extended unguided silence period so the nervous system can assimilate the practice without cognitive instruction.',
    'example': '“Resting in unguided open awareness”',
  },
  'S13': {
    'phase': 'Phase 5: Re-Orientation, Meaning & Close',
    'title': 'Somatic Re-Awakening',
    'rationale':
        'Gradually re-introduces micro-movements in fingers and toes and deeper breaths to prevent post-meditation disorientation or lethargy.',
    'example':
        '“Gradually bringing small movements into your fingers and toes. Taking a slightly deeper breath as you re-orient to the room.”',
  },
  'S14': {
    'phase': 'Phase 5: Re-Orientation, Meaning & Close',
    'title': 'Gratitude & Meaning Transfer',
    'rationale':
        'Bridges internal somatic calm into everyday life through self-appreciation and gratitude for taking time to practice.',
    'example':
        '“Acknowledging yourself for taking this dedicated time today for your mental well-being and presence.”',
  },
  'S15': {
    'phase': 'Phase 5: Re-Orientation, Meaning & Close',
    'title': 'Visual Orientation',
    'rationale':
        'Gently re-introduces light and visual room awareness as the formal meditation container prepares to close.',
    'example':
        '“And as we prepare to close... gently letting the light back in, allowing the eyes to flutter open, and just reorienting to the physical space around you.”',
  },
  'S16': {
    'phase': 'Phase 5: Re-Orientation, Meaning & Close',
    'title': 'Closing Bell & Transition',
    'rationale':
        'Delivers the resonant acoustic bell overlapped with a final closing reminder to carry quiet presence into the rest of the day.',
    'example': '“Remembering that the practice doesn\'t end simply because a bell rings”',
  },
};

/// Unified PracticeConfig data model
class PracticeConfig {
  final String id;
  final String name;
  final String subtitle;
  final bool isSystem;
  final bool isIncluded;
  final List<String> segmentIds;

  PracticeConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    this.isSystem = false,
    this.isIncluded = true,
    required List<String> segmentIds,
  }) : segmentIds = List<String>.unmodifiable(
          List<String>.from(segmentIds)..sort((a, b) => a.compareTo(b)),
        );

  PracticeConfig copyWith({
    String? id,
    String? name,
    String? subtitle,
    bool? isSystem,
    bool? isIncluded,
    List<String>? segmentIds,
  }) {
    return PracticeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      isSystem: isSystem ?? this.isSystem,
      isIncluded: isIncluded ?? this.isIncluded,
      segmentIds: segmentIds ?? this.segmentIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'isSystem': isSystem,
        'isIncluded': isIncluded,
        'segmentIds': segmentIds,
      };

  factory PracticeConfig.fromJson(Map<String, dynamic> json) {
    final rawSegments = (json['segmentIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    return PracticeConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      isSystem: json['isSystem'] as bool? ?? false,
      isIncluded: json['isIncluded'] as bool? ?? true,
      segmentIds: rawSegments,
    );
  }

  /// The 4 official System Practices
  static List<PracticeConfig> get defaultPractices => [
        PracticeConfig(
          id: 'focused_calm',
          name: 'Focused Calm',
          subtitle:
              'Attentional stability, cognitive decelerating, interoceptive grounding.',
          isSystem: true,
          isIncluded: true,
          segmentIds: [
            'S01',
            'S02',
            'S03',
            'S04',
            'S06',
            'S07',
            'S08',
            'S12',
            'S13',
            'S15',
            'S16',
          ],
        ),
        PracticeConfig(
          id: 'trauma_informed',
          name: 'Trauma-Sensitive Grounding',
          subtitle:
              'High agency, down-regulation, safety anchoring, bypasses forced breathwork.',
          isSystem: true,
          isIncluded: true,
          segmentIds: [
            'S01',
            'S02',
            'S04',
            'S05',
            'S07',
            'S08',
            'S10',
            'S12',
            'S13',
            'S14',
            'S15',
            'S16',
          ],
        ),
        PracticeConfig(
          id: 'open_awareness',
          name: 'Open Awareness / Insight',
          subtitle:
              'Decentering, metacognition, cognitive defusion, spacious perspective.',
          isSystem: true,
          isIncluded: true,
          segmentIds: [
            'S01',
            'S02',
            'S03',
            'S04',
            'S08',
            'S09',
            'S10',
            'S12',
            'S13',
            'S15',
            'S16',
          ],
        ),
        PracticeConfig(
          id: 'metta_compassion',
          name: 'Metta / Compassion',
          subtitle:
              'Ventral vagal activation, pro-social warmth, inner critic reduction.',
          isSystem: true,
          isIncluded: true,
          segmentIds: [
            'S01',
            'S02',
            'S03',
            'S04',
            'S07',
            'S11',
            'S12',
            'S13',
            'S14',
            'S15',
            'S16',
          ],
        ),
      ];

  /// Creates a PracticeConfig from a ClinicalArchetype
  factory PracticeConfig.fromArchetype(ClinicalArchetype archetype) {
    final defaults = defaultPractices;
    final match = defaults.cast<PracticeConfig?>().firstWhere(
          (p) => p?.id == archetype.id || p?.name == archetype.title,
          orElse: () => null,
        );
    if (match != null) return match;

    return PracticeConfig(
      id: archetype.id,
      name: archetype.title,
      subtitle: archetype.subtitle,
      isSystem: true,
      isIncluded: true,
      segmentIds: archetype.pipeline.map((s) => s.code).toList(),
    );
  }
}
