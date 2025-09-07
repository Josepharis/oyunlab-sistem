import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/admin_user_repository.dart';

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
    // Debug log'ları ekrana yazdır
    print('COMPLETED_TASK_CARD: _loadStaffNames çağrıldı');
    print('COMPLETED_TASK_CARD: Task status: ${widget.task.status}');
    print('COMPLETED_TASK_CARD: completedByStaffIds: ${widget.task.completedByStaffIds}');
    print('COMPLETED_TASK_CARD: completedByStaffIds length: ${widget.task.completedByStaffIds.length}');
    
    // Sadece tamamlanan görevler için personel isimlerini yükle
    if (widget.task.status != TaskStatus.completed || widget.task.completedByStaffIds.isEmpty) {
      print('COMPLETED_TASK_CARD: Koşullar sağlanmadı - status: ${widget.task.status}, isEmpty: ${widget.task.completedByStaffIds.isEmpty}');
      return;
    }
    
    print('COMPLETED_TASK_CARD: Personel isimleri yükleniyor...');
    setState(() {
      _isLoadingStaffNames = true;
    });

    try {
      // Admin kullanıcılarını al ve debug için ekrana yazdır
      final adminUserRepository = AdminUserRepository();
      final allAdminUsers = await adminUserRepository.getAllAdminUsers();
      
      print('COMPLETED_TASK_CARD: Admin users: ${allAdminUsers.map((u) => '${u.id}:${u.name}').join(', ')}');
      
      final names = await _getStaffNamesFromAdmin(widget.task.completedByStaffIds);
      print('COMPLETED_TASK_CARD: Alınan isimler: $names');
      if (mounted) {
        setState(() {
          _staffNames = '${names} | Admin: ${allAdminUsers.map((u) => '${u.id}:${u.name}').join(', ')}';
          _isLoadingStaffNames = false;
        });
        print('COMPLETED_TASK_CARD: State güncellendi: $_staffNames');
      }
    } catch (e) {
      print('COMPLETED_TASK_CARD: Hata: $e');
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
                              const SizedBox(height: 4),
                              Text(
                                'DEBUG: ${widget.task.completedByStaffIds}',
                                style: TextStyle(fontSize: 10, color: Colors.red[600]),
                              ),
                              Text(
                                'DEBUG: _staffNames: $_staffNames',
                                style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                              ),
                            ],
                          ),
                  ),
                ],
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
      print('COMPLETED_TASK_CARD: _getStaffNamesFromAdmin başladı');
      print('COMPLETED_TASK_CARD: Aranan staffIds: $staffIds');
      print('COMPLETED_TASK_CARD: staffIds length: ${staffIds.length}');
      
      final adminUserRepository = AdminUserRepository();
      final allAdminUsers = await adminUserRepository.getAllAdminUsers();
      
      print('COMPLETED_TASK_CARD: Tüm admin kullanıcıları sayısı: ${allAdminUsers.length}');
      print('COMPLETED_TASK_CARD: Tüm admin kullanıcıları: ${allAdminUsers.map((u) => '${u.id}: ${u.name}').toList()}');
      
      // Eğer staffIds boşsa, boş string döndür
      if (staffIds.isEmpty) {
        print('COMPLETED_TASK_CARD: staffIds boş, personel bilgisi yok döndürülüyor');
        return 'Personel bilgisi yok';
      }
      
      final staffNames = <String>[];
      
      for (int i = 0; i < staffIds.length; i++) {
        final staffId = staffIds[i];
        print('COMPLETED_TASK_CARD: ${i + 1}. staffId aranıyor: $staffId');
        String staffName = 'Bilinmeyen Personel';
        
        // Tüm admin kullanıcıları arasında ara
        for (int j = 0; j < allAdminUsers.length; j++) {
          final adminUser = allAdminUsers[j];
          print('COMPLETED_TASK_CARD: ${j + 1}. admin user kontrol ediliyor: ${adminUser.id} - ${adminUser.name}');
          
          // ID ile eşleştir
          if (adminUser.id == staffId) {
            staffName = adminUser.name;
            print('COMPLETED_TASK_CARD: ID ile bulunan kullanıcı: ${adminUser.name} (${adminUser.id})');
            break;
          }
          // Email ile eşleştir
          if (adminUser.email == staffId) {
            staffName = adminUser.name;
            print('COMPLETED_TASK_CARD: Email ile bulunan kullanıcı: ${adminUser.name} (${adminUser.id})');
            break;
          }
          // Name ile eşleştir
          if (adminUser.name == staffId) {
            staffName = adminUser.name;
            print('COMPLETED_TASK_CARD: Name ile bulunan kullanıcı: ${adminUser.name} (${adminUser.id})');
            break;
          }
        }
        
        print('COMPLETED_TASK_CARD: ${i + 1}. staffId için bulunan isim: $staffName');
        staffNames.add(staffName);
      }
      
      final result = staffNames.join(', ');
      print('COMPLETED_TASK_CARD: Final sonuç: $result');
      return result;
    } catch (e) {
      print('COMPLETED_TASK_CARD: Personel isimleri alınırken hata: $e');
      return 'Personel bilgisi alınamadı';
    }
  }
}
