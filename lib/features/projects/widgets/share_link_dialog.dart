import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/review_provider.dart';

class ShareLinkDialog extends ConsumerStatefulWidget {
  final String reviewId;

  const ShareLinkDialog({
    super.key,
    required this.reviewId,
  });

  @override
  ConsumerState<ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends ConsumerState<ShareLinkDialog> {
  int? _selectedExpiryHours = 24; // Default: 24 Hours
  String? _generatedLink;
  bool _isGenerating = false;
  bool _copied = false;

  final List<({String label, int? value})> _expiryOptions = const [
    (label: '12 Hours', value: 12),
    (label: '24 Hours', value: 24),
    (label: '48 Hours', value: 48),
    (label: 'Never Expires', value: null),
  ];

  Future<void> _generateLink() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final repo = ref.read(reviewRepositoryProvider);
      final token = await repo.createShareLink(widget.reviewId, _selectedExpiryHours);
      
      // Construct public web deep link
      final link = 'https://editflow.acsoft.online/app/#/share/review/$token';

      setState(() {
        _generatedLink = link;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate link: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_generatedLink == null) return;
    Clipboard.setData(ClipboardData(text: _generatedLink!));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D16) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.share, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Share Guest Review Link',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.clear_circled_solid, size: 22, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a cryptographically secure player link for stakeholders to view and add timestamped comments without registering an account.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),

            if (_generatedLink == null) ...[
              // Link Expiry Option Selection
              const Text(
                'Select Expiry Duration:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _expiryOptions.map((opt) {
                  final isSelected = opt.value == _selectedExpiryHours;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedExpiryHours = opt.value;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.primary 
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isGenerating ? null : _generateLink,
                    child: _isGenerating
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text('Generate Shareable Link', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ] else ...[
              // Generated Link Display
              const Text(
                'Review Link Generated Successfully:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111625) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : Colors.black12,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.link, color: AppColors.primary, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _generatedLink!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _copied 
                          ? [Colors.green, Colors.teal] 
                          : [const Color(0xFF0D9488), const Color(0xFF10B981)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_copied ? Icons.check_circle_rounded : Icons.copy_rounded, size: 18),
                    label: Text(
                      _copied ? 'Copied to Clipboard!' : 'Copy Link',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _copyToClipboard,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
