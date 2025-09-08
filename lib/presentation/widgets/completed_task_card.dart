import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/admin_user_repository.dart';
import 'task_complaint_dialog.dart';

class CompletedTaskCard extends StatefulWidget {
  final Task task;

  const CompletedTaskCard({
    super.key,
    required this.task,
  });

  @override
  State<CompletedTaskCard> createState() => _CompletedTaskCardState();
}

class _CompletedTaskCardState extends State<CompletedTaskCard> {
  String _staffNames = '';
  bool _isLoadingStaffNames = false;

  @override
  void initState() {
    super.initState();
    _loadStaffNames();
  }

  @override
  void didUpdateWidget(CompletedTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Görev güncellendiğinde personel isimlerini yeniden yükle
    if (oldWidget.task.completedByStaffIds != widget.task.completedByStaffIds) {
      _loadStaffNames();
    }
  }

  Future<void> _loadStaffNames() async {
    // Sadece tamamlanan görevler için personel isimlerini yükle
    if (widget.task.status != TaskStatus.completed || widget.task.completedByStaffIds.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingStaffNames = true;
    });

    try {
      final names = await _getStaffNamesFromAdmin(widget.task.completedByStaffIds);
      if (mounted) {
        setState(() {
          _staffNames = names;
          _isLoadingStaffNames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _staffNames = 'Bilinmeyen Personel';
          _isLoadingStaffNames = false;
        });
      }
    }
  }

  Color _getDifficultyColor(TaskDifficulty difficulty) {
    switch (difficulty) {
      case TaskDifficulty.easy:
        return Colors.green;
      case TaskDifficulty.medium:
        return Colors.orange;
      case TaskDifficulty.hard:
        return Colors.red;
    }
  }

  String _getDifficultyText(TaskDifficulty difficulty) {
    switch (difficulty) {
      case TaskDifficulty.easy:
        return 'Kolay';
      case TaskDifficulty.medium:
        return 'Orta';
      case TaskDifficulty.hard:
        return 'Zor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(widget.task.difficulty),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDifficultyText(widget.task.difficulty),
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
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Tamamlandı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.task.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (widget.task.completedAt != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Tamamlanma: ${_formatDateTime(widget.task.completedAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (widget.task.completedByStaffIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _isLoadingStaffNames
                        ? Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Yükleniyor...',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tamamlayan: $_staffNames',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
            // Şikayetler bölümü
            if (widget.task.complaints.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem, size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Şikayetler (${widget.task.complaints.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.task.complaints.map((complaint) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                complaint.isAnonymous ? 'Anonim' : (complaint.reporterName ?? 'Bilinmeyen'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDateTime(complaint.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            complaint.complaintText,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (complaint.complaintImageUrl != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                complaint.complaintImageUrl!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
            if (widget.task.completedImageUrl != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.task.completedImageUrl!,
                    height: 500,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 500,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Görsel yükleniyor...',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 500,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'Görsel yüklenemedi',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            // Şikayet et butonu
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => TaskComplaintDialog(task: widget.task),
                  );
                  
                  if (result == true && mounted) {
                    // Şikayet eklendiyse kartı yenile
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.report_problem, size: 18),
                label: const Text('Şikayet Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }


  // Admin kullanıcılarından personel isimlerini al
  Future<String> _getStaffNamesFromAdmin(List<String> staffIds) async {
    try {
      final adminUserRepository = AdminUserRepository();
      final allAdminUsers = await adminUserRepository.getAllAdminUsers();
      
      // Eğer staffIds boşsa, boş string döndür
      if (staffIds.isEmpty) {
        return 'Personel bilgisi yok';
      }
      
      final staffNames = <String>[];
      
      for (final staffId in staffIds) {
        String staffName = 'Bilinmeyen Personel';
        
        // Tüm admin kullanıcıları arasında ara
        for (final adminUser in allAdminUsers) {
          // ID ile eşleştir
          if (adminUser.id == staffId) {
            staffName = adminUser.name;
            break;
          }
          // Email ile eşleştir
          if (adminUser.email == staffId) {
            staffName = adminUser.name;
            break;
          }
          // Name ile eşleştir
          if (adminUser.name == staffId) {
            staffName = adminUser.name;
            break;
          }
        }
        
        staffNames.add(staffName);
      }
      
      return staffNames.join(', ');
    } catch (e) {
      return 'Personel bilgisi alınamadı';
    }
  }
}
