import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/linkified_text.dart';
import '../models/comment.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;
  final bool isCurrentUser;
  final bool isFreelancer;
  final bool isDark;
  final Widget? voicePlayer;
  final Widget? menuButton;

  const CommentCard({
    super.key,
    required this.comment,
    required this.isCurrentUser,
    required this.isFreelancer,
    required this.isDark,
    this.voicePlayer,
    this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d, h:mm a').format(comment.createdAt.toLocal());
    final backgroundColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.45);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Meta row
              Row(
                children: [
                  Text(
                    comment.userName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (isFreelancer ? AppColors.primary : Colors.teal).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (isFreelancer ? AppColors.primary : Colors.teal).withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      isFreelancer ? 'FREELANCER' : 'CLIENT',
                      style: GoogleFonts.inter(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: isFreelancer
                            ? AppColors.primary
                            : (isDark ? Colors.tealAccent : Colors.teal.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 8,
                      color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  ?menuButton,
                ],
              ),
              const SizedBox(height: 6),
              // Content / voice note directly (no nested container padding)
              if (comment.voiceUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: voicePlayer ?? const SizedBox.shrink(),
                )
              else
                LinkifiedText(
                  text: comment.content,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? AppColors.textPrimary : const Color(0xFF1E293B),
                  ),
                  linkStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
