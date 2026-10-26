import 'package:flutter/material.dart';
import '../models/voice_config.dart';
import '../theme/app_theme.dart';

/// Reusable Voice Stepper Card / ListTile widget.
/// Used on both the Home Screen (ConfigurationScreen) and ManageVoicesScreen.
/// Reuses the clean styling of the Home Screen Voice ListTile.
class VoiceStepperCard extends StatelessWidget {
  final VoiceConfig voice;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTap;
  final VoidCallback? onLeadingTap;
  final IconData leadingIcon;
  final Widget? trailing;
  final Color? titleColor;
  final String? subtitle;

  const VoiceStepperCard({
    super.key,
    required this.voice,
    this.onPrevious,
    this.onNext,
    this.onTap,
    this.onLeadingTap,
    this.leadingIcon = Icons.record_voice_over,
    this.trailing,
    this.titleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
          // Circular Leading Icon
          if (onLeadingTap != null)
            InkWell(
              onTap: onLeadingTap,
              borderRadius: BorderRadius.circular(21),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundSand,
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: AppColors.textBlack, size: 22),
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.backgroundSand,
                shape: BoxShape.circle,
              ),
              child: Icon(leadingIcon, color: AppColors.textBlack, size: 22),
            ),

          // Previous Chevron
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textBlack),
            onPressed: onPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
            splashRadius: 22,
          ),

          // Voice Info
          Expanded(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            voice.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor ?? AppColors.textBlack,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          voice.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor ?? AppColors.textBlack,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // Next Chevron
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textBlack),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
            splashRadius: 22,
          ),

          // Optional Trailing Widget
          ?trailing,
        ],
      ),
    );
  }
}
