import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../settings/models/currency_config.dart';

class ClientCard extends StatefulWidget {
  final Client client;
  final VoidCallback onTap;
  final double totalRevenue;
  final double pendingRevenue;
  final int projectCount;
  final CurrencyConfig? currency;

  const ClientCard({
    super.key,
    required this.client,
    required this.onTap,
    required this.totalRevenue,
    required this.pendingRevenue,
    required this.projectCount,
    this.currency,
  });

  @override
  State<ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<ClientCard> {
  bool _isHovered = false;

  List<Color> _getClientGradientColors(String id) {
    final colorsList = [
      [const Color(0xFF0D9488), const Color(0xFF10B981)], // Teal-emerald (primary)
      [const Color(0xFF3B82F6), const Color(0xFF06B6D4)], // Blue-cyan
      [const Color(0xFF8B5CF6), const Color(0xFFEC4899)], // Purple-pink
      [const Color(0xFFD97706), const Color(0xFFEF4444)], // Amber-red
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // Indigo-purple
    ];
    final index = id.hashCode.abs() % colorsList.length;
    return colorsList[index];
  }

  Future<void> _launch(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.currency ?? CurrencyConfig.usd;
    
    final initials = widget.client.name.isNotEmpty
        ? widget.client.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : '?';

    final hasEmail = widget.client.email != null && widget.client.email!.isNotEmpty;
    final hasPhone = widget.client.phone != null && widget.client.phone!.isNotEmpty;
    final hasActions = hasEmail || hasPhone;

    final avatarColors = _getClientGradientColors(widget.client.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? (isDark ? 6.0 : 4.0) : (isDark ? 0 : 2.0),
          shadowColor: isDark
              ? (_isHovered ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent)
              : const Color(0x0C0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
              width: _isHovered ? 1.2 : 0.8,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Avatar + Name & Company
                  Row(
                    children: [
                      // Avatar with gradient background & border (Upsized to 52)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: avatarColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: avatarColors[0].withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: avatarColors[0].withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18, // Upsized
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.client.name,
                              style: AppTextStyles.label(isDark).copyWith(
                                fontSize: 17.5, // Upsized
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.client.company != null && widget.client.company!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // Upsized
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surface : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.client.company!,
                                    style: TextStyle(
                                      fontSize: 12.5, // Upsized
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Metrics Cards Row
                  const SizedBox(height: 20), // Upsized
                  Row(
                    children: [
                      Expanded(
                        child: _metricBadge(
                          c.format(widget.totalRevenue),
                          'Revenue',
                          AppColors.success,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.pendingRevenue > 0) ...[
                        Expanded(
                          child: _metricBadge(
                            c.format(widget.pendingRevenue),
                            'Pending',
                            AppColors.warning,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _metricBadge(
                          '${widget.projectCount}',
                          widget.projectCount == 1 ? 'Project' : 'Projects',
                          AppColors.primary,
                          isDark,
                        ),
                      ),
                    ],
                  ),

                  // Quick Action Bar
                  if (hasActions) ...[
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Quick Contact',
                          style: TextStyle(
                            fontSize: 13, // Upsized
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        if (hasEmail)
                          _actionButton(
                            icon: Icons.mail_outline_rounded,
                            tooltip: 'Email ${widget.client.email}',
                            color: AppColors.primary,
                            isDark: isDark,
                            onTap: () => _launch('mailto:${widget.client.email}'),
                          ),
                        if (hasPhone) ...[
                          if (hasEmail) const SizedBox(width: 8),
                          _actionButton(
                            icon: Icons.phone_outlined,
                            tooltip: 'Call ${widget.client.phone}',
                            color: AppColors.info,
                            isDark: isDark,
                            onTap: () => _launch('tel:${widget.client.phone}'),
                          ),
                          const SizedBox(width: 8),
                          _actionButton(
                            imagePath: 'assets/images/whatsapp_logo.png',
                            tooltip: 'WhatsApp ${widget.client.phone}',
                            color: const Color(0xFF25D366),
                            isDark: isDark,
                            onTap: () => _launch('https://wa.me/${widget.client.phone}'),
                          ),
                        ],
                      ],
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

  Widget _metricBadge(String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Upsized
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, // Upsized
                height: 8, // Upsized
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8), // Upsized
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5, // Upsized
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Upsized
          Text(
            value,
            style: TextStyle(
              fontSize: 16, // Upsized to 16
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    IconData? icon,
    String? imagePath,
    required String tooltip,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10), // Upsized
          child: Container(
            width: 38, // Upsized to 38
            height: 38, // Upsized to 38
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10), // Upsized
              border: Border.all(
                color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                width: 0.6,
              ),
            ),
            alignment: Alignment.center,
            child: imagePath != null
                ? Image.asset(
                    imagePath,
                    width: 17, // Upsized to 17
                    height: 17, // Upsized to 17
                    fit: BoxFit.contain,
                  )
                : Icon(
                    icon,
                    size: 18, // Upsized to 18
                    color: isDark ? AppColors.textPrimary.withValues(alpha: 0.9) : const Color(0xFF334155),
                  ),
          ),
        ),
      ),
    );
  }
}
