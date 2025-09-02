import 'package:flutter/material.dart';
import '../../data/models/issue_model.dart';

class IssueCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onIssueResolved;
  final VoidCallback? onIssueDeleted;

  const IssueCard({
    super.key,
    required this.issue,
    this.onIssueResolved,
    this.onIssueDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(issue.category),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getCategoryText(issue.category),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(issue.priority),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getPriorityText(issue.priority),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              issue.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Ekleyen: ${issue.createdBy}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(issue.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (!issue.isResolved) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onIssueResolved,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Çözüldü'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(context),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Çözüldü - ${issue.resolvedBy ?? 'Bilinmiyor'}',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                  const Spacer(),
                  if (issue.resolvedAt != null) ...[
                    Icon(Icons.schedule, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(issue.resolvedAt!),
                      style: TextStyle(fontSize: 12, color: Colors.green[600]),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getCategoryText(IssueCategory category) {
    switch (category) {
      case IssueCategory.equipment:
        return 'Ekipman';
      case IssueCategory.supplies:
        return 'Malzeme';
      case IssueCategory.maintenance:
        return 'Bakım';
      case IssueCategory.safety:
        return 'Güvenlik';
      case IssueCategory.other:
        return 'Diğer';
    }
  }

  Color _getCategoryColor(IssueCategory category) {
    switch (category) {
      case IssueCategory.equipment:
        return Colors.blue;
      case IssueCategory.supplies:
        return Colors.orange;
      case IssueCategory.maintenance:
        return Colors.purple;
      case IssueCategory.safety:
        return Colors.red;
      case IssueCategory.other:
        return Colors.grey;
    }
  }

  String _getPriorityText(IssuePriority priority) {
    switch (priority) {
      case IssuePriority.low:
        return 'Düşük';
      case IssuePriority.medium:
        return 'Orta';
      case IssuePriority.high:
        return 'Yüksek';
      case IssuePriority.urgent:
        return 'Acil';
    }
  }

  Color _getPriorityColor(IssuePriority priority) {
    switch (priority) {
      case IssuePriority.low:
        return Colors.green;
      case IssuePriority.medium:
        return Colors.orange;
      case IssuePriority.high:
        return Colors.red;
      case IssuePriority.urgent:
        return Colors.purple;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eksik Sil'),
        content: const Text('Bu eksiği silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onIssueDeleted != null) {
                onIssueDeleted!();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
