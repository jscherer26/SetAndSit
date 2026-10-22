import 'package:flutter/material.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class SessionDebugScreen extends StatelessWidget {
  final int targetSeconds;
  final String selectedType;
  final double instructionDensity;
  final double redirectionDensity;
  final AudioSegment selectedBell;
  final List<SessionItem> sessionQueue;
  final VoidCallback onBack;

  const SessionDebugScreen({
    super.key,
    required this.targetSeconds,
    required this.selectedType,
    required this.instructionDensity,
    required this.redirectionDensity,
    required this.selectedBell,
    required this.sessionQueue,
    required this.onBack,
  });

  static String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var totalAudio = 0.0;
    var totalSilence = 0;
    final startTimes = <int>[];
    var acc = 0.0;

    for (final item in sessionQueue) {
      startTimes.add(acc.round());
      if (item is PlayAudioItem) {
        totalAudio += item.durationSeconds;
        acc += item.durationSeconds;
      } else if (item is PauseSilenceItem) {
        totalSilence += item.durationSeconds;
        acc += item.durationSeconds;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFEAEAEA)),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        onBack();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Session Debugger',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEAEAEA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Configuration Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuration Parameters',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.sageActive,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _debugRow('Practice Type', selectedType),
                    _debugRow('Target Duration', '${targetSeconds ~/ 60}m (${targetSeconds}s)'),
                    _debugRow(
                      'Settings',
                      'Instructions: ${instructionDensity.toInt()}, Mind-Wandering: ${redirectionDensity.toInt()}',
                    ),
                    _debugRow('Selected Bell', selectedBell.title),
                    _debugRow('Total Items in Queue', '${sessionQueue.length} items'),
                    _debugRow('Total Audio Duration', '${totalAudio.round()}s'),
                    _debugRow('Total Silence Pauses', '${totalSilence}s'),
                    _debugRow(
                      'Total Queue Duration',
                      '${_formatSeconds((totalAudio + totalSilence).round())} (${(totalAudio + totalSilence).round()}s)',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Generated SessionItems (${sessionQueue.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEAEAEA),
                ),
              ),
              const SizedBox(height: 8),

              // Items List
              Expanded(
                child: ListView.builder(
                  itemCount: sessionQueue.length,
                  itemBuilder: (context, index) {
                    final item = sessionQueue[index];
                    final startSec = startTimes.isNotEmpty ? startTimes[index] : 0;
                    final totalQueueSec = (totalAudio + totalSilence).round();
                    final countdownBase = targetSeconds > 0 ? targetSeconds : totalQueueSec;
                    final remainingSec = (countdownBase - startSec).clamp(0, countdownBase);

                    if (item is PlayAudioItem) {
                      final isOverlap = item.bellAssetPath != null ||
                          item.segment == ClinicalSegment.S16;

                      return Card(
                        color: AppColors.cardSurface,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isOverlap
                              ? const BorderSide(color: AppColors.sageActive, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isOverlap
                                        ? '#${index + 1} [DUAL-PLAYER OVERLAP]  ⏱ ${_formatSeconds(remainingSec)}'
                                        : '#${index + 1} [PLAY AUDIO]  ⏱ ${_formatSeconds(remainingSec)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isOverlap
                                          ? AppColors.darkOlive
                                          : AppColors.sageActive,
                                    ),
                                  ),
                                  Text(
                                    item.phaseName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.roseActive,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.displayTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEAEAEA),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Phase: ${item.phaseName} | Duration: ${item.durationSeconds.round()}s',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                              if (isOverlap) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2822),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.sageActive.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.notifications_active,
                                              size: 13, color: AppColors.sageActive),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Bell Player: ${item.bellAssetPath ?? selectedBell.filePath} (fires instantly, -2.5dB)',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFEAEAEA),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.record_voice_over,
                                              size: 13, color: AppColors.sageActive),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Voice Player: ${item.audioAssetPath} (speaks at +2.5s over bell decay)',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFEAEAEA),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Path: ${item.audioAssetPath}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    } else if (item is PauseSilenceItem) {
                      return Card(
                        color: AppColors.cardSurface,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${index + 1} [PAUSE SILENCE]  ⏱ ${_formatSeconds(remainingSec)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.roseActive,
                                ),
                              ),
                              Text(
                                '${item.durationSeconds}s pause',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEAEAEA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFEAEAEA),
            ),
          ),
        ],
      ),
    );
  }
}
