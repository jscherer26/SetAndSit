import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audio_models.dart';
import '../theme/app_theme.dart';

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

  final int voiceIndex;
  final ValueChanged<int> onVoiceIndexChanged;

  final int clockHour;
  final int clockMinute;
  final bool isAm;
  final Function(int hour, int minute, bool isAm) onClockTimeChanged;

  final Function(
    int targetSeconds,
    String practiceType,
    AudioSegment bell,
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
    required this.voiceIndex,
    required this.onVoiceIndexChanged,
    required this.clockHour,
    required this.clockMinute,
    required this.isAm,
    required this.onClockTimeChanged,
    required this.onBeginPractice,
  });

  static const List<String> voices = [
    'Kia (Male)',
    'Grace (Female)',
  ];

  static final List<String> practices = ClinicalArchetype.values.map((a) => a.title).toList();

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  Timer? _periodicCheckTimer;

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
    final initialTime = TimeOfDay(
      hour: widget.isAm
          ? (widget.clockHour % 12)
          : (widget.clockHour % 12 + 12),
      minute: widget.clockMinute,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.darkOlive,
              onPrimary: AppColors.buttonTextLight,
              surface: AppColors.white,
              onSurface: AppColors.textBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      var pickedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      // If picked time is earlier today, consider if it's tomorrow or overdue
      if (pickedDateTime.isBefore(now)) {
        pickedDateTime = pickedDateTime.add(const Duration(days: 1));
      }

      final diffMinutes = pickedDateTime.difference(now).inSeconds / 60.0;
      if (diffMinutes < 1.0 || diffMinutes > 90.0) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid Duration'),
            content: const Text(
              'Meditation duration must be between 1 and 90 minutes. Please pick a time within this window.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final hour12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final pickedIsAm = picked.period == DayPeriod.am;
      widget.onClockTimeChanged(hour12, picked.minute, pickedIsAm);
    }
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
                const Text(
                  'Select Practice',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),
                ...ConfigurationScreen.practices.map((p) {
                  final isSel = widget.selectedType == p ||
                      (widget.selectedType == 'Breath' &&
                          p == 'Breath Awareness');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      p,
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
                      widget.onSelectedTypeChanged(p);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoicePicker(BuildContext context) {
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
                const Text(
                  'Select Voice',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),
                ...ConfigurationScreen.voices.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final voiceName = entry.value;
                  final isSel = widget.voiceIndex == idx;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      voiceName,
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
                      widget.onVoiceIndexChanged(idx);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  int _calculateTargetSeconds() {
    final now = DateTime.now();
    final hour24 = widget.isAm
        ? (widget.clockHour == 12 ? 0 : widget.clockHour)
        : (widget.clockHour == 12 ? 12 : widget.clockHour + 12);

    final targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour24,
      widget.clockMinute,
    );

    if (!targetDateTime.isAfter(now)) {
      widget.onEnsureFutureTime();
      return widget.practiceDurationMinutes * 60;
    }

    final diff = targetDateTime.difference(now).inSeconds;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final isGuided = widget.selectedType != 'Silent';
    final formattedTime =
        '${widget.clockHour.toString().padLeft(2, '0')}:${widget.clockMinute.toString().padLeft(2, '0')}';
    final amPmText = widget.isAm ? 'AM' : 'PM';

    final practiceDisplay = widget.selectedType;
    final currentVoice = ConfigurationScreen.voices.length > widget.voiceIndex
        ? ConfigurationScreen.voices[widget.voiceIndex]
        : ConfigurationScreen.voices.first;

    final enabledBells = widget.bells.where((b) => b.isEnabled).toList();
    final availableBells = enabledBells.isNotEmpty ? enabledBells : widget.bells;
    final currentBellIndex =
        availableBells.indexWhere((b) => b.id == currentBell.id);

    final currentPracticeIndex = ConfigurationScreen.practices.indexWhere(
      (p) => p == practiceDisplay,
    );

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
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

                              const SizedBox(height: 12),
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
                            widget.onSelectedTypeChanged(ClinicalArchetype.focusedCalm.title);
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
                _buildStepperPill(
                  icon: Icons.self_improvement,
                  title: practiceDisplay,
                  onIconTap: () => _showPracticePicker(context),
                  onPrevious: () {
                    final validIdx = currentPracticeIndex == -1
                        ? 0
                        : currentPracticeIndex;
                    final nextIdx = (validIdx -
                            1 +
                            ConfigurationScreen.practices.length) %
                        ConfigurationScreen.practices.length;
                    widget.onSelectedTypeChanged(
                        ConfigurationScreen.practices[nextIdx]);
                  },
                  onNext: () {
                    final validIdx = currentPracticeIndex == -1
                        ? 0
                        : currentPracticeIndex;
                    final nextIdx = (validIdx + 1) %
                        ConfigurationScreen.practices.length;
                    widget.onSelectedTypeChanged(
                        ConfigurationScreen.practices[nextIdx]);
                  },
                ),
                const SizedBox(height: 14),

                // Voice Card
                _buildStepperPill(
                  icon: Icons.record_voice_over,
                  title: currentVoice,
                  onIconTap: () => _showVoicePicker(context),
                  onPrevious: () {
                    final nextIdx = (widget.voiceIndex -
                            1 +
                            ConfigurationScreen.voices.length) %
                        ConfigurationScreen.voices.length;
                    widget.onVoiceIndexChanged(nextIdx);
                  },
                  onNext: () {
                    final nextIdx = (widget.voiceIndex + 1) %
                        ConfigurationScreen.voices.length;
                    widget.onVoiceIndexChanged(nextIdx);
                  },
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
                      isGuided ? practiceDisplay : 'Silent',
                      currentBell,
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
