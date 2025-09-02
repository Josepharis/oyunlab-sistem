import 'package:uuid/uuid.dart';
import '../models/issue_model.dart';
import '../services/firebase_service.dart';

class IssueRepository {
  final FirebaseService _firebaseService;
  final Uuid _uuid = Uuid();
  bool _isOfflineMode = false;

  IssueRepository(this._firebaseService);

  /// Çevrimdışı modu ayarla
  void setOfflineMode(bool isOffline) {
    _isOfflineMode = isOffline;
  }

  /// Tüm çözülmemiş eksikleri getir
  Future<List<Issue>> getUnresolvedIssues() async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda eksikler alınamadı');
        return [];
      }

      final issuesData = await _firebaseService.getIssues();
      final issues = issuesData.map((data) => Issue.fromJson(data)).toList();
      return issues
          .where((issue) => !issue.isResolved)
          .toList();
    } catch (e) {
      print('Çözülmemiş eksikler alınırken hata: $e');
      return [];
    }
  }

  /// Tüm çözülmüş eksikleri getir
  Future<List<Issue>> getResolvedIssues() async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda çözülmüş eksikler alınamadı');
        return [];
      }

      final issuesData = await _firebaseService.getIssues();
      final issues = issuesData.map((data) => Issue.fromJson(data)).toList();
      return issues
          .where((issue) => issue.isResolved)
          .toList();
    } catch (e) {
      print('Çözülmüş eksikler alınırken hata: $e');
      return [];
    }
  }

  /// Tüm eksikleri getir
  Future<List<Issue>> getAllIssues() async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda eksikler alınamadı');
        return [];
      }

      final issuesData = await _firebaseService.getIssues();
      return issuesData.map((data) => Issue.fromJson(data)).toList();
    } catch (e) {
      print('Tüm eksikler alınırken hata: $e');
      return [];
    }
  }

  /// Yeni eksik oluştur
  Future<void> createIssue(Issue issue) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda eksik oluşturulamaz');
        return;
      }

      final issueWithId = issue.copyWith(id: _uuid.v4());
      final json = issueWithId.toJson();

      await _firebaseService.addIssue(json);
      print('ISSUE_REPO: Eksik başarıyla oluşturuldu: ${issue.title}');
    } catch (e) {
      print('ISSUE_REPO: Eksik oluşturulurken hata: $e');
      rethrow;
    }
  }

  /// Eksik güncelle
  Future<void> updateIssue(Issue issue) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda eksik güncellenemez');
        return;
      }

      final json = issue.toJson();
      await _firebaseService.updateIssue(issue.id, json);
      print('ISSUE_REPO: Eksik başarıyla güncellendi: ${issue.title}');
    } catch (e) {
      print('ISSUE_REPO: Eksik güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Eksik çöz
  Future<void> resolveIssue(String issueId, String resolvedBy) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda eksik çözülemez');
        return;
      }

      final issueData = await _firebaseService.getIssue(issueId);
      if (issueData != null) {
        final issue = Issue.fromJson(issueData);
        final updatedIssue = issue.copyWith(
          isResolved: true,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
        );

        await updateIssue(updatedIssue);
        print('ISSUE_REPO: Eksik başarıyla çözüldü: ${issue.title}');
      }
    } catch (e) {
      print('ISSUE_REPO: Eksik çözülürken hata: $e');
      rethrow;
    }
  }

  /// Eksik sil
  Future<void> deleteIssue(String issueId) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda eksik silinemez');
        return;
      }

      await _firebaseService.deleteIssue(issueId);
      print('ISSUE_REPO: Eksik başarıyla silindi');
    } catch (e) {
      print('ISSUE_REPO: Eksik silinirken hata: $e');
      rethrow;
    }
  }

  /// Kategoriye göre eksikleri getir
  Future<List<Issue>> getIssuesByCategory(IssueCategory category) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda kategori eksikleri alınamadı');
        return [];
      }

      final issuesData = await _firebaseService.getIssues();
      final issues = issuesData.map((data) => Issue.fromJson(data)).toList();
      return issues.where((issue) => issue.category == category).toList();
    } catch (e) {
      print('Kategori eksikleri alınırken hata: $e');
      return [];
    }
  }

  /// Önceliğe göre eksikleri getir
  Future<List<Issue>> getIssuesByPriority(IssuePriority priority) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda öncelik eksikleri alınamadı');
        return [];
      }

      final issuesData = await _firebaseService.getIssues();
      final issues = issuesData.map((data) => Issue.fromJson(data)).toList();
      return issues.where((issue) => issue.priority == priority).toList();
    } catch (e) {
      print('Öncelik eksikleri alınırken hata: $e');
      return [];
    }
  }

  /// Kullanıcıya göre eksikleri getir
  Future<List<Issue>> getIssuesByUser(String userId) async {
    try {
      if (_isOfflineMode) {
        print('ISSUE_REPO: Çevrimdışı modda kullanıcı eksikleri alınamadı');
        return [];
      }

      final issuesData = await _firebaseService.getIssues();
      final issues = issuesData.map((data) => Issue.fromJson(data)).toList();
      return issues.where((issue) => 
        issue.createdBy == userId || issue.resolvedBy == userId
      ).toList();
    } catch (e) {
      print('Kullanıcı eksikleri alınırken hata: $e');
      return [];
    }
  }
}
