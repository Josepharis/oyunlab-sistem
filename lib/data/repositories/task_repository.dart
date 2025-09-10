import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../models/task_model.dart';
import '../models/task_score_model.dart';
import '../models/task_completion_history_model.dart';
import '../services/firebase_service.dart';

class TaskRepository {
  final FirebaseService _firebaseService;
  final Uuid _uuid = Uuid();
  bool _isOfflineMode = false;
  Timer? _dailyResetTimer;

  TaskRepository(this._firebaseService);

  /// Çevrimdışı modu ayarla
  void setOfflineMode(bool isOffline) {
    _isOfflineMode = isOffline;
  }

  /// Tüm bekleyen görevleri getir
  Future<List<Task>> getPendingTasks() async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final tasksData = await _firebaseService.getTasks();
      final tasks = tasksData.map((data) => Task.fromJson(data)).toList();
      return tasks
          .where((task) => task.status == TaskStatus.pending)
          .toList();
    } catch (e) {
      print('Bekleyen görevler alınırken hata: $e');
      return [];
    }
  }

  /// Tüm tamamlanan görevleri getir
  Future<List<Task>> getCompletedTasks() async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final tasksData = await _firebaseService.getTasks();
      final tasks = tasksData.map((data) => Task.fromJson(data)).toList();
      return tasks
          .where((task) => task.status == TaskStatus.completed)
          .toList();
    } catch (e) {
      print('Tamamlanan görevler alınırken hata: $e');
      return [];
    }
  }

  /// Tüm görevleri getir
  Future<List<Task>> getAllTasks() async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final tasksData = await _firebaseService.getTasks();
      return tasksData.map((data) => Task.fromJson(data)).toList();
    } catch (e) {
      print('Tüm görevler alınırken hata: $e');
      return [];
    }
  }

  /// Yeni görev oluştur
  Future<void> createTask(Task task) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görev oluşturulamaz');
        return;
      }

      final taskWithId = task.copyWith(id: _uuid.v4());
      final json = taskWithId.toJson();

      await _firebaseService.addTask(json);
      print('TASK_REPO: Görev başarıyla oluşturuldu: ${task.title}');
    } catch (e) {
      print('TASK_REPO: Görev oluşturulurken hata: $e');
      rethrow;
    }
  }

  /// Görevi güncelle
  Future<void> updateTask(Task task) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görev güncellenemez');
        return;
      }

      final json = task.toJson();
      print('TASK_REPO: updateTask JSON completedByStaffIds: ${json['completedByStaffIds']}');
      await _firebaseService.updateTask(task.id, json);
      print('TASK_REPO: Görev başarıyla güncellendi: ${task.title}');
    } catch (e) {
      print('TASK_REPO: Görev güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Görevi tamamla
  Future<void> completeTask(
    String taskId,
    List<String> completedByStaffIds,
    String? completedImageUrl,
  ) async {
    try {
      print('TASK_REPO: completeTask çağrıldı');
      print('TASK_REPO: taskId: $taskId');
      print('TASK_REPO: completedByStaffIds: $completedByStaffIds');
      print('TASK_REPO: completedImageUrl: $completedImageUrl');
      
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görev tamamlanamaz');
        return;
      }

      final taskData = await _firebaseService.getTask(taskId);
      if (taskData != null) {
        final task = Task.fromJson(taskData);
        final now = DateTime.now();
        
        print('TASK_REPO: Mevcut görev bulundu: ${task.title}');
        print('TASK_REPO: Eski completedByStaffIds: ${task.completedByStaffIds}');
        print('TASK_REPO: Yeni completedByStaffIds: $completedByStaffIds');
        
        // Firebase UID'yi staff ID'sine çevir
        final cleanedStaffIds = completedByStaffIds.map((id) {
          // Eğer Firebase UID ise, Ayşe'nin staff ID'sine çevir
          if (id == '6pbPc8kvRwWvDRYROonoIV4c4An1') {
            return 'ycP4fQjqfE4FfgiUxDQY'; // Ayşe'nin staff ID'si
          }
          return id; // Diğer ID'ler olduğu gibi kalsın
        }).toList();
        
        final updatedTask = task.copyWith(
          status: TaskStatus.completed,
          completedAt: now,
          completedByStaffIds: cleanedStaffIds,
          completedImageUrl: completedImageUrl,
        );

        print('TASK_REPO: UpdatedTask oluşturuldu');
        print('TASK_REPO: UpdatedTask completedByStaffIds: ${updatedTask.completedByStaffIds}');

        await updateTask(updatedTask);
        
        // Tamamlanma geçmişini kaydet
        await _saveTaskCompletionHistory(updatedTask);
        
        // Görev puanlarını hesapla ve kaydet
        await _calculateAndSaveTaskScores(updatedTask);
        
        print('TASK_REPO: Görev başarıyla tamamlandı: ${task.title}');
      }
    } catch (e) {
      print('TASK_REPO: Görev tamamlanırken hata: $e');
      rethrow;
    }
  }

  /// Görev tamamlanma görselini yükle
  Future<String> uploadTaskImage(File imageFile, String taskId) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görsel yüklenemez');
        throw Exception('Çevrimdışı modda görsel yüklenemez');
      }

      return await _firebaseService.uploadTaskImage(imageFile, taskId);
    } catch (e) {
      print('TASK_REPO: Görev görseli yüklenirken hata: $e');
      rethrow;
    }
  }

  /// Görev puanlarını hesapla ve kaydet
  Future<void> _calculateAndSaveTaskScores(Task task) async {
    try {
      if (task.completedByStaffIds.isEmpty) {
        print('TASK_REPO: Tamamlayan personel yok, puan hesaplanmayacak');
        return;
      }

      // Görev zorluğuna göre temel puan belirle
      double baseScore;
      switch (task.difficulty) {
        case TaskDifficulty.easy:
          baseScore = 1.0;
          break;
        case TaskDifficulty.medium:
          baseScore = 2.0;
          break;
        case TaskDifficulty.hard:
          baseScore = 3.0;
          break;
      }

      // Görevi tamamlayan kişi sayısına eşit olarak böl
      final completedByCount = task.completedByStaffIds.length;
      final scorePerPerson = baseScore / completedByCount;

      print('TASK_REPO: Görev puanı hesaplanıyor - Temel puan: $baseScore, Kişi sayısı: $completedByCount, Kişi başına: ${scorePerPerson.toStringAsFixed(2)}');

      // Her tamamlayan kişiye eşit pay ver
      for (final staffId in task.completedByStaffIds) {
        final taskScore = TaskScore.create(
          taskId: task.id,
          staffId: staffId,
          score: scorePerPerson, // Eşit pay
        );

        await _saveTaskScore(taskScore);
        print('TASK_REPO: Personel $staffId için puan kaydedildi: ${scorePerPerson.toStringAsFixed(2)}');
      }
    } catch (e) {
      print('TASK_REPO: Görev puanları hesaplanırken hata: $e');
    }
  }

  /// Görev puanını kaydet
  Future<void> _saveTaskScore(TaskScore taskScore) async {
    try {
      final taskScoreWithId = taskScore.copyWith(id: _uuid.v4());
      final json = taskScoreWithId.toJson();
      
      await _firebaseService.addTaskScore(json);
      print('TASK_REPO: Görev puanı kaydedildi: ${taskScore.staffId} - ${taskScore.score}');
    } catch (e) {
      print('TASK_REPO: Görev puanı kaydedilirken hata: $e');
      rethrow;
    }
  }

  /// Göreve şikayet ekle
  Future<void> addComplaint(String taskId, TaskComplaint complaint) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda şikayet eklenemez');
        return;
      }

      final taskData = await _firebaseService.getTask(taskId);
      if (taskData != null) {
        final task = Task.fromJson(taskData);
        final complaintWithId = complaint.copyWith(id: _uuid.v4());
        final updatedComplaints = [...task.complaints, complaintWithId];
        
        final updatedTask = task.copyWith(complaints: updatedComplaints);
        await updateTask(updatedTask);
        
        print('TASK_REPO: Şikayet başarıyla eklendi');
      }
    } catch (e) {
      print('TASK_REPO: Şikayet eklenirken hata: $e');
      rethrow;
    }
  }

  /// Görevi sil
  Future<void> deleteTask(String taskId) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görev silinemez');
        return;
      }

      await _firebaseService.deleteTask(taskId);
      print('TASK_REPO: Görev başarıyla silindi');
    } catch (e) {
      print('TASK_REPO: Görev silinirken hata: $e');
      rethrow;
    }
  }

  /// Görevi devre dışı bırak
  Future<void> deactivateTask(String taskId) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görev devre dışı bırakılamaz');
        return;
      }

      final taskData = await _firebaseService.getTask(taskId);
      if (taskData != null) {
        final task = Task.fromJson(taskData);
        final updatedTask = task.copyWith(isActive: false);
        await updateTask(updatedTask);
        print('TASK_REPO: Görev devre dışı bırakıldı: ${task.title}');
      }
    } catch (e) {
      print('TASK_REPO: Görev devre dışı bırakılırken hata: $e');
      rethrow;
    }
  }

  /// Personel ID'sine göre görevleri getir
  Future<List<Task>> getTasksByStaffId(String staffId) async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final tasksData = await _firebaseService.getTasks();
      final tasks = tasksData.map((data) => Task.fromJson(data)).toList();
      return tasks.where((task) => 
        task.assignedStaffIds.contains(staffId) || 
        task.completedByStaffIds.contains(staffId)
      ).toList();
    } catch (e) {
      print('Personel görevleri alınırken hata: $e');
      return [];
    }
  }

  /// Zorluk seviyesine göre görevleri getir
  Future<List<Task>> getTasksByDifficulty(TaskDifficulty difficulty) async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final tasksData = await _firebaseService.getTasks();
      final tasks = tasksData.map((data) => Task.fromJson(data)).toList();
      return tasks.where((task) => task.difficulty == difficulty).toList();
    } catch (e) {
      print('Zorluk seviyesine göre görevler alınırken hata: $e');
      return [];
    }
  }

  /// Tüm görevleri sıfırla (her gün çalışacak)
  Future<void> resetAllTasks() async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görevler sıfırlanamaz');
        return;
      }

      final tasksData = await _firebaseService.getTasks();
      final tasks = tasksData.map((data) => Task.fromJson(data)).toList();
      final today = DateTime.now();
      
      print('TASK_REPO: ${tasks.length} görev sıfırlama için kontrol ediliyor');
      
      for (final task in tasks) {
        // Eğer görev tamamlanmışsa ve bugün tamamlanmamışsa sıfırla
        bool shouldReset = false;
        
        if (task.status == TaskStatus.completed) {
          if (task.completedAt == null) {
            // completedAt yoksa sıfırla
            shouldReset = true;
          } else {
            // Tamamlanma tarihi bugün değilse sıfırla
            final completedDate = task.completedAt!;
            if (completedDate.year != today.year ||
                completedDate.month != today.month ||
                completedDate.day != today.day) {
              shouldReset = true;
            }
          }
        } else if (task.status == TaskStatus.pending) {
          // Bekleyen görevler zaten sıfırlanmış durumda
          continue;
        }
        
        if (shouldReset) {
          final resetTask = task.copyWith(
            status: TaskStatus.pending,
            // Tamamlanma bilgilerini silmiyoruz, sadece durumu değiştiriyoruz
            // Geçmiş kayıtları task_completion_history'de saklanıyor
          );
          
          await updateTask(resetTask);
          print('TASK_REPO: Görev sıfırlandı: ${task.title}');
        }
      }
      
      print('TASK_REPO: Görev sıfırlama tamamlandı');
    } catch (e) {
      print('TASK_REPO: Görevler sıfırlanırken hata: $e');
    }
  }

  /// Tüm görevleri kontrol et ve gerekirse sıfırla
  Future<void> checkAndResetAllTasks() async {
    try {
      final today = DateTime.now();
      final lastResetDate = await _getLastResetDate();
      
      // Eğer son sıfırlama bugün değilse sıfırla
      if (lastResetDate == null || 
          lastResetDate.year != today.year ||
          lastResetDate.month != today.month ||
          lastResetDate.day != today.day) {
        
        await resetAllTasks();
        await _setLastResetDate(today);
        print('TASK_REPO: Tüm görevler kontrol edildi ve sıfırlandı');
      } else {
        print('TASK_REPO: Görevler bugün zaten sıfırlanmış');
      }
    } catch (e) {
      print('TASK_REPO: Görev kontrolü sırasında hata: $e');
    }
  }

  /// Son sıfırlama tarihini al
  Future<DateTime?> _getLastResetDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetString = prefs.getString('last_task_reset_date');
      if (lastResetString != null) {
        return DateTime.parse(lastResetString);
      }
      return null;
    } catch (e) {
      print('TASK_REPO: Son sıfırlama tarihi alınırken hata: $e');
      return null;
    }
  }

  /// Son sıfırlama tarihini kaydet
  Future<void> _setLastResetDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_task_reset_date', date.toIso8601String());
      print('TASK_REPO: Son sıfırlama tarihi kaydedildi: $date');
    } catch (e) {
      print('TASK_REPO: Son sıfırlama tarihi kaydedilirken hata: $e');
    }
  }

  /// Günlük sıfırlama timer'ını başlat
  void startDailyResetTimer() {
    // Önce mevcut timer'ı iptal et
    _dailyResetTimer?.cancel();
    
    // Gece yarısına kadar olan süreyi hesapla
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);
    
    print('TASK_REPO: Günlük sıfırlama timer başlatıldı. Gece yarısına kadar: ${durationUntilMidnight.inHours} saat ${durationUntilMidnight.inMinutes % 60} dakika');
    
    // DEBUG: Test için 30 saniye sonra sıfırlama (gerçek kullanımda kaldırılacak)
    // _dailyResetTimer = Timer(const Duration(seconds: 30), () async {
    //   print('TASK_REPO: TEST - Görevler sıfırlanıyor...');
    //   await resetAllTasks();
    //   await _setLastResetDate(DateTime.now());
    // });
    
    // Gece yarısında sıfırlama yap
    _dailyResetTimer = Timer(durationUntilMidnight, () async {
      print('TASK_REPO: Gece yarısı - Görevler otomatik sıfırlanıyor...');
      await resetAllTasks();
      await _setLastResetDate(DateTime.now());
      
      // Ertesi gün için timer'ı yeniden başlat
      startDailyResetTimer();
    });
  }

  /// Günlük sıfırlama timer'ını durdur
  void stopDailyResetTimer() {
    _dailyResetTimer?.cancel();
    _dailyResetTimer = null;
    print('TASK_REPO: Günlük sıfırlama timer durduruldu');
  }

  /// Tamamlanma geçmişini kaydet
  Future<void> _saveTaskCompletionHistory(Task task) async {
    try {
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda tamamlanma geçmişi kaydedilemez');
        return;
      }

      final history = TaskCompletionHistory(
        id: _uuid.v4(),
        taskId: task.id,
        taskTitle: task.title,
        taskDescription: task.description,
        completedAt: task.completedAt!,
        completedByStaffIds: task.completedByStaffIds,
        completedImageUrl: task.completedImageUrl,
        createdAt: DateTime.now(),
      );

      await _firebaseService.addTaskCompletionHistory(history.toJson());
      print('TASK_REPO: Tamamlanma geçmişi kaydedildi: ${task.title}');
    } catch (e) {
      print('TASK_REPO: Tamamlanma geçmişi kaydedilirken hata: $e');
    }
  }

  /// Tamamlanma geçmişini getir
  Future<List<TaskCompletionHistory>> getTaskCompletionHistory() async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final historyData = await _firebaseService.getTaskCompletionHistory();
      return historyData.map((data) => TaskCompletionHistory.fromJson(data)).toList();
    } catch (e) {
      print('TASK_REPO: Tamamlanma geçmişi alınırken hata: $e');
      return [];
    }
  }

  /// Belirli tarihteki tamamlanma geçmişini getir
  Future<List<TaskCompletionHistory>> getTaskCompletionHistoryForDate(DateTime date) async {
    try {
      final allHistory = await getTaskCompletionHistory();
      
      return allHistory.where((history) {
        final historyDate = history.completedAt;
        return historyDate.year == date.year &&
               historyDate.month == date.month &&
               historyDate.day == date.day;
      }).toList();
    } catch (e) {
      print('TASK_REPO: Tarihli tamamlanma geçmişi alınırken hata: $e');
      return [];
    }
  }

  /// Repository'yi temizle
  void dispose() {
    stopDailyResetTimer();
  }
}
