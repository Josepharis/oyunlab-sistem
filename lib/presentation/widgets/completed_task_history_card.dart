import 'package:flutter/material.dart';
import '../../data/models/task_completion_history_model.dart';
import '../../data/repositories/admin_user_repository.dart';

class CompletedTaskHistoryCard extends StatefulWidget {
  final TaskCompletionHistory history;

  const CompletedTaskHistoryCard({
    super.key,
    required this.history,
  });

  @override
  State<CompletedTaskHistoryCard> createState() => _CompletedTaskHistoryCardState();
}

class _CompletedTaskHistoryCardState extends State<CompletedTaskHistoryCard> {
  String _staffNames = '';
  bool _isLoadingStaffNames = false;

  @override
  void initState() {
    super.initState();
    _loadStaffNames();
  }

  @override
  void didUpdateWidget(CompletedTaskHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Geçmiş güncellendiğinde personel isimlerini yeniden yükle
    if (oldWidget.history.completedByStaffIds != widget.history.completedByStaffIds) {
      _loadStaffNames();
    }
  }

  Future<void> _loadStaffNames() async {
    if (widget.history.completedByStaffIds.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingStaffNames = true;
    });

    try {
      final names = await _getStaffNamesFromAdmin(widget.history.completedByStaffIds);
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
                    widget.history.taskTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
              widget.history.taskDescription,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Tamamlanma: ${_formatDateTime(widget.history.completedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (widget.history.completedByStaffIds.isNotEmpty) ...[
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
                        : Text(
                            'Tamamlayan: $_staffNames',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                  ),
                ],
              ),
            ],
            if (widget.history.completedImageUrl != null) ...[
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
                    widget.history.completedImageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
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
                        height: 200,
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
      
      print('COMPLETED_TASK_HISTORY_CARD: Aranan staffIds: $staffIds');
      print('COMPLETED_TASK_HISTORY_CARD: Mevcut admin kullanıcıları:');
      for (final adminUser in allAdminUsers) {
        print('  - ID: ${adminUser.id}, Name: ${adminUser.name}, Email: ${adminUser.email}');
      }
      
      final staffNames = <String>[];
      
      for (final staffId in staffIds) {
        String staffName = 'Bilinmeyen Personel';
        
        // Tüm admin kullanıcıları arasında ara
        for (final adminUser in allAdminUsers) {
          // ID ile eşleştir
          if (adminUser.id == staffId) {
            staffName = adminUser.name;
            print('COMPLETED_TASK_HISTORY_CARD: ID eşleşmesi bulundu: $staffId -> ${adminUser.name}');
            break;
          }
          // Email ile eşleştir
          if (adminUser.email == staffId) {
            staffName = adminUser.name;
            print('COMPLETED_TASK_HISTORY_CARD: Email eşleşmesi bulundu: $staffId -> ${adminUser.name}');
            break;
          }
          // Name ile eşleştir
          if (adminUser.name == staffId) {
            staffName = adminUser.name;
            print('COMPLETED_TASK_HISTORY_CARD: Name eşleşmesi bulundu: $staffId -> ${adminUser.name}');
            break;
          }
        }
        
        print('COMPLETED_TASK_HISTORY_CARD: $staffId için bulunan isim: $staffName');
        staffNames.add(staffName);
      }
      
      final result = staffNames.join(', ');
      print('COMPLETED_TASK_HISTORY_CARD: Final result: $result');
      return result;
    } catch (e) {
      print('COMPLETED_TASK_HISTORY_CARD: Hata: $e');
      return 'Personel bilgisi alınamadı';
    }
  }
}
