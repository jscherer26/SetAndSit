import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class PracticeScreen extends StatefulWidget {
  final List<SessionItem> sessionQueue;
  final int targetDurationSeconds;
  final String selectedMeditationType;
  final AudioSegment? selectedBell;
  final Widget Function() buildDebugScreen;
  final VoidCallback onEndSession;
  final VoidCallback? onSessionComplete;

  const PracticeScreen({
    super.key,
    required this.sessionQueue,
    required this.targetDurationSeconds,
    required this.selectedMeditationType,
    this.selectedBell,
    required this.buildDebugScreen,
    required this.onEndSession,
    this.onSessionComplete,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Phase 2: Dual AudioPlayer Architecture
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _bellPlayer = AudioPlayer();
  StreamSubscription? _voiceCompleteSubscription;
  StreamSubscription? _bellCompleteSubscription;
  StreamSubscription? _voiceLogSubscription;
  StreamSubscription? _bellLogSubscription;
  Timer? _countdownTimer;
  Timer? _silenceTimer;
  Timer? _fallbackTimer;
  Timer? _overlapTimer;

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

    // Keep screen awake throughout the entire practice, including S16 and bell decay
    WakelockPlus.enable().catchError((e) {
      debugPrint('[PracticeScreen] Error enabling Wakelock: $e');
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudioPlayers();
    _startCountdownTimer();
    _playCurrentQueueItem();
  }

  void _initAudioPlayers() {
    _voiceCompleteSubscription = _voicePlayer.onPlayerComplete.listen((_) {
      if (!mounted || _isFinished) return;
      final item = currentItem;
      final isS16 = item is PlayAudioItem &&
          (item.segment == ClinicalSegment.S16 || item.id.startsWith('S16'));
      if (isS16) {
        // Direct hook to session completion state
        _finishSession();
      } else {
        _advanceQueue();
      }
    });

    _bellCompleteSubscription = _bellPlayer.onPlayerComplete.listen((_) {
      if (!mounted || _isFinished) return;
      // Standalone bell queue items (e.g. silent session closing bell) advance queue on completion.
      // S16 overlap bell decay finishes independently; queue advancement for S16 is driven by _voicePlayer.
      final item = currentItem;
      if (item is PlayAudioItem &&
          item.isBell &&
          item.segment != ClinicalSegment.S16 &&
          !item.id.startsWith('S16')) {
        _advanceQueue();
      }
    });

    _voiceLogSubscription = _voicePlayer.onLog.listen((msg) {
      debugPrint('[VoicePlayer] $msg');
    });

    _bellLogSubscription = _bellPlayer.onLog.listen((msg) {
      debugPrint('[BellPlayer] $msg');
    });

    _voicePlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    ).catchError((e) {
      debugPrint('[VoicePlayer] Error setting AudioContext: $e');
    });

    _bellPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    ).catchError((e) {
      debugPrint('[BellPlayer] Error setting AudioContext: $e');
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceCompleteSubscription?.cancel();
    _bellCompleteSubscription?.cancel();
    _voiceLogSubscription?.cancel();
    _bellLogSubscription?.cancel();
    _countdownTimer?.cancel();
    _silenceTimer?.cancel();
    _fallbackTimer?.cancel();
    _overlapTimer?.cancel();
    _voicePlayer.dispose();
    _bellPlayer.dispose();
    // Ensure screen lock / wakelock is released if user exits early
    WakelockPlus.disable().catchError((e) {
      debugPrint('[PracticeScreen] Error disabling Wakelock on dispose: $e');
    });
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
      _fallbackTimer?.cancel();
      _overlapTimer?.cancel();

      if (_silenceSecondsRemaining <= 0) {
        _advanceQueue();
        return;
      }

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
      _overlapTimer?.cancel();

      final isS16 = item.segment == ClinicalSegment.S16 || item.id.startsWith('S16');
      final isBellOnly = item.isBell && !isS16;

      // Arm a safety watchdog timer so queue CANNOT freeze if onPlayerComplete is dropped
      final clipMs = (item.durationSeconds * 1000).round();
      final timeoutMs = max(2000, clipMs + (isS16 ? 4000 : 2000));
      _fallbackTimer = Timer(Duration(milliseconds: timeoutMs), () {
        if (mounted && !_isFinished) {
          debugPrint('[PracticeScreen] Watchdog timeout triggered for ${item.id}');
          _advanceQueue();
        }
      });

      if (isS16) {
        // --- Phase 2: Dual-Player Overlap Engine for S16 ---
        final bellAsset = (item.bellAssetPath ??
                widget.selectedBell?.filePath ??
                'bells/bell_meditation.ogg')
            .replaceFirst('assets/', '');
        final voiceAsset = item.audioAssetPath.replaceFirst('assets/', '');

        // Calibrated gain: bell at 0.75 (~ -2.5dB) allows voice at 1.0 to cut through resonant decay
        final bellVol = _isMuted ? 0.35 : 0.75;
        final voiceVol = _isMuted ? 0.0 : 1.0;

        // 1. Instantly fire the acoustic bell asset using _bellPlayer
        try {
          await _bellPlayer.setVolume(bellVol);
          await _bellPlayer.play(AssetSource(bellAsset));
        } catch (e) {
          debugPrint('[PracticeScreen] Error playing bell on _bellPlayer: $e');
        }

        // 2. Start a Flutter Timer for exactly 2.5 seconds
        // When the timer triggers, play the chosen S16 voice variant using _voicePlayer
        _overlapTimer = Timer(const Duration(milliseconds: 2500), () async {
          if (!mounted || _isFinished) return;
          try {
            await _voicePlayer.setVolume(voiceVol);
            await _voicePlayer.play(AssetSource(voiceAsset));
          } catch (e) {
            debugPrint('[PracticeScreen] Error playing S16 voice on _voicePlayer: $e');
          }
        });
      } else if (isBellOnly) {
        // Standalone bell playback on dedicated _bellPlayer
        try {
          final rawPath = item.audioAssetPath.replaceFirst('assets/', '');
          final volume = _isMuted ? 0.35 : 1.0;
          await _bellPlayer.setVolume(volume);
          await _bellPlayer.play(AssetSource(rawPath));
        } catch (e) {
          debugPrint('[PracticeScreen] Error playing standalone bell: $e');
        }
      } else {
        // Standard sequential playback for S01 through S15 on _voicePlayer
        try {
          final rawPath = item.audioAssetPath.replaceFirst('assets/', '');
          final volume = _isMuted ? 0.0 : 1.0;
          await _voicePlayer.setVolume(volume);
          await _voicePlayer.play(AssetSource(rawPath));
        } catch (e) {
          debugPrint('[PracticeScreen] Error playing ${item.audioAssetPath}: $e');
        }
      }

      setState(() {});
    }
  }

  void _advanceQueue() {
    if (_isFinished) return;
    _fallbackTimer?.cancel();
    _overlapTimer?.cancel();
    _currentIndex++;
    if (_currentIndex < widget.sessionQueue.length) {
      _playCurrentQueueItem();
    } else {
      _finishSession();
    }
  }

  void _finishSession() async {
    if (_isFinished) return;

    // Immediately mark finished to guard against any re-entrant completion calls
    _isFinished = true;

    _silenceTimer?.cancel();
    _countdownTimer?.cancel();
    _fallbackTimer?.cancel();
    _overlapTimer?.cancel();

    final item = currentItem;
    final isBellPlaying = item is PlayAudioItem && item.isBell;
    final isOutroPlaying = item is PlayAudioItem &&
        (item.segment == ClinicalSegment.S16 || item.id.startsWith('S16'));

    if (!isBellPlaying && !isOutroPlaying) {
      await _voicePlayer.stop();
      await _bellPlayer.stop();
      if (_isMuted) {
        try {
          await _bellPlayer.setVolume(0.35);
          final bellAsset = (widget.selectedBell?.filePath ?? 'bells/bell_meditation.ogg')
              .replaceFirst('assets/', '');
          await _bellPlayer.play(AssetSource(bellAsset));
        } catch (_) {}
      }
    }

    // Release wakelock only upon final transition to the completion screen
    WakelockPlus.disable().catchError((e) {
      debugPrint('[PracticeScreen] Error disabling Wakelock on completion: $e');
    });

    setState(() {
      _isFinished = true;
      _totalSecondsRemaining = 0;
    });

    widget.onSessionComplete?.call();
  }

  void _toggleMute() async {
    if (_isFinished) return;

    setState(() {
      _isMuted = !_isMuted;
    });

    final item = currentItem;
    if (item is PlayAudioItem) {
      final isS16 = item.segment == ClinicalSegment.S16 || item.id.startsWith('S16');
      if (isS16) {
        await _bellPlayer.setVolume(_isMuted ? 0.35 : 0.75);
        await _voicePlayer.setVolume(_isMuted ? 0.0 : 1.0);
      } else if (item.isBell) {
        await _bellPlayer.setVolume(_isMuted ? 0.35 : 1.0);
      } else {
        await _voicePlayer.setVolume(_isMuted ? 0.0 : 1.0);
      }
    } else {
      await _voicePlayer.setVolume(_isMuted ? 0.0 : 1.0);
      await _bellPlayer.setVolume(_isMuted ? 0.35 : 1.0);
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
                      _overlapTimer?.cancel();
                      _voicePlayer.stop();
                      _bellPlayer.stop();
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
                      width: 220,
                      height: 220,
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
                          width: 168,
                          height: 168,
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
                                  fontSize: _isFinished ? 22 : 36,
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
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Line anchored directly below the circle (width matches the circle)
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.pillUnselected,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.darkOlive,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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

                    // Single-line concise title (e.g. "External Arrival (10)")
                    SizedBox(
                      height: 28,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          currentItem?.displayTitle ?? 'Preparing Practice Space',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBlack,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Spoken Guidance Text with minHeight so it never causes layout shifts
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 76,
                      ),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                ? currentItem!.text
                                : (currentItem is PauseSilenceItem
                                    ? 'Resting in open stillness...'
                                    : ''),
                            key: ValueKey<String>(
                              (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                  ? currentItem!.text
                                  : (currentItem is PauseSilenceItem ? 'silence' : ''),
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontStyle: (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              color: (currentItem?.text != null && currentItem!.text.isNotEmpty)
                                  ? AppColors.textBlack
                                  : AppColors.textMuted,
                              height: 1.35,
                            ),
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
