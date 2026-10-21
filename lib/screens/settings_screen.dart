import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final int practiceDurationMinutes;
  final double instructionDensity;
  final double redirectionDensity;
  final ValueChanged<int> onPracticeDurationChanged;
  final ValueChanged<double> onInstructionDensityChanged;
  final ValueChanged<double> onRedirectionDensityChanged;
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.practiceDurationMinutes,
    required this.instructionDensity,
    required this.redirectionDensity,
    required this.onPracticeDurationChanged,
    required this.onInstructionDensityChanged,
    required this.onRedirectionDensityChanged,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _durationController;
  late FocusNode _durationFocusNode;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _durationController.dispose();
    _durationFocusNode.dispose();
    super.dispose();
  }

  void _validateDuration() {
    final text = _durationController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a duration.';
      });
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 90) {
      setState(() {
        _errorMessage = 'Duration must be between 1 and 90 minutes.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
    });
    widget.onPracticeDurationChanged(parsed);
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
    widget.onPracticeDurationChanged(parsed);
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textBlack),
                    onPressed: _handleBack,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Bubble 1: Default Practice Duration Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Default Practice Duration',
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
                              if (trimmed.isEmpty) {
                                setState(() {
                                  _errorMessage =
                                      'Duration must be between 1 and 90 minutes.';
                                });
                                return;
                              }
                              final parsed = int.tryParse(trimmed);
                              if (parsed == null ||
                                  parsed < 1 ||
                                  parsed > 90) {
                                setState(() {
                                  _errorMessage =
                                      'Duration must be between 1 and 90 minutes.';
                                });
                              } else {
                                setState(() {
                                  _errorMessage = null;
                                });
                                widget.onPracticeDurationChanged(parsed);
                              }
                            },
                            onSubmitted: (_) => _validateDuration(),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
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

              const SizedBox(height: 18),

              // Bubble 2: Instructions and Mind-Wandering Checks Card
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
                    // Instructions density slider
                    Text(
                      '[ ${widget.instructionDensity.toInt()} ]  Instructions',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      value: widget.instructionDensity,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      activeColor: AppColors.darkOlive,
                      inactiveColor: AppColors.pillUnselected,
                      onChanged: widget.onInstructionDensityChanged,
                    ),

                    const SizedBox(height: 20),

                    // Mind-Wandering Checks density slider
                    Text(
                      '[ ${widget.redirectionDensity.toInt()} ]  Mind-Wandering Checks',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      value: widget.redirectionDensity,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      activeColor: AppColors.darkOlive,
                      inactiveColor: AppColors.pillUnselected,
                      onChanged: widget.onRedirectionDensityChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
