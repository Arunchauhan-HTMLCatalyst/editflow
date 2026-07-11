import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

/// Platform metadata for a detected link
class _LinkPlatform {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _LinkPlatform(this.label, this.icon, this.color, this.bgColor);
}

/// Detects platform from URL and returns appropriate styling
_LinkPlatform _detectPlatform(String url) {
  final lower = url.toLowerCase();

  if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
    return _LinkPlatform('YouTube', Icons.play_circle_fill_rounded, const Color(0xFFFF0000), const Color(0xFFFF0000).withAlpha(18));
  }
  if (lower.contains('instagram.com')) {
    return _LinkPlatform('Instagram', Icons.camera_alt_rounded, const Color(0xFFE1306C), const Color(0xFFE1306C).withAlpha(18));
  }
  if (lower.contains('figma.com')) {
    return _LinkPlatform('Figma', Icons.auto_fix_high_rounded, const Color(0xFFA259FF), const Color(0xFFA259FF).withAlpha(18));
  }
  if (lower.contains('github.com')) {
    return _LinkPlatform('GitHub', Icons.code_rounded, const Color(0xFF6E40C9), const Color(0xFF6E40C9).withAlpha(18));
  }
  if (lower.contains('drive.google.com') || lower.contains('docs.google.com')) {
    return _LinkPlatform('Google Drive', Icons.folder_rounded, const Color(0xFF4285F4), const Color(0xFF4285F4).withAlpha(18));
  }
  if (lower.contains('behance.net')) {
    return _LinkPlatform('Behance', Icons.palette_rounded, const Color(0xFF1769FF), const Color(0xFF1769FF).withAlpha(18));
  }
  if (lower.contains('dribbble.com')) {
    return _LinkPlatform('Dribbble', Icons.sports_basketball_rounded, const Color(0xFFEA4C89), const Color(0xFFEA4C89).withAlpha(18));
  }
  if (lower.contains('notion.so') || lower.contains('notion.site')) {
    return _LinkPlatform('Notion', Icons.description_rounded, const Color(0xFF000000), const Color(0xFF000000).withAlpha(15));
  }
  if (lower.contains('linkedin.com')) {
    return _LinkPlatform('LinkedIn', Icons.business_rounded, const Color(0xFF0A66C2), const Color(0xFF0A66C2).withAlpha(18));
  }
  if (lower.contains('twitter.com') || lower.contains('x.com')) {
    return _LinkPlatform('X / Twitter', Icons.tag_rounded, const Color(0xFF1DA1F2), const Color(0xFF1DA1F2).withAlpha(18));
  }
  if (lower.contains('trello.com')) {
    return _LinkPlatform('Trello', Icons.dashboard_rounded, const Color(0xFF0079BF), const Color(0xFF0079BF).withAlpha(18));
  }
  if (lower.contains('slack.com')) {
    return _LinkPlatform('Slack', Icons.chat_rounded, const Color(0xFF4A154B), const Color(0xFF4A154B).withAlpha(18));
  }
  if (lower.contains('canva.com')) {
    return _LinkPlatform('Canva', Icons.brush_rounded, const Color(0xFF00C4CC), const Color(0xFF00C4CC).withAlpha(18));
  }
  if (lower.contains('pinterest.com')) {
    return _LinkPlatform('Pinterest', Icons.push_pin_rounded, const Color(0xFFE60023), const Color(0xFFE60023).withAlpha(18));
  }
  if (lower.contains('dropbox.com')) {
    return _LinkPlatform('Dropbox', Icons.cloud_rounded, const Color(0xFF0061FF), const Color(0xFF0061FF).withAlpha(18));
  }
  if (lower.contains('vimeo.com')) {
    return _LinkPlatform('Vimeo', Icons.videocam_rounded, const Color(0xFF1AB7EA), const Color(0xFF1AB7EA).withAlpha(18));
  }
  if (lower.contains('facebook.com') || lower.contains('fb.com')) {
    return _LinkPlatform('Facebook', Icons.facebook_rounded, const Color(0xFF1877F2), const Color(0xFF1877F2).withAlpha(18));
  }
  if (lower.contains('whatsapp.com') || lower.contains('wa.me')) {
    return _LinkPlatform('WhatsApp', Icons.chat_bubble_rounded, const Color(0xFF25D366), const Color(0xFF25D366).withAlpha(18));
  }
  if (lower.contains('telegram.org') || lower.contains('t.me')) {
    return _LinkPlatform('Telegram', Icons.send_rounded, const Color(0xFF0088CC), const Color(0xFF0088CC).withAlpha(18));
  }
  // Generic link
  return _LinkPlatform('Link', Icons.open_in_new_rounded, AppColors.primary, AppColors.primary.withAlpha(18));
}

/// URL regex
final _urlRegex = RegExp(
  r'https?://[^\s<>\[\]()]+',
  caseSensitive: false,
);

/// Extracts a display-friendly hostname from a URL
String _displayHost(String url) {
  try {
    final uri = Uri.parse(url);
    String host = uri.host;
    if (host.startsWith('www.')) host = host.substring(4);
    final path = uri.path.length > 20
        ? '${uri.path.substring(0, 20)}…'
        : uri.path;
    return path.length > 1 ? '$host$path' : host;
  } catch (_) {
    return url.length > 40 ? '${url.substring(0, 40)}…' : url;
  }
}

/// A widget that renders text with inline URLs detected and shown as
/// tappable compact styled chips with platform icons.
class RichLinkText extends StatelessWidget {
  final String text;
  final bool isDark;
  final TextStyle? textStyle;

  const RichLinkText({
    super.key,
    required this.text,
    required this.isDark,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final matches = _urlRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: textStyle ?? TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: isDark ? AppColors.textSecondary : const Color(0xFF334155),
        ),
      );
    }

    final widgets = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final segment = text.substring(lastEnd, match.start).trim();
        if (segment.isNotEmpty) {
          widgets.add(
            Text(
              segment,
              style: textStyle ?? TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? AppColors.textSecondary : const Color(0xFF334155),
              ),
            ),
          );
        }
      }
      final url = match.group(0)!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: LinkBubble(url: url, isDark: isDark),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final segment = text.substring(lastEnd).trim();
      if (segment.isNotEmpty) {
        widgets.add(
          Text(
            segment,
            style: textStyle ?? TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? AppColors.textSecondary : const Color(0xFF334155),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// A compact styled link chip with platform icon, label, and open action.
class LinkBubble extends StatelessWidget {
  final String url;
  final bool isDark;

  const LinkBubble({
    super.key,
    required this.url,
    required this.isDark,
  });

  Future<void> _openLink() async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[LinkBubble] Failed to launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = _detectPlatform(url);
    final host = _displayHost(url);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openLink,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(platform.icon, size: 13, color: platform.color),
              const SizedBox(width: 6),
              Text(
                platform.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  host,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 11,
                color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
