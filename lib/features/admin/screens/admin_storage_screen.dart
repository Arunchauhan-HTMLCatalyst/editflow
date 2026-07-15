import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/admin_provider.dart';

class AdminStorageScreen extends ConsumerWidget {
  const AdminStorageScreen({super.key});

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(adminStorageProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return storageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
      data: (data) {
        final totalUsed = data['totalStorageUsed'] ?? 0;
        final largestFiles = data['largestFiles'] as List? ?? [];
        final userUsage = data['userUsage'] as Map? ?? {};

        // Sort user usage list
        final userList = userUsage.entries.map((e) => _UserStorageEntry(e.key.toString(), e.value as num)).toList();
        userList.sort((a, b) => b.bytes.compareTo(a.bytes));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStorageProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Storage Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.8),
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.05), Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL PLATFORM STORAGE IN USE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.storage_rounded, size: 28, color: AppColors.primaryNeon),
                          const SizedBox(width: 16),
                          Text(
                            _formatBytes(totalUsed),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: User Footprints
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'STORAGE BY USER FOLDER',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          if (userList.isEmpty)
                            _buildEmptyPlaceholder('No user folders found.')
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 0.8),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: userList.length,
                                separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                                itemBuilder: (context, idx) {
                                  final entry = userList[idx];
                                  final maxBytes = userList.first.bytes;
                                  final ratio = maxBytes > 0 ? (entry.bytes / maxBytes).clamp(0.0, 1.0) : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Folder: ${entry.userId}',
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatBytes(entry.bytes),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNeon),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: ratio,
                                            minHeight: 6,
                                            backgroundColor: AppColors.border,
                                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (isDesktop) const SizedBox(width: 24),

                    // Right Column: Largest Files
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LARGEST PLATFORM FILES',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          if (largestFiles.isEmpty)
                            _buildEmptyPlaceholder('No files detected in buckets.')
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 0.8),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: largestFiles.length,
                                separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                                itemBuilder: (context, idx) {
                                  final file = largestFiles[idx] as Map<String, dynamic>;
                                  final name = file['name'] as String? ?? '';
                                  final bucket = file['bucket'] as String? ?? '';
                                  final sizeBytes = file['sizeBytes'] ?? 0;
                                  final createdStr = file['createdAt'] as String?;
                                  final createdDate = createdStr != null
                                      ? DateFormat('MMM d, HH:mm').format(DateTime.parse(createdStr))
                                      : 'Unknown';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            bucket == 'video-reviews' ? Icons.video_collection_rounded : Icons.audiotrack_rounded,
                                            color: AppColors.primaryNeon,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Bucket: $bucket • Uploaded: $createdDate',
                                                style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _formatBytes(sizeBytes),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
    );
  }
}

class _UserStorageEntry {
  final String userId;
  final num bytes;
  _UserStorageEntry(this.userId, this.bytes);
}
