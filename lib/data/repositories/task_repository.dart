import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/task_model.dart';
import '../models/task_score_model.dart';
import '../services/firebase_service.dart';

class TaskRepository {
  final FirebaseService _firebaseService;
  final Uuid _uuid = Uuid();
  bool _isOfflineMode = false;

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
      if (_isOfflineMode) {
        print('TASK_REPO: Çevrimdışı modda görev tamamlanamaz');
        return;
      }

      final taskData = await _firebaseService.getTask(taskId);
      if (taskData != null) {
        final task = Task.fromJson(taskData);
        final updatedTask = task.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
          completedByStaffIds: completedByStaffIds,
          completedImageUrl: completedImageUrl,
        );

        await updateTask(updatedTask);
        
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
}
