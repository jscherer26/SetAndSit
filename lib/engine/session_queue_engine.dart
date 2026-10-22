import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../services/audio_manifest_service.dart';

class SessionQueueEngine {
  static final Random _random = Random();

  /// Protected frame segments never pruned in sessions >= 5 minutes.
  static const List<String> protectedFrame = [
    'S01',
    'S02',
    'S12',
    'S13',
    'S15',
    'S16',
  ];

  /// Pruning priority order (dropped one-by-one in this exact order when silence gaps are too tight).
  static const List<String> pruningPriorityOrder = [
    'S14',
    'S06',
    'S04',
    'S03',
    'S07',
    'S10',
    'S08',
  ];

  /// Returns the protected signature pair for a clinical archetype.
  static List<String> getProtectedSignaturePair(ClinicalArchetype archetype) {
    switch (archetype) {
      case ClinicalArchetype.focusedCalm:
        return const ['S03', 'S08'];
      case ClinicalArchetype.traumaInformed:
        return const ['S04', 'S05'];
      case ClinicalArchetype.openAwareness:
        return const ['S08', 'S09'];
      case ClinicalArchetype.mettaCompassion:
        return const ['S04', 'S11'];
    }
  }

  /// Returns the protected signature pair for a PracticeConfig (system or custom).
  static List<String> getProtectedSignaturePairForPractice(PracticeConfig practice) {
    if (practice.isSystem) {
      final arch = ClinicalArchetype.values.cast<ClinicalArchetype?>().firstWhere(
        (a) => a?.id == practice.id || a?.title == practice.name,
        orElse: () => null,
      );
      if (arch != null) {
        return getProtectedSignaturePair(arch);
      }
    }
    // For Custom practices: take the LAST 2 active segments (or single if only one)
    // within the S03-S11 range of that custom practice's segmentIds.
    final zone2Segments = practice.segmentIds
        .where((id) => id.compareTo('S03') >= 0 && id.compareTo('S11') <= 0)
        .toList();
    if (zone2Segments.length <= 2) {
      return zone2Segments;
    }
    return zone2Segments.sublist(zone2Segments.length - 2);
  }

  /// Returns the primary signature segment for ultra-short test mode (<= 120s).
  static ClinicalSegment getPrimarySignatureSegment(ClinicalArchetype archetype) {
    switch (archetype) {
      case ClinicalArchetype.focusedCalm:
        return ClinicalSegment.S08;
      case ClinicalArchetype.traumaInformed:
        return ClinicalSegment.S04;
      case ClinicalArchetype.openAwareness:
        return ClinicalSegment.S09;
      case ClinicalArchetype.mettaCompassion:
        return ClinicalSegment.S11;
    }
  }

  /// Returns the primary signature segment for a PracticeConfig in ultra-short mode.
  static ClinicalSegment getPrimarySignatureSegmentForPractice(PracticeConfig practice) {
    if (practice.isSystem) {
      final arch = ClinicalArchetype.values.cast<ClinicalArchetype?>().firstWhere(
        (a) => a?.id == practice.id || a?.title == practice.name,
        orElse: () => null,
      );
      if (arch != null) {
        return getPrimarySignatureSegment(arch);
      }
    }
    // For Custom practices: use the last active segment in S03-S11
    final zone2 = practice.segmentIds
        .where((id) => id.compareTo('S03') >= 0 && id.compareTo('S11') <= 0)
        .toList();
    if (zone2.isNotEmpty) {
      return ClinicalSegment.fromCode(zone2.last);
    }
    return ClinicalSegment.S08;
  }

  /// Returns whether a segment belongs to Zone 2 (S03 through S11).
  static bool isZone2(ClinicalSegment seg) {
    return seg.code.compareTo('S03') >= 0 && seg.code.compareTo('S11') <= 0;
  }

  /// Returns the relative weight for a Zone 2 segment.
  /// Settling segments (S03-S07): 1.0; Core Practice segments (S08-S11): 1.5.
  static double getZone2Weight(ClinicalSegment seg) {
    switch (seg) {
      case ClinicalSegment.S03:
      case ClinicalSegment.S04:
      case ClinicalSegment.S05:
      case ClinicalSegment.S06:
      case ClinicalSegment.S07:
        return 1.0;
      case ClinicalSegment.S08:
      case ClinicalSegment.S09:
      case ClinicalSegment.S10:
      case ClinicalSegment.S11:
        return 1.5;
      default:
        return 0.0;
    }
  }

