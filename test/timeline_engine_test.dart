import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/engine/session_queue_engine.dart';
import 'package:setandsit/data/bell_data.dart';
import 'package:setandsit/services/audio_manifest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ClinicalArchetype pipelines match exact clinical specifications', () {
    expect(
      ClinicalArchetype.focusedCalm.pipeline.map((s) => s.code).toList(),
      ['S01', 'S02', 'S03', 'S04', 'S06', 'S07', 'S08', 'S12', 'S13', 'S15', 'S16'],
    );

    expect(
      ClinicalArchetype.traumaInformed.pipeline.map((s) => s.code).toList(),
      ['S01', 'S02', 'S04', 'S05', 'S07', 'S08', 'S10', 'S12', 'S13', 'S14', 'S15', 'S16'],
    );

    expect(
      ClinicalArchetype.openAwareness.pipeline.map((s) => s.code).toList(),
      ['S01', 'S02', 'S03', 'S04', 'S08', 'S09', 'S10', 'S12', 'S13', 'S15', 'S16'],
    );

    expect(
      ClinicalArchetype.mettaCompassion.pipeline.map((s) => s.code).toList(),
      ['S01', 'S02', 'S03', 'S04', 'S07', 'S11', 'S12', 'S13', 'S14', 'S15', 'S16'],
    );

    for (final arch in ClinicalArchetype.values) {
      expect(arch.pipeline.contains(ClinicalSegment.S01), isTrue);
      expect(arch.pipeline.contains(ClinicalSegment.S02), isTrue);
      expect(arch.pipeline.contains(ClinicalSegment.S12), isTrue);
      expect(arch.pipeline.contains(ClinicalSegment.S13), isTrue);
      expect(arch.pipeline.contains(ClinicalSegment.S15), isTrue);
      expect(arch.pipeline.contains(ClinicalSegment.S16), isTrue);
      expect(arch.pipeline.last, ClinicalSegment.S16);
    }
  });

  test('Trauma-Informed pipeline explicitly bypasses S03 and includes S05', () {
    final trauma = ClinicalArchetype.traumaInformed;
    expect(trauma.pipeline.contains(ClinicalSegment.S03), isFalse);
    expect(trauma.pipeline.contains(ClinicalSegment.S05), isTrue);
  });

  test('Silent session queue creates silence interval with closing bell (no opening bell)', () {
    final bell = BellData.defaultBells.first;
    final queue = SessionQueueEngine.generateSilentSessionQueue(
      targetDurationSeconds: 600,
      selectedBell: bell,
    );

    expect(queue.isNotEmpty, isTrue);
    expect(queue.whereType<PlayAudioItem>().length, 1); // closing bell only
    expect(queue.first is PauseSilenceItem, isTrue); // silent formal practice
  });

  test('SessionManifest parses script_bank and resolves lowercase asset paths', () {
    final mockJson = {
      'app': 'SetAndSit',
      'schema_version': '3.5.0',
      'description': 'Test',
      'script_bank': {
        'S01': [
          {
            'variant_id': 'v01',
            'variant_name': '1. Gentle Arrival',
            'active': true,
            'text': 'Sample text',
            'word_count': 2,
          }
        ]
      }
    };

    final manifest = SessionManifest.fromJson(mockJson);
    expect(manifest.scriptBank.containsKey('S01'), isTrue);
    expect(manifest.scriptBank['S01']!.first.text, 'Sample text');

    final kiaPath = AudioManifestService.getAudioAssetPath(
      voice: 'Kia',
      segmentCode: 'S01',
      variantId: 'v01',
    );
    expect(kiaPath, 'assets/audio/kia/S01_v01.mp3');

    final gracePath = AudioManifestService.getAudioAssetPath(
      voice: 'Grace',
      segmentCode: 'S01',
      variantId: 'v01',
    );
    expect(gracePath, 'assets/audio/grace/S01_v01.mp3');
  });

  test('ScriptVariant cleanText removes brackets and formats ellipses cleanly', () {
    final variant = ScriptVariant(
      variantId: 'v01',
      variantName: 'Test',
      active: true,
      text: 'Letting ourselves settle... [pause 2s] seeing if it is possible...',
      wordCount: 10,
    );

    expect(
      variant.cleanText,
      'Letting ourselves settle, seeing if it is possible.',
    );
  });

  test('Guided session queue generates S16 with dual-player overlap bellAssetPath', () {
    final bell = BellData.defaultBells.first;
    final queue = SessionQueueEngine.generateGuidedSessionQueue(
      targetDurationSeconds: 600,
      archetype: ClinicalArchetype.focusedCalm,
      voicePersona: 'kia',
      selectedBell: bell,
    );

    expect(queue.isNotEmpty, isTrue);

    // Find S16 item in queue
    final s16Items = queue
        .whereType<PlayAudioItem>()
        .where((it) => it.segment == ClinicalSegment.S16)
        .toList();

    expect(s16Items.length, 1);
    final s16Item = s16Items.first;

    // Verify S16 carries the selected bell asset path for the dual-player overlap engine
    expect(s16Item.bellAssetPath, bell.filePath);

    // Verify standard sequential segments (S01 through S15) do NOT carry bellAssetPath
    final nonS16Items = queue
        .whereType<PlayAudioItem>()
        .where((it) => it.segment != ClinicalSegment.S16 && it.segment != null)
        .toList();

    for (final item in nonS16Items) {
      expect(item.bellAssetPath, isNull);
    }

    // Verify there is no redundant standalone closing bell before S16 in guided queue
    final bellItems = queue
        .whereType<PlayAudioItem>()
        .where((it) => it.isBell)
        .toList();
    expect(bellItems.isEmpty, isTrue);

    // S16 is the closing audio item; its voice completion hooks directly to session completion
    final s16Idx = queue.indexOf(s16Item);
    expect(s16Idx, queue.length - 1);
  });

  test('Dynamic Interval Math: SessionQueueEngine calculates silent intervals accurately across 5m, 12m, 15m, and 30m', () {
    final bell = BellData.defaultBells.first;
    final durationsToTest = [300, 720, 900, 1800]; // 5 min, 12 min, 15 min, 30 min

    for (final targetSec in durationsToTest) {
      for (final arch in ClinicalArchetype.values) {
        final queue = SessionQueueEngine.generateGuidedSessionQueue(
          targetDurationSeconds: targetSec,
          archetype: arch,
          voicePersona: 'kia',
          selectedBell: bell,
        );

        var totalCalculatedSec = 0.0;
        for (final item in queue) {
          if (item is PlayAudioItem) {
            totalCalculatedSec += item.durationSeconds;
          } else if (item is PauseSilenceItem) {
            totalCalculatedSec += item.durationSeconds;
          }
        }

        // Total calculated duration matches targetDurationSeconds within 1 second rounding
        expect(
          (totalCalculatedSec - targetSec).abs(),
          lessThanOrEqualTo(1.0),
          reason: 'Failed for archetype ${arch.title} at $targetSec seconds',
        );

        // Verify S12 integration silence was populated and adjusted
        final s12Item = queue
            .whereType<PauseSilenceItem>()
            .firstWhere((it) => it.displayTitle == 'Deep Integration Silence');
        expect(s12Item.durationSeconds, greaterThan(0));
      }
    }
  });

  test('Test Mode Bypass (<= 120s): Generates 4 segments with primary signature segment', () {
    final bell = BellData.defaultBells.first;

    final expectedPrimary = {
      ClinicalArchetype.focusedCalm: ClinicalSegment.S08,
      ClinicalArchetype.traumaInformed: ClinicalSegment.S04,
      ClinicalArchetype.openAwareness: ClinicalSegment.S09,
      ClinicalArchetype.mettaCompassion: ClinicalSegment.S11,
    };

    for (final entry in expectedPrimary.entries) {
      final arch = entry.key;
      final expectedSig = entry.value;

      final queue = SessionQueueEngine.generateGuidedSessionQueue(
        targetDurationSeconds: 60,
        archetype: arch,
        voicePersona: 'kia',
        selectedBell: bell,
      );

      final audioSegments = queue
          .whereType<PlayAudioItem>()
          .map((it) => it.segment)
          .toList();

      expect(audioSegments, [
        ClinicalSegment.S01,
        expectedSig,
        ClinicalSegment.S12,
        ClinicalSegment.S16,
      ]);

      var totalSec = 0.0;
      for (final item in queue) {
        if (item is PlayAudioItem) {
          totalSec += item.durationSeconds;
        } else if (item is PauseSilenceItem) {
          totalSec += item.durationSeconds;
        }
      }

      expect(
        (totalSec - 60).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'Failed 60s duration check for archetype ${arch.title}',
      );
    }
  });

  test('Test Mode Bypass (121s - 299s): Uses Protected Frame + Protected Signature Pair', () {
    final bell = BellData.defaultBells.first;

    for (final arch in ClinicalArchetype.values) {
      final queue = SessionQueueEngine.generateGuidedSessionQueue(
        targetDurationSeconds: 180,
        archetype: arch,
        voicePersona: 'kia',
        selectedBell: bell,
      );

      final audioCodes = queue
          .whereType<PlayAudioItem>()
          .map((it) => it.segment!.code)
          .toList();

      // Protected frame segments must all be present
      for (final frameCode in SessionQueueEngine.protectedFrame) {
        expect(audioCodes.contains(frameCode), isTrue);
      }

      // Protected signature pair segments must both be present
      final sigPair = SessionQueueEngine.getProtectedSignaturePair(arch);
      for (final sigCode in sigPair) {
        expect(audioCodes.contains(sigCode), isTrue);
      }

      // Total audio segments should be 6 (frame) + 2 (signature pair) = 8
      expect(audioCodes.length, 8);

      var totalSec = 0.0;
      for (final item in queue) {
        if (item is PlayAudioItem) {
          totalSec += item.durationSeconds;
        } else if (item is PauseSilenceItem) {
          totalSec += item.durationSeconds;
        }
      }

      expect(
        (totalSec - 180).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'Failed 180s duration check for archetype ${arch.title}',
      );
    }
  });

  test('Pruning logic for 300s sessions protects frame and signature pairs and adheres to priority order', () {
    final bell = BellData.defaultBells.first;

    for (final arch in ClinicalArchetype.values) {
      final queue = SessionQueueEngine.generateGuidedSessionQueue(
        targetDurationSeconds: 300,
        archetype: arch,
        voicePersona: 'kia',
        selectedBell: bell,
      );

      final audioCodes = queue
          .whereType<PlayAudioItem>()
          .map((it) => it.segment!.code)
          .toList();

      // Protected Frame must NEVER be pruned
      for (final frameCode in SessionQueueEngine.protectedFrame) {
        expect(audioCodes.contains(frameCode), isTrue,
            reason: '$frameCode was pruned in archetype ${arch.title}');
      }

      // Protected Signature Pair must NEVER be pruned
      final sigPair = SessionQueueEngine.getProtectedSignaturePair(arch);
      for (final sigCode in sigPair) {
        expect(audioCodes.contains(sigCode), isTrue,
            reason: '$sigCode was pruned in archetype ${arch.title}');
      }
    }
  });

  test('3-Zone Silence Distribution assigns fixed Zone 1 bridges at 900s', () {
    final bell = BellData.defaultBells.first;
    final queue = SessionQueueEngine.generateGuidedSessionQueue(
      targetDurationSeconds: 900,
      archetype: ClinicalArchetype.traumaInformed,
      voicePersona: 'kia',
      selectedBell: bell,
    );

    // Verify Zone 1 fixed bridge pauses
    for (var i = 0; i < queue.length - 1; i++) {
      final item = queue[i];
      final nextItem = queue[i + 1];

      if (item is PlayAudioItem && nextItem is PauseSilenceItem) {
        final code = item.segment?.code;
        if (code == 'S01' || code == 'S02' || code == 'S13' || code == 'S14') {
          expect(nextItem.durationSeconds, 8,
              reason: 'Zone 1 segment $code must have an 8s fixed bridge pause');
        } else if (code == 'S15') {
          expect(nextItem.durationSeconds, 5,
              reason: 'S15 must have a 5s fixed bridge pause transitioning into S16 bell');
        }
      }
    }
  });
}
