import 'package:flutter/material.dart';
import '../../features/projects/models/project_status.dart';

Color statusColor(ProjectStatus status) {
  switch (status) {
    case ProjectStatus.yetToStart:
      return const Color(0xFF71717A);
    case ProjectStatus.inProgress:
      return const Color(0xFF8B5CF6);
    case ProjectStatus.revisionPending:
      return const Color(0xFFF59E0B);
    case ProjectStatus.completed:
      return const Color(0xFF3B82F6);
    case ProjectStatus.paid:
      return const Color(0xFF22C55E);
  }
}
