import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../services/audio_manifest_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_stepper_card.dart';

class ManageVoicesScreen extends StatefulWidget {
  final List<VoiceConfig> initialVoices;
  final String? initialSelectedVoiceId;
  final ValueChanged<List<VoiceConfig>> onVoicesUpdated;
  final VoidCallback? onBack;
  final AudioPlayer? audioPlayer;

  const ManageVoicesScreen({
    super.key,
    required this.initialVoices,
    this.initialSelectedVoiceId,
    required this.onVoicesUpdated,
    this.onBack,
    this.audioPlayer,
  });

  @override
  State<ManageVoicesScreen> createState() => _ManageVoicesScreenState();
}

class _ManageVoicesScreenState extends State<ManageVoicesScreen> {
  late List<VoiceConfig> _voices;
  late String _selectedVoiceId;

  static const List<String> _segmentCodes = [
    'S01', 'S02', 'S03', 'S04', 'S05', 'S06', 'S07', 'S08',
    'S09', 'S10', 'S11', 'S12', 'S13', 'S14', 'S15', 'S16',
  ];

  int _selectedSegmentIndex = 0;
  int _selectedVariantIndex = 0;

  // Dedicated AudioPlayer instance for audition
  late final AudioPlayer _audioPlayer;
  late final bool _ownsAudioPlayer;
  bool _isPlaying = false;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _ownsAudioPlayer = widget.audioPlayer == null;
    _audioPlayer = widget.audioPlayer ?? AudioPlayer();

    _voices = List<VoiceConfig>.from(widget.initialVoices);
    _selectedVoiceId = widget.initialSelectedVoiceId ??
        (_voices.isNotEmpty ? _voices.first.id : 'kia');

