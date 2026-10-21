import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/engine/session_queue_engine.dart';
import 'package:setandsit/data/bell_data.dart';
import 'package:setandsit/services/audio_manifest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ClinicalArchetype pipelines contain valid segments and closing sequence', () {
    for (final arch in ClinicalArchetype.values) {
      expect(arch.pipeline.contains(ClinicalSegment.S01), isTrue);
      expect(arch.pipeline.contains(ClinicalSegment.S02), isTrue);
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
}
