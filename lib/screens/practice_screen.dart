import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class PracticeScreen extends StatefulWidget {
  final List<SessionItem> sessionQueue;
  final int targetDurationSeconds;
  final String selectedMeditationType;
  final Widget Function() buildDebugScreen;
  final VoidCallback onEndSession;

  const PracticeScreen({
    super.key,
    required this.sessionQueue,
    required this.targetDurationSeconds,
    required this.selectedMeditationType,
    required this.buildDebugScreen,
    required this.onEndSession,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerCompleteSubscription;
  Timer? _countdownTimer;
  Timer? _silenceTimer;
  Timer? _fallbackTimer;

  int _totalSecondsRemaining = 0;
  int _currentIndex = 0;
  bool _isMuted = false;
  bool _isFinished = false;
  int _silenceSecondsRemaining = 0;

  SessionItem? get currentItem =>
      (_currentIndex >= 0 && _currentIndex < widget.sessionQueue.length)
          ? widget.sessionQueue[_currentIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _totalSecondsRemaining = widget.targetDurationSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) _advanceQueue();
    });

    _startCountdownTimer();
    _playCurrentQueueItem();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _playerCompleteSubscription?.cancel();
    _countdownTimer?.cancel();
    _silenceTimer?.cancel();
    _fallbackTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isFinished) {
        if (_totalSecondsRemaining > 0) {
          setState(() {
            _totalSecondsRemaining--;
          });
        }
        // Notice: When _totalSecondsRemaining reaches 0, we do NOT forcibly cut off
        // the session with _finishSession() here. The audio queue controls the orderly
        // completion through the closing bell, outro, and trailing silence.
        // Once the queue completes, _advanceQueue() calls _finishSession().
      }
    });
  }

  void _playCurrentQueueItem() async {
    if (_isFinished) return;

    if (_currentIndex >= widget.sessionQueue.length) {
      _finishSession();
      return;
    }

    final item = widget.sessionQueue[_currentIndex];

    if (item is PauseSilenceItem) {
      _silenceSecondsRemaining = item.durationSeconds;
      _silenceTimer?.cancel();
      _silenceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_silenceSecondsRemaining > 1) {
          setState(() {
            _silenceSecondsRemaining--;
          });
        } else {
          _silenceTimer?.cancel();
          _advanceQueue();
        }
      });
      setState(() {});
    } else if (item is PlayAudioItem) {
      _silenceTimer?.cancel();
      _fallbackTimer?.cancel();
      try {
        final rawPath = item.audioAssetPath.replaceFirst('assets/', '');
        final isBell = item.isBell;

        // If muted and this is a closing bell: play a gentle, non-invasive audio alert (soft chime)
        final volume = _isMuted ? (isBell ? 0.35 : 0.0) : 1.0;
        await _audioPlayer.setVolume(volume);
        await _audioPlayer.play(AssetSource(rawPath));
      } catch (e) {
        // If file playback fails, advance after clip duration
        final durSeconds = max(1, item.durationSeconds.round());
        _fallbackTimer = Timer(Duration(seconds: durSeconds), () {
          if (mounted && !_isFinished) {
            _advanceQueue();
          }
        });
      }
      setState(() {});
    }
  }

  void _advanceQueue() {
    if (_isFinished) return;
    _fallbackTimer?.cancel();
    _currentIndex++;
    if (_currentIndex < widget.sessionQueue.length) {
      _playCurrentQueueItem();
    } else {
      _finishSession();
    }
  }

  void _finishSession() async {
    if (_isFinished) return;

    _silenceTimer?.cancel();
    _countdownTimer?.cancel();
    _fallbackTimer?.cancel();

    // If session was ended prematurely (e.g. user finished manually) while still queued
    // before reaching S16 closing sequence, ensure the closing bell and outro play.
    if (_currentIndex < widget.sessionQueue.length) {
      final closingItems = widget.sessionQueue.sublist(_currentIndex);
      final hasClosingBell = closingItems.any((it) => it is PlayAudioItem && it.isBell);
      if (hasClosingBell) {
        // Jump directly to the closing bell sequence so the practitioner hears the closing cue
        final closingIdx = widget.sessionQueue.lastIndexWhere((it) => it is PlayAudioItem && it.isBell);
        if (closingIdx != -1) {
          _currentIndex = closingIdx;
          _playCurrentQueueItem();
          return;
        }
      }
    }

    final item = currentItem;
    final isBellPlaying = item is PlayAudioItem && item.isBell;
    final isOutroPlaying = item is PlayAudioItem && item.segment == ClinicalSegment.S16;

    if (!isBellPlaying && !isOutroPlaying) {
      await _audioPlayer.stop();
      if (_isMuted) {
        try {
          await _audioPlayer.setVolume(0.35);
          await _audioPlayer.play(AssetSource('bells/bell_meditation.ogg'));
        } catch (_) {}
      }
    }

    setState(() {
      _isFinished = true;
      _totalSecondsRemaining = 0;
    });
  }

  void _toggleMute() async {
    if (_isFinished) return;

    setState(() {
      _isMuted = !_isMuted;
    });

    final item = currentItem;
    if (item is PlayAudioItem) {
      final vol = _isMuted ? (item.isBell ? 0.35 : 0.0) : 1.0;
      await _audioPlayer.setVolume(vol);
    } else {
      await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = widget.targetDurationSeconds > 0
        ? widget.targetDurationSeconds
        : 1;
    final progress =
        ((totalDuration - _totalSecondsRemaining) / totalDuration)
            .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Practice',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textBlack),
                    onPressed: () {
                      _audioPlayer.stop();
                      widget.onEndSession();
                    },
                  ),
                ],
              ),

              // Center Visual & Timer
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.selectedMeditationType,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkOlive,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Ambient Breathing Circle (continues pulsing while muted)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale =
                          _isFinished ? 1.0 : _pulseAnimation.value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.circleOuterGlow,
                        border: Border.all(
                          color: AppColors.circleBorder,
                          width: 8,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isFinished
                                    ? 'Sit Complete'
                                    : _formatTime(_totalSecondsRemaining),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _isFinished ? 24 : 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBlack,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isFinished
                                    ? 'May you be well'
                                    : 'remaining',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_isFinished) ...[
                    const Text(
                      'End of Formal Practice',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Carry this clarity and quiet presence with you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ] else ...[
                    // Phase badge and Mute indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pillUnselected,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentItem?.phaseName ?? 'Arrival & Agency',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkOlive,
                            ),
                          ),
                        ),
                        if (_isMuted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSand,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_off,
                                    size: 13, color: AppColors.textMuted),
                                SizedBox(width: 4),
                                Text(
                                  'MUTED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      currentItem?.displayTitle ?? 'Preparing Practice Space',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBlack,
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.pillUnselected,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.darkOlive,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Bottom Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _isFinished
                    ? SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkOlive,
                            foregroundColor: AppColors.buttonTextLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: widget.onEndSession,
                          child: const Text(
                            'Finished',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.cardBorder,
                                    width: 1.5,
                                  ),
                                  foregroundColor: AppColors.textBlack,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => widget.buildDebugScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.bug_report_outlined),
                                label: const Text(
                                  'Debug',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isMuted
                                      ? AppColors.textSubtle
                                      : AppColors.darkOlive,
                                  foregroundColor: AppColors.buttonTextLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _toggleMute,
                                icon: Icon(_isMuted
                                    ? Icons.volume_up
                                    : Icons.volume_off),
                                label: Text(
                                  _isMuted ? 'Unmute' : 'Mute',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
