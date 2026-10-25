import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audio_models.dart';
import '../models/practice_config.dart';
import '../models/voice_config.dart';
import '../services/audio_manifest_service.dart';
import '../theme/app_theme.dart';
import '../widgets/practice_stepper_card.dart';
import '../widgets/voice_stepper_card.dart';
import 'clock_time_picker_dialog.dart';

class ConfigurationScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;

  final int practiceDurationMinutes;
  final VoidCallback onEnsureFutureTime;

  final List<AudioSegment> bells;
  final String selectedBellId;
  final ValueChanged<String> onSelectedBellChanged;
  final VoidCallback onOpenBellSettings;

  final String selectedType;
  final ValueChanged<String> onSelectedTypeChanged;

  final List<PracticeConfig> practices;
  final String selectedPracticeId;
  final ValueChanged<String> onSelectedPracticeIdChanged;
  final VoidCallback onOpenManagePractices;

  final List<VoiceConfig>? voices;
  final String? selectedVoiceId;
  final ValueChanged<String>? onSelectedVoiceIdChanged;
  final VoidCallback? onOpenManageVoices;

  final int voiceIndex;
  final ValueChanged<int>? onVoiceIndexChanged;

  final int clockHour;
  final int clockMinute;
  final bool isAm;
  final Function(int hour, int minute, bool isAm) onClockTimeChanged;

  final bool isDeveloperMode;
  final ValueChanged<bool>? onDeveloperModeChanged;

  final Function(
    int targetSeconds,
    String practiceType,
    AudioSegment bell,
    PracticeConfig? practiceConfig,
  ) onBeginPractice;

  const ConfigurationScreen({
    super.key,
    required this.onOpenSettings,
    required this.practiceDurationMinutes,
    required this.onEnsureFutureTime,
    required this.bells,
    required this.selectedBellId,
    required this.onSelectedBellChanged,
    required this.onOpenBellSettings,
    required this.selectedType,
    required this.onSelectedTypeChanged,
    required this.practices,
    required this.selectedPracticeId,
    required this.onSelectedPracticeIdChanged,
    required this.onOpenManagePractices,
    this.voices,
    this.selectedVoiceId,
    this.onSelectedVoiceIdChanged,
    this.onOpenManageVoices,
    this.voiceIndex = 0,
    this.onVoiceIndexChanged,
    required this.clockHour,
    required this.clockMinute,
    required this.isAm,
    required this.onClockTimeChanged,
    this.isDeveloperMode = false,
    this.onDeveloperModeChanged,
    required this.onBeginPractice,
  });

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  Timer? _periodicCheckTimer;
  int _titleTapCount = 0;
  DateTime? _lastTitleTapTime;

  @override
  void initState() {
    super.initState();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkTimeStillInFuture();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTimeStillInFuture();
    });
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    if (_lastTitleTapTime == null ||
        now.difference(_lastTitleTapTime!) > const Duration(milliseconds: 1500)) {
      _titleTapCount = 1;
    } else {
      _titleTapCount++;
    }
    _lastTitleTapTime = now;

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      _showDeveloperModeDialog();
    }
  }

  Future<void> _showDeveloperModeDialog() async {
    if (widget.isDeveloperMode) {
      _showActiveDeveloperModeDialog();
      return;
    }

    final controller = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.developer_mode, color: AppColors.darkOlive),
                  SizedBox(width: 8),
                  Text(
                    'Developer Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter passcode to enable Developer Mode:',
                    style: TextStyle(fontSize: 14, color: AppColors.textBlack),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkOlive,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.backgroundSand,
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.darkOlive, width: 2),
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim() == '2217') {
                        Navigator.of(dialogContext).pop();
                        widget.onDeveloperModeChanged?.call(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Developer Mode enabled. Staged audio active.'),
                            backgroundColor: Color(0xFFD32F2F),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          errorText = 'Incorrect passcode';
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkOlive,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (controller.text.trim() == '2217') {
                      Navigator.of(dialogContext).pop();
                      widget.onDeveloperModeChanged?.call(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Developer Mode enabled. Staged audio active.'),
                          backgroundColor: Color(0xFFD32F2F),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      setDialogState(() {
                        errorText = 'Incorrect passcode';
                      });
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showActiveDeveloperModeDialog() async {
    final count = AudioManifestService.stagedVariantsCount;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFFD32F2F)),
              SizedBox(width: 8),
              Text(
                'Developer Mode Active',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Previewing staged script audio from /changes directories.',
                style: TextStyle(fontSize: 14, color: AppColors.textBlack),
              ),
              const SizedBox(height: 8),
              Text(
                'Staged variants loaded: $count',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep Active', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onDeveloperModeChanged?.call(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Developer Mode disabled.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Disable Developer Mode'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  void _checkTimeStillInFuture() {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );
    if (!target.isAfter(now)) {
      widget.onEnsureFutureTime();
    }
  }

  AudioSegment get currentBell {
    final enabled = widget.bells.where((b) => b.isEnabled).toList();
    final list = enabled.isNotEmpty ? enabled : widget.bells;
    return list.firstWhere(
      (b) => b.id == widget.selectedBellId,
      orElse: () => list.first,
    );
  }

  void _showTimeAdjustmentDialog(BuildContext context) async {
    final picked = await ClockTimePickerDialog.show(
      context: context,
      initialHour12: widget.clockHour,
      initialMinute: widget.clockMinute,
      initialIsAm: widget.isAm,
    );

    if (picked != null) {
      final hour12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final pickedIsAm = picked.period == DayPeriod.am;
      widget.onClockTimeChanged(hour12, picked.minute, pickedIsAm);
    }
  }

  List<PracticeConfig> get includedPractices {
    final list = widget.practices.where((p) => p.isIncluded).toList();
    return list.isNotEmpty ? list : widget.practices;
  }

  PracticeConfig get currentPractice {
    final list = includedPractices;
    return list.firstWhere(
      (p) => p.id == widget.selectedPracticeId,
      orElse: () => list.firstWhere(
        (p) => p.name == widget.selectedType,
        orElse: () => list.first,
      ),
    );
  }

  void _showPracticePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Practice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenManagePractices();
                      },
                      icon: const Icon(Icons.tune, size: 16, color: AppColors.darkOlive),
                      label: const Text(
                        'Manage',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkOlive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...includedPractices.map((p) {
                  final isSel = currentPractice.id == p.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel
                            ? AppColors.darkOlive
                            : AppColors.textBlack,
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check, color: AppColors.darkOlive)
                        : null,
                    onTap: () {
                      widget.onSelectedPracticeIdChanged(p.id);
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 10),
                const Divider(color: AppColors.cardBorder, height: 1),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.darkOlive.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune, color: AppColors.darkOlive, size: 20),
                  ),
                  title: const Text(
                    'Manage Practices',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkOlive,
                    ),
                  ),
                  subtitle: const Text(
                    'Customize segments, add or copy practices',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.darkOlive),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenManagePractices();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int get currentDurationMinutes {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);

    var targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );

    if (!targetDateTime.isAfter(now)) {
      targetDateTime = targetDateTime.add(const Duration(days: 1));
    }

    final diff = targetDateTime.difference(now).inSeconds;
    if (diff > 90 * 60 || diff < 60) {
      return widget.practiceDurationMinutes;
    }
    return (diff / 60.0).round();
  }

  int _calculateTargetSeconds() {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);

    var targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );

    if (!targetDateTime.isAfter(now)) {
      targetDateTime = targetDateTime.add(const Duration(days: 1));
    }

    final diff = targetDateTime.difference(now).inSeconds;
    if (diff > 90 * 60 || diff < 60) {
      widget.onEnsureFutureTime();
      return widget.practiceDurationMinutes * 60;
    }
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final isGuided = widget.selectedType != 'Silent';
    final formattedTime =
        '${widget.clockHour.toString().padLeft(2, '0')}:${widget.clockMinute.toString().padLeft(2, '0')}';
    final amPmText = widget.isAm ? 'AM' : 'PM';

    final voiceList = widget.voices ?? VoiceConfig.defaultVoices;
    final includedVoices = voiceList.where((v) => v.isIncluded).toList();
    final activeVoices =
        includedVoices.isNotEmpty ? includedVoices : voiceList;
    final currentVoiceConfig = activeVoices.firstWhere(
      (v) => v.id == widget.selectedVoiceId,
      orElse: () => activeVoices.first,
    );

    final enabledBells = widget.bells.where((b) => b.isEnabled).toList();
    final availableBells = enabledBells.isNotEmpty ? enabledBells : widget.bells;
    final currentBellIndex =
        availableBells.indexWhere((b) => b.id == currentBell.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Settings Gear Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: _handleTitleTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set&Sit',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBlack,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Adaptive Guided Meditation',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.isDeveloperMode) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showActiveDeveloperModeDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE53935), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1AE53935),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: Color(0xFFD32F2F)),
                            SizedBox(width: 6),
                            Text(
                              'Developer Mode',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings,
                          color: AppColors.textBlack, size: 22),
                      onPressed: widget.onOpenSettings,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Hero Circular Dial
              Center(
                child: ClipOval(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showTimeAdjustmentDialog(context),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.circleOuterGlow.withValues(alpha: 0.5),
                        border: Border.all(
                          color: AppColors.circleBorder,
                          width: 12,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Practice Ends At',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textBlack,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      amPmText,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textBlack,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 4),
                              Text(
                                '$currentDurationMinutes min practice',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkOlive,
                                ),
                              ),

                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSand,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Tap to Adjust',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSubtle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Guided vs Silent Toggle Pill
              Container(
                height: 56,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.pillUnselected,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!isGuided) {
                            widget.onSelectedTypeChanged('Guided');
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isGuided
                                ? AppColors.darkOlive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Guided',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isGuided
                                  ? AppColors.buttonTextLight
                                  : AppColors.textBlack,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onSelectedTypeChanged('Silent'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !isGuided
                                ? AppColors.darkOlive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Silent',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: !isGuided
                                  ? AppColors.buttonTextLight
                                  : AppColors.textBlack,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Practice Card (Guided mode only)
              if (isGuided) ...[
                PracticeStepperCard(
                  practice: currentPractice,
                  onPrevious: includedPractices.length > 1
                      ? () {
                          final list = includedPractices;
                          final idx = list.indexWhere((p) => p.id == currentPractice.id);
                          final nextIdx = (idx - 1 + list.length) % list.length;
                          widget.onSelectedPracticeIdChanged(list[nextIdx].id);
                        }
                      : null,
                  onNext: includedPractices.length > 1
                      ? () {
                          final list = includedPractices;
                          final idx = list.indexWhere((p) => p.id == currentPractice.id);
                          final nextIdx = (idx + 1) % list.length;
                          widget.onSelectedPracticeIdChanged(list[nextIdx].id);
                        }
                      : null,
                  onTap: () => _showPracticePicker(context),
                  onLeadingTap: widget.onOpenManagePractices,
                ),
                const SizedBox(height: 14),

                // Voice Card
                VoiceStepperCard(
                  voice: currentVoiceConfig,
                  onLeadingTap: widget.onOpenManageVoices,
                  onTap: widget.onOpenManageVoices,
                  onPrevious: activeVoices.length > 1
                      ? () {
                          final idx = activeVoices.indexWhere(
                              (v) => v.id == currentVoiceConfig.id);
                          final nextIdx = (idx - 1 + activeVoices.length) %
                              activeVoices.length;
                          widget.onSelectedVoiceIdChanged
                              ?.call(activeVoices[nextIdx].id);
                          widget.onVoiceIndexChanged?.call(nextIdx);
                        }
                      : null,
                  onNext: activeVoices.length > 1
                      ? () {
                          final idx = activeVoices.indexWhere(
                              (v) => v.id == currentVoiceConfig.id);
                          final nextIdx =
                              (idx + 1) % activeVoices.length;
                          widget.onSelectedVoiceIdChanged
                              ?.call(activeVoices[nextIdx].id);
                          widget.onVoiceIndexChanged?.call(nextIdx);
                        }
                      : null,
                ),
                const SizedBox(height: 14),
              ],

              // Bell Card
              _buildStepperPill(
                icon: Icons.notifications,
                title: currentBell.title,
                onIconTap: widget.onOpenBellSettings,
                onPrevious: () {
                  if (availableBells.isEmpty) return;
                  final validIdx = currentBellIndex == -1
                      ? 0
                      : currentBellIndex;
                  final nextIdx = (validIdx - 1 + availableBells.length) %
                      availableBells.length;
                  widget.onSelectedBellChanged(availableBells[nextIdx].id);
                },
                onNext: () {
                  if (availableBells.isEmpty) return;
                  final validIdx = currentBellIndex == -1
                      ? 0
                      : currentBellIndex;
                  final nextIdx =
                      (validIdx + 1) % availableBells.length;
                  widget.onSelectedBellChanged(availableBells[nextIdx].id);
                },
              ),

              const SizedBox(height: 28),

              // Begin Practice Button
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkOlive,
                    foregroundColor: AppColors.buttonTextLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(29),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    final targetSeconds = _calculateTargetSeconds();
                    widget.onBeginPractice(
                      targetSeconds,
                      isGuided ? currentPractice.name : 'Silent',
                      currentBell,
                      isGuided ? currentPractice : null,
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Begin Practice',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperPill({
    required IconData icon,
    required String title,
    required VoidCallback onIconTap,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(29),
        border:
            Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          // Circular Icon Button (Tapping opens Parameter page / picker)
          InkWell(
            onTap: onIconTap,
            borderRadius: BorderRadius.circular(21),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.backgroundSand,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textBlack, size: 22),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textBlack),
            onPressed: onPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
            splashRadius: 22,
          ),
          Expanded(
            child: InkWell(
              onTap: onIconTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: AppColors.textBlack),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}
