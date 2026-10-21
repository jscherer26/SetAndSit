import 'dart:math';
import '../models/audio_models.dart';
import '../services/audio_manifest_service.dart';

class SessionQueueEngine {
  static final Random _random = Random();

  /// Generates a silent session with only an ending bell.
  /// (Opening bell removed as meditations do not start with a bell).
  static List<SessionItem> generateSilentSessionQueue({
    required int targetDurationSeconds,
    required AudioSegment selectedBell,
  }) {
    final endingBellDuration = selectedBell.durationSeconds.toDouble();

    // The silent practice runs for the duration minus the ending bell
    final silenceSeconds = max(
      0,
      targetDurationSeconds - endingBellDuration.round(),
    );

    final queue = <SessionItem>[];
    if (silenceSeconds > 0) {
      queue.add(PauseSilenceItem(
        silenceSeconds,
        displayTitle: 'Silent Formal Practice',
        phaseName: 'Deep Silence',
      ));
    }

    queue.add(PlayAudioItem(
      id: '${selectedBell.id}_end',
      displayTitle: '${selectedBell.title} (Closing)',
      phaseName: 'Re-Orientation & Close',
      audioAssetPath: selectedBell.filePath,
      durationSeconds: endingBellDuration,
      isBell: true,
    ));

    return queue;
  }

