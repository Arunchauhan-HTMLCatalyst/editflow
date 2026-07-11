import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Regex matches http:// and https:// links
    final RegExp urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final List<InlineSpan> spans = [];
    int start = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
        ));
      }

      final String urlString = match.group(0)!;
      
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InlineLinkPreview(url: urlString),
      ));

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
    );
  }
}

class InlineLinkPreview extends StatefulWidget {
  final String url;
  const InlineLinkPreview({super.key, required this.url});

  @override
  State<InlineLinkPreview> createState() => _InlineLinkPreviewState();
}

class _InlineLinkPreviewState extends State<InlineLinkPreview> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String urlLower = widget.url.toLowerCase();

    IconData iconData = Icons.language_rounded;
    Color brandColor = const Color(0xFF64748B);
    String label = 'Link';

    if (urlLower.contains('youtube.com') || urlLower.contains('youtu.be')) {
      iconData = Icons.play_circle_fill_rounded;
      brandColor = const Color(0xFFFF0000);
      label = 'YouTube';
    } else if (urlLower.contains('instagram.com')) {
      iconData = Icons.camera_alt_rounded;
      brandColor = const Color(0xFFE1306C);
      label = 'Instagram';
    } else if (urlLower.contains('facebook.com') || urlLower.contains('fb.com') || urlLower.contains('fb.watch')) {
      iconData = Icons.facebook_rounded;
      brandColor = const Color(0xFF1877F2);
      label = 'Facebook';
    } else if (urlLower.contains('x.com') || urlLower.contains('twitter.com')) {
      iconData = Icons.tag_rounded;
      brandColor = isDark ? Colors.white : const Color(0xFF0F1419);
      label = 'X';
    } else if (urlLower.contains('whatsapp.com') || urlLower.contains('wa.me')) {
      iconData = Icons.chat_bubble_rounded;
      brandColor = const Color(0xFF25D366);
      label = 'WhatsApp';
    } else if (urlLower.contains('linkedin.com')) {
      iconData = Icons.business_rounded;
      brandColor = const Color(0xFF0A66C2);
      label = 'LinkedIn';
    } else {
      // General web link - show hostname/domain
      String displayUrl = widget.url;
      if (displayUrl.startsWith('https://')) displayUrl = displayUrl.substring(8);
      if (displayUrl.startsWith('http://')) displayUrl = displayUrl.substring(7);
      if (displayUrl.startsWith('www.')) displayUrl = displayUrl.substring(4);
      final slashIdx = displayUrl.indexOf('/');
      if (slashIdx != -1) {
        displayUrl = displayUrl.substring(0, slashIdx);
      }
      label = displayUrl.isNotEmpty ? displayUrl : 'Web';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: isDark 
              ? (label == 'X' ? AppColors.surface : brandColor.withValues(alpha: 0.12))
              : brandColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered 
                ? brandColor 
                : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
            width: 0.8,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final Uri? uri = Uri.tryParse(widget.url);
              if (uri != null) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch ${widget.url}: $e');
                }
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    color: brandColor == Colors.white && isDark ? Colors.white : brandColor,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 9,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
