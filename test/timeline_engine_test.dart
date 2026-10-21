import 'package:flutter_test/flutter_test.dart';
import 'package:setandsit/models/audio_models.dart';
import 'package:setandsit/engine/session_queue_engine.dart';
import 'package:setandsit/data/bell_data.dart';

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
}
