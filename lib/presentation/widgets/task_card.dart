import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/models/staff_model.dart';
import '../../data/repositories/admin_user_repository.dart';
import 'complete_task_dialog.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback onTaskCompleted;
  final VoidCallback? onTaskDeleted;
  final List<Staff>? allStaff;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTaskCompleted,
    this.onTaskDeleted,
    this.allStaff,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  String _staffNames = '';
  bool _isLoadingStaffNames = false;

  @override
  void initState() {
    super.initState();
    _loadStaffNames();
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Görev güncellendiğinde personel isimlerini yeniden yükle
    if (oldWidget.task.completedByStaffIds != widget.task.completedByStaffIds) {
      _loadStaffNames();
    }
  }

  Future<void> _loadStaffNames() async {
    // Debug log'ları ekrana yazdır
    print('TASK_CARD: _loadStaffNames çağrıldı');
    print('TASK_CARD: Task status: ${widget.task.status}');
    print('TASK_CARD: completedByStaffIds: ${widget.task.completedByStaffIds}');
    print('TASK_CARD: completedByStaffIds length: ${widget.task.completedByStaffIds.length}');
    
    // Sadece tamamlanan görevler için personel isimlerini yükle
    if (widget.task.status != TaskStatus.completed || widget.task.completedByStaffIds.isEmpty) {
      print('TASK_CARD: Koşullar sağlanmadı - status: ${widget.task.status}, isEmpty: ${widget.task.completedByStaffIds.isEmpty}');
      return;
    }
    
    print('TASK_CARD: Personel isimleri yükleniyor...');
    setState(() {
      _isLoadingStaffNames = true;
    });

    try {
      final names = await _getStaffNamesFromAdmin(widget.task.completedByStaffIds);
      print('TASK_CARD: Alınan isimler: $names');
      if (mounted) {
        setState(() {
          _staffNames = names;
          _isLoadingStaffNames = false;
        });
        print('TASK_CARD: State güncellendi: $_staffNames');
      }
    } catch (e) {
      print('TASK_CARD: Hata: $e');
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

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Bekliyor';
      case TaskStatus.inProgress:
        return 'Devam Ediyor';
      case TaskStatus.completed:
        return 'Tamamlandı';
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
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
                    color: _getStatusColor(widget.task.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(widget.task.status),
                    style: const TextStyle(
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
                              const SizedBox(height: 4),
                              Text(
                                'DEBUG: ${widget.task.completedByStaffIds}',
                                style: TextStyle(fontSize: 10, color: Colors.red[600]),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Tüm görevler için "Görevi Tamamla" butonu (pending ve completed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCompleteTaskDialog(context),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Görevi Tamamla'),
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
      print('TASK_CARD: _getStaffNamesFromAdmin başladı');
      print('TASK_CARD: Aranan staffIds: $staffIds');
      print('TASK_CARD: staffIds length: ${staffIds.length}');
      
      final adminUserRepository = AdminUserRepository();
      final allAdminUsers = await adminUserRepository.getAllAdminUsers();
      
      print('TASK_CARD: Tüm admin kullanıcıları sayısı: ${allAdminUsers.length}');
      print('TASK_CARD: Tüm admin kullanıcıları: ${allAdminUsers.map((u) => '${u.id}: ${u.name}').toList()}');
      
      final staffNames = <String>[];
      
      for (int i = 0; i < staffIds.length; i++) {
        final staffId = staffIds[i];
        print('TASK_CARD: ${i + 1}. staffId aranıyor: $staffId');
        String staffName = 'Bilinmeyen Personel';
        
        // Tüm admin kullanıcıları arasında ara
        for (int j = 0; j < allAdminUsers.length; j++) {
          final adminUser = allAdminUsers[j];
          print('TASK_CARD: ${j + 1}. admin user kontrol ediliyor: ${adminUser.id} - ${adminUser.name}');
          
          // ID ile eşleştir
          if (adminUser.id == staffId) {
            staffName = adminUser.name;
            print('TASK_CARD: ID ile bulunan kullanıcı: ${adminUser.name} (${adminUser.id})');
            break;
          }
          // Email ile eşleştir
          if (adminUser.email == staffId) {
            staffName = adminUser.name;
            print('TASK_CARD: Email ile bulunan kullanıcı: ${adminUser.name} (${adminUser.id})');
            break;
          }
          // Name ile eşleştir
          if (adminUser.name == staffId) {
            staffName = adminUser.name;
            print('TASK_CARD: Name ile bulunan kullanıcı: ${adminUser.name} (${adminUser.id})');
            break;
          }
        }
        
        print('TASK_CARD: ${i + 1}. staffId için bulunan isim: $staffName');
        staffNames.add(staffName);
      }
      
      final result = staffNames.join(', ');
      print('TASK_CARD: Final sonuç: $result');
      return result;
    } catch (e) {
      print('TASK_CARD: Personel isimleri alınırken hata: $e');
      return 'Personel bilgisi alınamadı';
    }
  }

  void _showCompleteTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CompleteTaskDialog(
        task: widget.task,
        onTaskCompleted: () {
          // Görev tamamlandığında personel isimlerini yeniden yükle
          _loadStaffNames();
          // CompleteTaskDialog zaten completeTask çağırıyor, burada tekrar çağırmaya gerek yok
          widget.onTaskCompleted();
        },
      ),
    );
  }


  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: const Text('Bu görevi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: TaskRepository ile silme işlemi yapılacak
              // Şimdilik sadece callback ile bildiriyoruz
              if (widget.onTaskDeleted != null) {
                widget.onTaskDeleted!();
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
