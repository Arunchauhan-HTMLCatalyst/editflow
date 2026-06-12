enum ProjectStatus {
  yetToStart('yet_to_start'),
  inProgress('in_progress'),
  revisionPending('revision_pending'),
  completed('completed'),
  paid('paid');

  final String value;
  const ProjectStatus(this.value);

  static ProjectStatus fromString(String s) =>
      ProjectStatus.values.firstWhere((e) => e.value == s, orElse: () => ProjectStatus.yetToStart);

  String get displayName {
    switch (this) {
      case ProjectStatus.yetToStart:
        return 'Yet to Start';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.revisionPending:
        return 'Revision Pending';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.paid:
        return 'Paid';
    }
  }

  int get orderIndex {
    switch (this) {
      case ProjectStatus.yetToStart:
        return 0;
      case ProjectStatus.inProgress:
        return 1;
      case ProjectStatus.revisionPending:
        return 2;
      case ProjectStatus.completed:
        return 3;
      case ProjectStatus.paid:
        return 4;
    }
  }
}
