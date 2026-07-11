import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/models/currency_config.dart';

class ClientCard extends ConsumerStatefulWidget {
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
  ConsumerState<ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends ConsumerState<ClientCard> {
  bool _isHovered = false;

  List<Color> _getClientGradientColors(String id) {
    final colorsList = [
      [const Color(0xFF0D9488), const Color(0xFF10B981)], // Teal-emerald
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

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF151D2A) : Colors.white,
        title: const Text('Delete Client', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${widget.client.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(clientProvider.notifier).deleteClient(widget.client.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete client: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildClientMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 18,
      onSelected: (value) {
        if (value == 'details') {
          widget.onTap();
        } else if (value == 'delete') {
          _showDeleteConfirmation(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16),
              SizedBox(width: 8),
              Text('Details', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
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

    final avatarColors = _getClientGradientColors(widget.client.id);

    // Active state is defined by whether a clientUserId has accepted the sync invitation
    final isActive = widget.client.clientUserId != null;

    final paidRevenue = widget.totalRevenue - widget.pendingRevenue;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        child: Card(
          elevation: _isHovered ? (isDark ? 5.0 : 4.0) : (isDark ? 0 : 2.0),
          shadowColor: isDark
              ? (_isHovered ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent)
              : const Color(0x0A0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
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
                  // Row 1: Header (Avatar, Name, Chip, Status text, Popup Menu)
                  Row(
                    children: [
                      // Squircle Avatar Stack with Status Dot
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: avatarColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14.0),
                              boxShadow: [
                                BoxShadow(
                                  color: avatarColors[0].withValues(alpha: 0.2),
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
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.client.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Company/Role Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                widget.client.company != null && widget.client.company!.isNotEmpty
                                    ? widget.client.company!
                                    : 'Freelancer',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Status Dot + Text (Active/Inactive)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      // Three-dot popup menu
                      _buildClientMenu(context),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Row 2: LayoutBuilder for Adaptive Columns (Prevents cropping on mobile)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useMobile = constraints.maxWidth < 480;

                      if (useMobile) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 2x2 Grid of Metrics to give each double horizontal space
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMetricColumn(
                                          label: 'Revenue',
                                          value: c.format(widget.totalRevenue),
                                          iconColor: const Color(0xFF10B981),
                                          isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMetricColumn(
                                          label: 'Projects',
                                          value: '${widget.projectCount}',
                                          icon: Icons.folder_open_rounded,
                                          iconColor: const Color(0xFF3B82F6),
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMetricColumn(
                                          label: 'Pending',
                                          value: c.format(widget.pendingRevenue),
                                          icon: Icons.hourglass_empty_rounded,
                                          iconColor: const Color(0xFFF59E0B),
                                          isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMetricColumn(
                                          label: 'Paid',
                                          value: c.format(paidRevenue),
                                          icon: Icons.check_circle_outline_rounded,
                                          iconColor: const Color(0xFF10B981),
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Stacked Action Buttons matching 2-row height
                            if (hasPhone)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _compactActionButton(
                                    icon: Icons.phone_outlined,
                                    tooltip: 'Call ${widget.client.phone}',
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    isDark: isDark,
                                    onTap: () => _launch('tel:${widget.client.phone}'),
                                  ),
                                  const SizedBox(height: 8),
                                  _compactActionButton(
                                    imagePath: 'assets/images/whatsapp_logo.png',
                                    tooltip: 'WhatsApp ${widget.client.phone}',
                                    color: const Color(0xFF25D366),
                                    isDark: isDark,
                                    onTap: () => _launch('https://wa.me/${widget.client.phone}'),
                                  ),
                                ],
                              )
                            else if (hasEmail)
                              _compactActionButton(
                                icon: Icons.mail_outline_rounded,
                                tooltip: 'Email ${widget.client.email}',
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                isDark: isDark,
                                onTap: () => _launch('mailto:${widget.client.email}'),
                              ),
                          ],
                        );
                      }

                      // Desktop / Tablet Layout: Row with Dividers
                      return Row(
                        children: [
                          Expanded(
                            child: _buildMetricColumn(
                              label: 'Revenue',
                              value: c.format(widget.totalRevenue),
                              iconColor: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                          _buildDivider(isDark),
                          Expanded(
                            child: _buildMetricColumn(
                              label: 'Projects',
                              value: '${widget.projectCount}',
                              icon: Icons.folder_open_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              isDark: isDark,
                            ),
                          ),
                          _buildDivider(isDark),
                          Expanded(
                            child: _buildMetricColumn(
                              label: 'Pending',
                              value: c.format(widget.pendingRevenue),
                              icon: Icons.hourglass_empty_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              isDark: isDark,
                            ),
                          ),
                          _buildDivider(isDark),
                          Expanded(
                            child: _buildMetricColumn(
                              label: 'Paid',
                              value: c.format(paidRevenue),
                              icon: Icons.check_circle_outline_rounded,
                              iconColor: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 14),
                          if (hasPhone) ...[
                            _compactActionButton(
                              icon: Icons.phone_outlined,
                              tooltip: 'Call ${widget.client.phone}',
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              isDark: isDark,
                              onTap: () => _launch('tel:${widget.client.phone}'),
                            ),
                            const SizedBox(width: 8),
                            _compactActionButton(
                              imagePath: 'assets/images/whatsapp_logo.png',
                              tooltip: 'WhatsApp ${widget.client.phone}',
                              color: const Color(0xFF25D366),
                              isDark: isDark,
                              onTap: () => _launch('https://wa.me/${widget.client.phone}'),
                            ),
                          ] else if (hasEmail) ...[
                            _compactActionButton(
                              icon: Icons.mail_outline_rounded,
                              tooltip: 'Email ${widget.client.email}',
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              isDark: isDark,
                              onTap: () => _launch('mailto:${widget.client.email}'),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 28,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildMetricColumn({
    IconData? icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactActionButton({
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
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: imagePath != null
                ? Image.asset(
                    imagePath,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: color,
                  ),
          ),
        ),
      ),
    );
  }
}
