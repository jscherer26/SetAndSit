import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final int practiceDurationMinutes;
  final double instructionDensity;
  final double redirectionDensity;
  final int preparationDelaySeconds;
  final ValueChanged<int> onPracticeDurationChanged;
  final ValueChanged<double> onInstructionDensityChanged;
  final ValueChanged<double> onRedirectionDensityChanged;
  final ValueChanged<int> onPreparationDelayChanged;
  final VoidCallback onBack;
  final VoidCallback? onOpenManagePractices;
  final VoidCallback? onOpenManageVoices;
  final VoidCallback? onOpenBellSettings;
  final VoidCallback? onOpenAbout;

  const SettingsScreen({
    super.key,
    required this.practiceDurationMinutes,
    required this.instructionDensity,
    required this.redirectionDensity,
    this.preparationDelaySeconds = 10,
    required this.onPracticeDurationChanged,
    required this.onInstructionDensityChanged,
    required this.onRedirectionDensityChanged,
    required this.onPreparationDelayChanged,
    required this.onBack,
    this.onOpenManagePractices,
    this.onOpenManageVoices,
    this.onOpenBellSettings,
    this.onOpenAbout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _durationController;
  late FocusNode _durationFocusNode;
  String? _errorMessage;

  late TextEditingController _delayController;
  late FocusNode _delayFocusNode;
  String? _delayErrorMessage;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.practiceDurationMinutes.toString(),
    );
    _durationFocusNode = FocusNode();
    _durationFocusNode.addListener(() {
      if (!_durationFocusNode.hasFocus) {
        _validateDuration();
      }
    });

    _delayController = TextEditingController(
      text: widget.preparationDelaySeconds.toString(),
    );
    _delayFocusNode = FocusNode();
    _delayFocusNode.addListener(() {
      if (!_delayFocusNode.hasFocus) {
        _validateDelay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.practiceDurationMinutes != widget.practiceDurationMinutes) {
      if (!_durationFocusNode.hasFocus &&
          _durationController.text !=
              widget.practiceDurationMinutes.toString()) {
        _durationController.text = widget.practiceDurationMinutes.toString();
        setState(() {
          _errorMessage = null;
        });
      }
    }
    if (oldWidget.preparationDelaySeconds != widget.preparationDelaySeconds) {
      if (!_delayFocusNode.hasFocus &&
          _delayController.text !=
              widget.preparationDelaySeconds.toString()) {
        _delayController.text = widget.preparationDelaySeconds.toString();
        setState(() {
          _delayErrorMessage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _durationFocusNode.dispose();
    _delayController.dispose();
    _delayFocusNode.dispose();
    super.dispose();
  }

  void _validateDuration({bool updateUi = true}) {
    final text = _durationController.text.trim();
    if (text.isEmpty) {
      if (updateUi && mounted) {
        setState(() {
          _errorMessage = 'Please enter a duration.';
        });
      }
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 90) {
      if (updateUi && mounted) {
        setState(() {
          _errorMessage = 'Duration must be between 1 and 90 minutes.';
        });
      }
      return;
    }
    if (updateUi && mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
    widget.onPracticeDurationChanged(parsed);
  }

  void _validateDelay({bool updateUi = true}) {
    final text = _delayController.text.trim();
    if (text.isEmpty) {
      if (updateUi && mounted) {
        setState(() {
          _delayErrorMessage = 'Please enter a delay (0 to 20 seconds).';
        });
      }
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > 20) {
      if (updateUi && mounted) {
        setState(() {
          _delayErrorMessage = 'Delay must be between 0 and 20 seconds.';
        });
      }
      return;
    }
    if (updateUi && mounted) {
      setState(() {
        _delayErrorMessage = null;
      });
    }
    widget.onPreparationDelayChanged(parsed);
  }

  void _handleBack() {
    final text = _durationController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 90) {
      setState(() {
        _errorMessage = 'Duration must be between 1 and 90 minutes.';
      });
      return;
    }

    final delayText = _delayController.text.trim();
    final delayParsed = int.tryParse(delayText);
    if (delayParsed == null || delayParsed < 0 || delayParsed > 20) {
      setState(() {
        _delayErrorMessage = 'Delay must be between 0 and 20 seconds.';
      });
      return;
    }

    widget.onPracticeDurationChanged(parsed);
    widget.onPreparationDelayChanged(delayParsed);
    widget.onBack();
  }

  void _handleNavigationSilently() {
    final text = _durationController.text.trim();
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 1 && parsed <= 90) {
      widget.onPracticeDurationChanged(parsed);
    }
    final delayText = _delayController.text.trim();
    final delayParsed = int.tryParse(delayText);
    if (delayParsed != null && delayParsed >= 0 && delayParsed <= 20) {
      widget.onPreparationDelayChanged(delayParsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textBlack, size: 22),
                      onPressed: _handleBack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Defaults',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              // Top Bubble: Defaults (Duration, Delay, Density)
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
                    // Row 1: Practice Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Practice Duration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBlack,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 100,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSand,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _errorMessage != null
                                  ? AppColors.errorRed
                                  : AppColors.cardBorder
                                      .withValues(alpha: 0.6),
                              width: _errorMessage != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: TextField(
                            controller: _durationController,
                            focusNode: _durationFocusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _errorMessage != null
                                  ? AppColors.errorRed
                                  : AppColors.darkOlive,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 12,
                              ),
                              suffixText: 'min',
                              suffixStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            onChanged: (val) {
                              final trimmed = val.trim();
                              final parsed = int.tryParse(trimmed);
                              if (parsed != null && parsed >= 1 && parsed <= 90) {
                                setState(() {
                                  _errorMessage = null;
                                });
                                widget.onPracticeDurationChanged(parsed);
                              } else {
                                _validateDuration();
                              }
                            },
                            onSubmitted: (_) => _validateDuration(),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        color: AppColors.cardBorder,
                        height: 1,
                      ),
                    ),

                    // Row 2: Practice Delay
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Practice Delay',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBlack,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 100,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSand,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _delayErrorMessage != null
                                  ? AppColors.errorRed
                                  : AppColors.cardBorder
                                      .withValues(alpha: 0.6),
                              width: _delayErrorMessage != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: TextField(
                            controller: _delayController,
                            focusNode: _delayFocusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _delayErrorMessage != null
                                  ? AppColors.errorRed
                                  : AppColors.darkOlive,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 12,
                              ),
                              suffixText: 'sec',
                              suffixStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            onChanged: (val) {
                              final trimmed = val.trim();
                              final parsed = int.tryParse(trimmed);
                              if (parsed != null && parsed >= 0 && parsed <= 20) {
                                setState(() {
                                  _delayErrorMessage = null;
                                });
                                widget.onPreparationDelayChanged(parsed);
                              } else {
                                _validateDelay();
                              }
                            },
                            onSubmitted: (_) => _validateDelay(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'The guidance will start this many seconds after  "Begin Practice" is pressed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),

                    if (_delayErrorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _delayErrorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (widget.onOpenManagePractices != null || widget.onOpenBellSettings != null) ...[
                const SizedBox(height: 18),

                // Bubble 3: Configuration & Practice Management Section
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (widget.onOpenManagePractices != null)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppColors.backgroundSand,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.self_improvement,
                                color: AppColors.darkOlive,
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              'Manage Practices',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBlack,
                              ),
                            ),
                            subtitle: const Text(
                              'Create, copy, and customize clinical meditation practices',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap: () {
                              _handleNavigationSilently();
                              widget.onOpenManagePractices!();
                            },
                          ),

                        if (widget.onOpenManageVoices != null) ...[
                          const Divider(
                            color: AppColors.cardBorder,
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppColors.backgroundSand,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.record_voice_over,
                                color: AppColors.darkOlive,
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              'Manage Voices',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBlack,
                              ),
                            ),
                            subtitle: const Text(
                              'Browse voices, inspect script variants, and audition audio',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap: () {
                              _handleNavigationSilently();
                              widget.onOpenManageVoices!();
                            },
                          ),
                        ],

                        if ((widget.onOpenManagePractices != null || widget.onOpenManageVoices != null) &&
                            widget.onOpenBellSettings != null)
                          const Divider(
                            color: AppColors.cardBorder,
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                          ),

                        if (widget.onOpenBellSettings != null)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppColors.backgroundSand,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active_outlined,
                                color: AppColors.darkOlive,
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              'Manage Bells',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBlack,
                              ),
                            ),
                            subtitle: const Text(
                              'Select and configure acoustic meditation bells',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap: () {
                              _handleNavigationSilently();
                              widget.onOpenBellSettings!();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              // Separate About Card
              if (widget.onOpenAbout != null) ...[
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.backgroundSand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.darkOlive,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'About Set&Sit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    subtitle: const Text(
                      'App info, mission, feedback, and licenses',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                    onTap: () {
                      _handleNavigationSilently();
                      widget.onOpenAbout!();
                    },
                  ),
                ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }
}
