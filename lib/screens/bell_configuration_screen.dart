import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

class BellConfigurationScreen extends StatefulWidget {
  final List<AudioSegment> bells;
  final String selectedBellId;
  final ValueChanged<String> onBellSelected;
  final ValueChanged<AudioSegment> onBellUpdated;
  final VoidCallback onBack;

  const BellConfigurationScreen({
    super.key,
    required this.bells,
    required this.selectedBellId,
    required this.onBellSelected,
    required this.onBellUpdated,
    required this.onBack,
  });

  @override
  State<BellConfigurationScreen> createState() =>
      _BellConfigurationScreenState();
}

class _BellConfigurationScreenState extends State<BellConfigurationScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  AudioSegment get currentBell {
    return widget.bells.firstWhere(
      (b) => b.id == widget.selectedBellId,
      orElse: () => widget.bells.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _previewBell(String path) async {
    try {
      await _audioPlayer.stop();
      final cleanPath = path.replaceFirst('assets/', '');
      setState(() => _isPlaying = true);
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _stopAudition() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        widget.bells.indexWhere((b) => b.id == widget.selectedBellId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Manage Bells',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Bell to Configure',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              // 1. Stepper Pill
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.textBlack),
                      onPressed: currentIndex > 0
                          ? () {
                              _stopAudition();
                              widget.onBellSelected(
                                  widget.bells[currentIndex - 1].id);
                            }
                          : null,
                    ),
                    Text(
                      currentBell.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBlack,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.textBlack),
                      onPressed: currentIndex < widget.bells.length - 1
                          ? () {
                              _stopAudition();
                              widget.onBellSelected(
                                  widget.bells[currentIndex + 1].id);
                            }
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. "Include on Home Screen" Switch (consistent feel & layout as Manage Voices)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.6),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Include on Home Screen',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBlack,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentBell.isEnabled
                                ? 'Active in Home Screen Bell selector'
                                : 'Hidden from Home Screen Bell selector',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: currentBell.isEnabled,
                      activeTrackColor: AppColors.darkOlive,
                      activeThumbColor: AppColors.white,
                      onChanged: (checked) {
                        widget.onBellUpdated(
                            currentBell.copyWith(isEnabled: checked));
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. "Audition Bell" Button (consistent feel & layout as Manage Voices)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isPlaying ? AppColors.errorRed : AppColors.darkOlive,
                    foregroundColor: AppColors.buttonTextLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow,
                      size: 22),
                  label: Text(
                    _isPlaying ? 'Stop Audition' : 'Audition Bell',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isPlaying
                      ? _stopAudition
                      : () => _previewBell(currentBell.filePath),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Bell Parameters Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bell Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: ValueKey('${currentBell.id}_name'),
                      initialValue: currentBell.title,
                      onChanged: (val) {
                        widget.onBellUpdated(currentBell.copyWith(title: val));
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundSand,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Duration (Seconds)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: ValueKey('${currentBell.id}_dur'),
                      initialValue: currentBell.durationSeconds.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        final parsed = int.tryParse(digits) ?? currentBell.durationSeconds;
                        widget.onBellUpdated(currentBell.copyWith(durationSeconds: parsed));
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundSand,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Min Delay Before (Seconds)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: ValueKey('${currentBell.id}_min'),
                      initialValue: currentBell.minDelayBefore.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        final parsed = int.tryParse(digits) ?? currentBell.minDelayBefore;
                        widget.onBellUpdated(currentBell.copyWith(minDelayBefore: parsed));
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundSand,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Max Delay Before (Seconds)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: ValueKey('${currentBell.id}_max'),
                      initialValue: currentBell.maxDelayBefore.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        final parsed = int.tryParse(digits) ?? currentBell.maxDelayBefore;
                        widget.onBellUpdated(currentBell.copyWith(maxDelayBefore: parsed));
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.backgroundSand,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
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