    if (!_voices.any((v) => v.id == _selectedVoiceId) && _voices.isNotEmpty) {
      _selectedVoiceId = _voices.first.id;
    }

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });

    AudioManifestService.initialize();
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.stop();
    if (_ownsAudioPlayer) {
      _audioPlayer.dispose();
    }
    super.dispose();
  }

  VoiceConfig get currentVoice {
    return _voices.firstWhere(
      (v) => v.id == _selectedVoiceId,
      orElse: () => _voices.first,
    );
  }

  String get currentSegmentCode => _segmentCodes[_selectedSegmentIndex];

  List<ScriptVariant> get currentVariants {
    return AudioManifestService.getVariantsForSegment(currentSegmentCode);
  }

  ScriptVariant? get currentVariant {
    final vars = currentVariants;
    if (vars.isEmpty) return null;
    if (_selectedVariantIndex >= vars.length) {
      return vars.first;
    }
    return vars[_selectedVariantIndex];
  }

  void _saveAndNotify() {
    PreferencesService.saveVoices(_voices);
    widget.onVoicesUpdated(_voices);
  }

  Future<void> _stopAudition() async {
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> _startAudition() async {
    if (_isPlaying) {
      await _stopAudition();
    }

    final voice = currentVoice;
    final seg = currentSegmentCode;
    final variant = currentVariant;
    if (variant == null) return;

    final variantId = variant.variantId;
    final audioPath = '${voice.assetFolder}/${seg}_$variantId.mp3';
    String cleanPath =
        audioPath.startsWith('assets/') ? audioPath.substring(7) : audioPath;
    if (cleanPath.startsWith('audio/voices/')) {
      cleanPath = cleanPath.replaceFirst('audio/voices/', 'audio/');
    }

    if (mounted) {
      setState(() {
        _isPlaying = true;
      });
    }

    try {
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play audio: $e')),
        );
      }
    }
  }

  void _stepVoicePrevious() {
    _stopAudition();
    final list = _voices;
    if (list.isEmpty) return;
    final idx = list.indexWhere((v) => v.id == _selectedVoiceId);
    final nextIdx = (idx - 1 + list.length) % list.length;
    setState(() {
      _selectedVoiceId = list[nextIdx].id;
    });
  }

  void _stepVoiceNext() {
    _stopAudition();
    final list = _voices;
    if (list.isEmpty) return;
    final idx = list.indexWhere((v) => v.id == _selectedVoiceId);
    final nextIdx = (idx + 1) % list.length;
    setState(() {
      _selectedVoiceId = list[nextIdx].id;
    });
  }

  void _stepSegmentPrevious() {
    _stopAudition();
    setState(() {
      _selectedSegmentIndex =
          (_selectedSegmentIndex - 1 + _segmentCodes.length) %
              _segmentCodes.length;
      _selectedVariantIndex = 0;
    });
  }

  void _stepSegmentNext() {
    _stopAudition();
    setState(() {
      _selectedSegmentIndex =
          (_selectedSegmentIndex + 1) % _segmentCodes.length;
      _selectedVariantIndex = 0;
    });
  }

  void _stepVariantPrevious() {
    _stopAudition();
    final vars = currentVariants;
    if (vars.isEmpty) return;
    setState(() {
      _selectedVariantIndex =
          (_selectedVariantIndex - 1 + vars.length) % vars.length;
    });
  }

  void _stepVariantNext() {
    _stopAudition();
    final vars = currentVariants;
    if (vars.isEmpty) return;
    setState(() {
      _selectedVariantIndex = (_selectedVariantIndex + 1) % vars.length;
    });
  }

  void _toggleInclude(bool newValue) {
    final voice = currentVoice;
    if (!newValue) {
      final activeCount = _voices.where((v) => v.isIncluded).length;
      if (activeCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one voice must remain active.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() {
      final idx = _voices.indexWhere((v) => v.id == voice.id);
      if (idx != -1) {
        _voices[idx] = voice.copyWith(isIncluded: newValue);
      }
    });
    _saveAndNotify();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isDestructive = false,
  }) {
    final isEnabled = onPressed != null;
    final color = !isEnabled
        ? AppColors.textSubtle.withValues(alpha: 0.4)
        : (isDestructive ? AppColors.errorRed : AppColors.darkOlive);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.white
              : AppColors.backgroundSand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !isEnabled
                ? AppColors.cardBorder.withValues(alpha: 0.3)
                : (isDestructive
                    ? AppColors.errorRed.withValues(alpha: 0.4)
                    : AppColors.cardBorder),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperCard({
    required IconData leadingIcon,
    required String title,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(29),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.6),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.backgroundSand,
              shape: BoxShape.circle,
            ),
            child: Icon(leadingIcon, color: AppColors.textBlack, size: 22),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textBlack),
            onPressed: onPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
            splashRadius: 22,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textBlack),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = currentVoice;
    final segmentMeta = kSegmentMetadata[currentSegmentCode];
    final variant = currentVariant;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
          onPressed: () {
            _stopAudition();
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Manage Voices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlack,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Voice Stepper (< [Voice ListTile Widget] >)
              VoiceStepperCard(
                voice: voice,
                subtitle: '${voice.description} • ${voice.gender}',
                onPrevious: _voices.length > 1 ? _stepVoicePrevious : null,
                onNext: _voices.length > 1 ? _stepVoiceNext : null,
              ),
              const SizedBox(height: 12),

              // 2. Action Buttons Row: Add | Copy | Rename | Delete (Disabled)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.add,
                      label: 'Add',
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.copy,
                      label: 'Copy',
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Rename',
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      isDestructive: true,
                      onPressed: null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. "Include on Home Screen" Switch
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
                            voice.isIncluded
                                ? 'Active in Home Screen Voice selector'
                                : 'Hidden from Home Screen Voice selector',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: voice.isIncluded,
                      activeTrackColor: AppColors.darkOlive,
                      activeThumbColor: AppColors.white,
                      onChanged: _toggleInclude,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. "Audition Voice" Button
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
                    _isPlaying ? 'Stop Audition' : 'Audition Voice',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isPlaying ? _stopAudition : _startAudition,
                ),
              ),

              // Visual Divider
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(
                  color: AppColors.cardBorder,
                  height: 1,
                  thickness: 1,
                ),
              ),

              // Bottom Section: Script & Variant Inspector
              const Text(
                'Script & Variant Inspector',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 12),

              // 1. Segment Stepper (< [Segment ListTile Widget] >)
              _buildStepperCard(
                leadingIcon: Icons.auto_stories_outlined,
                title:
                    '$currentSegmentCode • ${segmentMeta?['title'] ?? currentSegmentCode}',
                onPrevious: _stepSegmentPrevious,
                onNext: _stepSegmentNext,
              ),
              const SizedBox(height: 10),

              // 2. Segment Description Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.darkOlive,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Segment Rationale',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkOlive,
                          ),
                        ),
                        if (segmentMeta?['phase'] != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '• ${segmentMeta!['phase']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      segmentMeta?['rationale'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Variant Stepper (< [Variant ListTile Widget] >)
              _buildStepperCard(
                leadingIcon: Icons.format_quote_outlined,
                title: variant != null
                    ? '${variant.variantId} • ${variant.variantName}'
                    : 'No variants available',
                onPrevious:
                    currentVariants.length > 1 ? _stepVariantPrevious : null,
                onNext: currentVariants.length > 1 ? _stepVariantNext : null,
              ),
              const SizedBox(height: 10),

              // 4. Variant Script Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Script Variant Text',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (variant != null && variant.wordCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSand,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${variant.wordCount} words',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.darkOlive,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        variant != null
                            ? '“${variant.text}”'
                            : 'No script text found.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: AppColors.textBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
