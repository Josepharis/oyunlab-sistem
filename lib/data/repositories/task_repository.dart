import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
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
        print('TASK_REPO: Görev başarıyla tamamlandı: ${task.title}');
      }
    } catch (e) {
      print('TASK_REPO: Görev tamamlanırken hata: $e');
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
