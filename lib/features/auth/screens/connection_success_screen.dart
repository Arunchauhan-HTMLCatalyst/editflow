import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ambient_glow_container.dart';
import '../../clients/providers/client_provider.dart';
import '../../projects/providers/project_provider.dart';

class ConnectionSuccessScreen extends ConsumerStatefulWidget {
  final String inviteCode;

  const ConnectionSuccessScreen({super.key, required this.inviteCode});

  @override
  ConsumerState<ConnectionSuccessScreen> createState() => _ConnectionSuccessScreenState();
}

class _ConnectionSuccessScreenState extends ConsumerState<ConnectionSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  String? _clientName;
  String? _freelancerName;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _loadConnectionDetails();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadConnectionDetails() async {
    try {
      final uid = ref.read(authProvider).user?.id ?? SupabaseService.userId;

      // 1. Perform database update to link client to this workspace
      await SupabaseService.instance
          .from('clients')
          .update({'client_user_id': uid})
          .eq('id', widget.inviteCode);

      // 2. Invalidate providers so the client instantly sees the workspace data
      ref.invalidate(clientProvider);
      ref.invalidate(projectProvider);

      // 3. Fetch names to show personalized success message
      final clientRow = await SupabaseService.instance
          .from('clients')
          .select('name, user_id')
          .eq('id', widget.inviteCode)
          .single();

      final freelancerRow = await SupabaseService.instance
          .from('profiles')
          .select('full_name')
          .eq('id', clientRow['user_id'])
          .single();

      if (mounted) {
        setState(() {
          _clientName = clientRow['name'] as String?;
          _freelancerName = freelancerRow['full_name'] as String?;
          _isLoading = false;
        });
        _controller.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlowContainer(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A1B) : Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _errorMessage != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: AppColors.error,
                                  size: 56,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Connection Failed',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'We couldn\'t load the connection details. The invite code may be invalid.',
                                  textAlign: Center,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => context.go('/dashboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text('Go to Dashboard'),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: FadeTransition(
                                    opacity: _opacityAnimation,
                                    child: Container(
                                      padding: const EdgeInsets.all(16.0),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.2),
                                          width: 2.0,
                                        ),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        color: AppColors.success,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'Connection Successful!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Hello ${_clientName ?? 'Client'}, you are now connected to ${_freelancerName ?? 'Freelancer\'s Workspace'} on EditFlow.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You can now view project drafts, track timeline milestones, and leave comments directly on video reviews.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton(
                                  onPressed: () => context.go('/dashboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Enter Dashboard',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
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
    );
  }
}