  /// Generates a clinical guided session queue based on the selected Archetype,
  /// voice persona, exact end-time duration, and S13 silence partitioning.
  /// Does NOT start with a bell.
  /// Randomly selects from the 15 variations available for each segment.
  static List<SessionItem> generateGuidedSessionQueue({
    required int targetDurationSeconds,
    required ClinicalArchetype archetype,
    required String voicePersona, // 'kia' or 'grace'
    required AudioSegment selectedBell,
  }) {
    final vNorm = voicePersona.toLowerCase() == 'grace' ? 'grace' : 'kia';

    // For short testing durations (< 180s / 3 minutes):
    // The complete 10-segment clinical pipeline has ~135 seconds of spoken voice and bells alone,
    // which cannot physically fit into under 3 minutes without overflowing or eliminating all silence.
    // An abbreviated pipeline (S01 Arrival, S04 Grounding, S13 Integration Silence, S16 Outro)
    // provides an authentic practice experience that fits test windows cleanly.
    final List<ClinicalSegment> pipeline = targetDurationSeconds < 180
        ? const [
            ClinicalSegment.S01,
            ClinicalSegment.S04,
            ClinicalSegment.S13,
            ClinicalSegment.S16,
          ]
        : archetype.pipeline;

    // 1. Randomly select from the 15 variants for each segment in the pipeline
    final selectedVariants = <ClinicalSegment, ScriptVariant>{};
    for (final seg in pipeline) {
      if (seg == ClinicalSegment.S13) continue; // S13 is integration silence

      final variants = AudioManifestService.getVariantsForSegment(seg.code);
      if (variants.isEmpty) {
        selectedVariants[seg] = ScriptVariant(
          variantId: 'v01',
          variantName: '${seg.code} Standard',
          active: true,
          text: '',
          wordCount: 15,
        );
        continue;
      }

      // Randomly select one of the variations for this segment
      selectedVariants[seg] = variants[_random.nextInt(variants.length)];
    }

    // 2. Pre-closing guidance duration (all segments except S13 and S16)
    var preClosingGuidanceSec = 0.0;
    final preClosingSegments = pipeline.where(
      (s) => s != ClinicalSegment.S13 && s != ClinicalSegment.S16,
    ).toList();

    for (final seg in preClosingSegments) {
      final variant = selectedVariants[seg]!;
      final dur = AudioManifestService.getAudioDuration(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );
      preClosingGuidanceSec += dur;
    }

    // 3. Closing unit: 4.0s Pre-Bell Silence + Closing Bell + 2.0s Pause + S16 Vocal Outro + 3.0s Closing Stillness
    final closingBellSec = selectedBell.durationSeconds.toDouble();

    final s16Variant = selectedVariants[ClinicalSegment.S16] ??
        ScriptVariant(
          variantId: 'v01',
          variantName: 'Closing',
          active: true,
          text: '',
          wordCount: 10,
        );
    final s16Sec = AudioManifestService.getAudioDuration(
      voice: vNorm,
      segmentCode: 'S16',
      variantId: s16Variant.variantId,
    );

    const preClosingBellSilenceSec = 4;
    const s16PauseBetweenBellAndVoice = 2;
    const postS16SilenceSec = 3; // 3 seconds of final silence after S16 completes
    final closingUnitSec = preClosingBellSilenceSec +
        closingBellSec +
        s16PauseBetweenBellAndVoice +
        s16Sec +
        postS16SilenceSec;

    // Intentional 4-second settling pause before S01 begins
    const settlePauseSec = 4;

    // 4. Calculate micro-pauses between guidance segments
    // Micro-pauses occur between pre-closing guidance segments
    final numTransitions = max(0, preClosingSegments.length - 1);
    int pSegment;
    if (targetDurationSeconds <= 300) {
      pSegment = 2;
    } else if (targetDurationSeconds <= 900) {
      pSegment = 6;
    } else {
      pSegment = 14;
    }

    // 5. Dynamic S13 silence calculation:
    // S13 absorbs the remaining budget so total queue duration precisely matches targetDurationSeconds
    final fixedWithoutS13 = settlePauseSec +
        preClosingGuidanceSec +
        (numTransitions * pSegment) +
        closingUnitSec;
    final s13SilenceSec = max(0, (targetDurationSeconds - fixedWithoutS13).round());

    // 6. Construct Final Queue
    final queue = <SessionItem>[];

    // Enforce intentional 4.0s silent settling pause before S01
    queue.add(PauseSilenceItem(
      settlePauseSec,
      displayTitle: 'Settling into Practice',
      phaseName: 'Arrival & Agency',
    ));
    var preClosingCount = 0;
    for (var i = 0; i < pipeline.length; i++) {
      final seg = pipeline[i];

      if (seg == ClinicalSegment.S13) {
        if (s13SilenceSec > 0) {
          queue.add(PauseSilenceItem(
            s13SilenceSec,
            displayTitle: 'Deep Integration Silence',
            phaseName: 'Deep Silence',
          ));
        }
        continue;
      }

      if (seg == ClinicalSegment.S16) {
        // Handled in closing sequence
        continue;
      }

      final variant = selectedVariants[seg]!;
      final assetPath = AudioManifestService.getAudioAssetPath(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );
      final dur = AudioManifestService.getAudioDuration(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );

      queue.add(PlayAudioItem(
        id: '${seg.code}_${variant.variantId}',
        displayTitle: '${seg.title} (${variant.variantName})',
        phaseName: seg.phase,
        audioAssetPath: assetPath,
        durationSeconds: dur,
        segment: seg,
      ));

      preClosingCount++;
      // Add micro-pause between guidance segments (after every segment except the last one before S13/closing)
      if (preClosingCount < preClosingSegments.length) {
        queue.add(PauseSilenceItem(
          pSegment,
          displayTitle: 'Settling with Guidance',
          phaseName: seg.phase,
        ));
      }
    }

    // 4.0s silence immediately before the closing bell
    queue.add(PauseSilenceItem(
      preClosingBellSilenceSec,
      displayTitle: 'Pre-Bell Silence',
      phaseName: 'Re-Orientation & Close',
    ));

    // S16 Closing Sequence: Closing Bell -> 2.0s Pause -> S16 Vocal Outro
    queue.add(PlayAudioItem(
      id: '${selectedBell.id}_closing',
      displayTitle: '${selectedBell.title} (Closing)',
      phaseName: 'Re-Orientation & Close',
      audioAssetPath: selectedBell.filePath,
      durationSeconds: closingBellSec,
      isBell: true,
    ));

    queue.add(PauseSilenceItem(
      s16PauseBetweenBellAndVoice,
      displayTitle: 'Final Stillness',
      phaseName: 'Re-Orientation & Close',
    ));

    final s16Path = AudioManifestService.getAudioAssetPath(
      voice: vNorm,
      segmentCode: 'S16',
      variantId: s16Variant.variantId,
    );
    queue.add(PlayAudioItem(
      id: 'S16_${s16Variant.variantId}',
      displayTitle: 'Closing Guidance (${s16Variant.variantName})',
      phaseName: 'Re-Orientation & Close',
      audioAssetPath: s16Path,
      durationSeconds: s16Sec,
      segment: ClinicalSegment.S16,
    ));

    // 3.0s buffer of silence at the very end so S16 vocal outro completes without being cut off
    queue.add(PauseSilenceItem(
      postS16SilenceSec,
      displayTitle: 'Closing Stillness',
      phaseName: 'Re-Orientation & Close',
    ));

    return queue;
  }
}