  /// Returns the Zone label for debug logging.
  static String getZoneLabel(ClinicalSegment seg) {
    if (seg == ClinicalSegment.S12) {
      return 'Zone 3';
    } else if (isZone2(seg)) {
      return 'Zone 2';
    } else {
      return 'Zone 1';
    }
  }

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

  /// Generates a clinical guided session queue based on the selected Archetype/Practice,
  /// voice persona, exact end-time duration, and 3-Zone Silence & Pruning Engine.
  /// Dual-player overlap is used for S16 (bell strikes first, voice triggers at +2.5s).
  static List<SessionItem> generateGuidedSessionQueue({
    required int targetDurationSeconds,
    PracticeConfig? practice,
    ClinicalArchetype? archetype,
    required String voicePersona, // 'kia' or 'grace'
    required AudioSegment selectedBell,
  }) {
    final effectivePractice = practice ??
        (archetype != null
            ? PracticeConfig.fromArchetype(archetype)
            : PracticeConfig.defaultPractices.first);

    final vNorm = voicePersona.toLowerCase() == 'grace' ? 'grace' : 'kia';
    const s16OverlapDelaySec = 2.5;

    final sigPair = getProtectedSignaturePairForPractice(effectivePractice);
    final prunedSegments = <String>[];
    final selectedVariants = <ClinicalSegment, ScriptVariant>{};
    final postSilenceMap = <ClinicalSegment, int>{};
    List<ClinicalSegment> activeSegments;

    double calcTotalAudio(List<ClinicalSegment> segs) {
      var total = 0.0;
      for (final seg in segs) {
        final variant = selectedVariants[seg]!;
        final dur = AudioManifestService.getAudioDuration(
          voice: vNorm,
          segmentCode: seg.code,
          variantId: variant.variantId,
        );
        total += dur;
      }
      if (segs.contains(ClinicalSegment.S16)) {
        total += s16OverlapDelaySec;
      }
      return total;
    }

    double calcTotalZone1(List<ClinicalSegment> segs) {
      var total = 0.0;
      for (final seg in segs) {
        if (seg.code == 'S01' || seg.code == 'S02' || seg.code == 'S13' || seg.code == 'S14') {
          total += 8.0;
        } else if (seg.code == 'S15') {
          total += 5.0;
        }
      }
      return total;
    }

    if (targetDurationSeconds < 300) {
      // --- Section 4: Test Mode Bypass for Ultra-Short Sessions (< 300s) ---
      if (targetDurationSeconds <= 120) {
        final primarySig = getPrimarySignatureSegmentForPractice(effectivePractice);
        activeSegments = [
          ClinicalSegment.S01,
          primarySig,
          ClinicalSegment.S12,
          ClinicalSegment.S16,
        ];
      } else {
        final fullPipeline = effectivePractice.segmentIds
            .map((c) => ClinicalSegment.fromCode(c))
            .toList();
        activeSegments = fullPipeline
            .where((s) => protectedFrame.contains(s.code) || sigPair.contains(s.code))
            .toList();
      }

      for (final seg in activeSegments) {
        final variants = AudioManifestService.getVariantsForSegment(seg.code);
        if (variants.isEmpty) {
          selectedVariants[seg] = ScriptVariant(
            variantId: 'v01',
            variantName: '${seg.code} Standard',
            active: true,
            text: '',
            wordCount: 15,
          );
        } else {
          selectedVariants[seg] = variants[_random.nextInt(variants.length)];
        }
      }

      final totalAudioSeconds = calcTotalAudio(activeSegments);
      final silencePool = max(0.0, targetDurationSeconds - totalAudioSeconds);

      double getShortSessionWeight(ClinicalSegment seg) {
        if (seg == ClinicalSegment.S16) return 0.0;
        if (seg == ClinicalSegment.S12) return 3.0;
        if (sigPair.contains(seg.code)) return 2.0;
        return 1.0; // Framing segments: S01, S02, S13, S14, S15
      }

      final totalWeight = activeSegments.fold<double>(
        0.0,
        (sum, seg) => sum + getShortSessionWeight(seg),
      );

      var assignedOtherSilence = 0;
      for (final seg in activeSegments) {
        if (seg == ClinicalSegment.S12) continue;
        if (seg == ClinicalSegment.S16) {
          postSilenceMap[seg] = 0;
          continue;
        }
        final w = getShortSessionWeight(seg);
        final silence = totalWeight > 0 ? (silencePool * (w / totalWeight)).round() : 0;
        postSilenceMap[seg] = silence;
        assignedOtherSilence += silence;
      }

      if (activeSegments.contains(ClinicalSegment.S12)) {
        final s12Silence = max(
          0,
          (targetDurationSeconds - totalAudioSeconds - assignedOtherSilence).round(),
        );
        postSilenceMap[ClinicalSegment.S12] = s12Silence;
      }
    } else {
      // --- Sessions >= 5 Minutes (>= 300s) ---
      activeSegments = effectivePractice.segmentIds
          .map((c) => ClinicalSegment.fromCode(c))
          .toList();

      for (final seg in activeSegments) {
        final variants = AudioManifestService.getVariantsForSegment(seg.code);
        if (variants.isEmpty) {
          selectedVariants[seg] = ScriptVariant(
            variantId: 'v01',
            variantName: '${seg.code} Standard',
            active: true,
            text: '',
            wordCount: 15,
          );
        } else {
          selectedVariants[seg] = variants[_random.nextInt(variants.length)];
        }
      }

      var totalAudioSeconds = calcTotalAudio(activeSegments);
      var totalZone1Seconds = calcTotalZone1(activeSegments);
      var dynamicSilencePool = targetDurationSeconds - totalAudioSeconds - totalZone1Seconds;
      var zone2Pool = dynamicSilencePool * 0.68;
      var activeZone2 = activeSegments.where((s) => isZone2(s)).toList();

      // Pruning Loop Check (halting when activeZone2.length <= 1 prevents division-by-zero)
      while (activeZone2.length > 1 && (zone2Pool / activeZone2.length) < 60.0) {
        ClinicalSegment? toPrune;
        for (final code in pruningPriorityOrder) {
          if (protectedFrame.contains(code) || sigPair.contains(code)) continue;
          final candidate = activeSegments.cast<ClinicalSegment?>().firstWhere(
            (s) => s?.code == code,
            orElse: () => null,
          );
          if (candidate != null) {
            toPrune = candidate;
            break;
          }
        }

        if (toPrune == null) {
          break; // No more prunable segments available
        }

        activeSegments.remove(toPrune);
        prunedSegments.add(toPrune.code);

        totalAudioSeconds = calcTotalAudio(activeSegments);
        totalZone1Seconds = calcTotalZone1(activeSegments);
        dynamicSilencePool = targetDurationSeconds - totalAudioSeconds - totalZone1Seconds;
        zone2Pool = dynamicSilencePool * 0.68;
        activeZone2 = activeSegments.where((s) => isZone2(s)).toList();
      }

      // Final Silence Assignment
      dynamicSilencePool = max(0.0, targetDurationSeconds - totalAudioSeconds - totalZone1Seconds);
      zone2Pool = dynamicSilencePool * 0.68;
      final sumOfActiveZone2Weights = activeZone2.fold<double>(
        0.0,
        (sum, s) => sum + getZone2Weight(s),
      );

      var assignedOtherSilence = 0;
      for (final seg in activeSegments) {
        if (seg == ClinicalSegment.S12) continue;
        if (seg == ClinicalSegment.S16) {
          postSilenceMap[seg] = 0;
          continue;
        }

        int silence;
        if (seg.code == 'S01' || seg.code == 'S02' || seg.code == 'S13' || seg.code == 'S14') {
          silence = 8;
        } else if (seg.code == 'S15') {
          silence = 5;
        } else if (isZone2(seg)) {
          final segWeight = getZone2Weight(seg);
          silence = sumOfActiveZone2Weights > 0
              ? (zone2Pool * (segWeight / sumOfActiveZone2Weights)).round()
              : 0;
        } else {
          silence = 0;
        }
        postSilenceMap[seg] = silence;
        assignedOtherSilence += silence;
      }

      // Zone 3: S12 absorbs remaining dynamic silence pool to guarantee exact duration match
      if (activeSegments.contains(ClinicalSegment.S12)) {
        final s12Silence = max(
          0,
          (targetDurationSeconds - totalAudioSeconds - assignedOtherSilence).round(),
        );
        postSilenceMap[ClinicalSegment.S12] = s12Silence;
      }
    }

    // --- Section 5: Debug Logging ---
    var totalCalculatedSec = 0.0;
    for (final seg in activeSegments) {
      final variant = selectedVariants[seg]!;
      final voiceDur = AudioManifestService.getAudioDuration(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );
      final dur = seg == ClinicalSegment.S16 ? s16OverlapDelaySec + voiceDur : voiceDur;
      final silence = postSilenceMap[seg] ?? 0;
      totalCalculatedSec += dur + silence;
    }

    debugPrint('=== SessionQueueEngine Queue Generated ===');
    debugPrint('Selected Archetype: ${effectivePractice.name} | Target Duration: ${targetDurationSeconds}s');
    debugPrint('Pruned Segments: ${prunedSegments.isEmpty ? 'None' : prunedSegments.join(', ')}');
    debugPrint('Final Ordered Segment List:');
    for (final seg in activeSegments) {
      final variant = selectedVariants[seg]!;
      final voiceDur = AudioManifestService.getAudioDuration(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );
      final dur = seg == ClinicalSegment.S16 ? s16OverlapDelaySec + voiceDur : voiceDur;
      final silence = (postSilenceMap[seg] ?? 0).toDouble();
      final zone = getZoneLabel(seg);
      debugPrint('  [${seg.code}_${variant.variantId}] Audio: ${dur.toStringAsFixed(1)}s | Post-SilenceGap: ${silence.toStringAsFixed(1)}s ($zone)');
    }
    debugPrint('Total Calculated Duration: ${totalCalculatedSec.toStringAsFixed(1)}s vs. Target Duration: ${targetDurationSeconds}s');

    // --- Construct Final Playback Queue ---
    final queue = <SessionItem>[];
    for (final seg in activeSegments) {
      final variant = selectedVariants[seg]!;
      final assetPath = AudioManifestService.getAudioAssetPath(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );
      final voiceDur = AudioManifestService.getAudioDuration(
        voice: vNorm,
        segmentCode: seg.code,
        variantId: variant.variantId,
      );
      final varNum = _extractVariantNumber(variant.variantId, variant.variantName);

      if (seg == ClinicalSegment.S16) {
        queue.add(PlayAudioItem(
          id: 'S16_${variant.variantId}',
          displayTitle: 'Closing Guidance ($varNum)',
          phaseName: 'Re-Orientation & Close',
          audioAssetPath: assetPath,
          durationSeconds: s16OverlapDelaySec + voiceDur,
          segment: ClinicalSegment.S16,
          text: variant.cleanText,
          bellAssetPath: selectedBell.filePath,
        ));
      } else {
        queue.add(PlayAudioItem(
          id: '${seg.code}_${variant.variantId}',
          displayTitle: '${seg.title} ($varNum)',
          phaseName: seg.phase,
          audioAssetPath: assetPath,
          durationSeconds: voiceDur,
          segment: seg,
          text: variant.cleanText,
        ));
      }

      final postSilence = postSilenceMap[seg] ?? 0;
      if (postSilence > 0) {
        queue.add(PauseSilenceItem(
          postSilence,
          displayTitle: _getSilenceTitle(seg),
          phaseName: _getSilencePhase(seg),
        ));
      }
    }

    return queue;
  }

  static String _getSilenceTitle(ClinicalSegment seg) {
    if (seg == ClinicalSegment.S12) {
      return 'Deep Integration Silence';
    } else if (seg == ClinicalSegment.S15) {
      return 'Pre-Bell Silence';
    }
    return 'Settling with Guidance';
  }

  static String _getSilencePhase(ClinicalSegment seg) {
    if (seg == ClinicalSegment.S12) {
      return 'Deep Silence';
    } else if (seg == ClinicalSegment.S15) {
      return 'Re-Orientation & Close';
    }
    return seg.phase;
  }

  /// Extracts clean variation number (e.g. "10" from "10. Simple Concludes" or "v10")
  static String _extractVariantNumber(String variantId, String variantName) {
    final match = RegExp(r'^(\d+)').firstMatch(variantName.trim());
    if (match != null) {
      return match.group(1)!;
    }
    final numOnly = int.tryParse(variantId.replaceFirst(RegExp(r'^[vV]'), ''));
    if (numOnly != null) {
      return numOnly.toString();
    }
    return variantId;
  }
}
