import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_user_model.dart';
import '../repositories/admin_user_repository.dart';

class AdminAuthService extends ChangeNotifier {
  AdminUser? _currentUser;
  bool _isLoading = false;
  final AdminUserRepository _adminUserRepository = AdminUserRepository();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  AdminAuthService() {
    // Constructor'da auth state listener'ı başlat
    setupAuthStateListener();
    // Mevcut kullanıcıyı kontrol et
    checkCurrentUser();
  }

  // Getter'lar
  AdminUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseAuth.currentUser != null; // Firebase Auth durumuna göre
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isManager => _currentUser?.isManager ?? false;
  bool get isStaff => _currentUser?.isStaff ?? false;

  // Admin giriş işlemi
  Future<bool> login(String email, String password) async {
    try {
      _setLoading(true);

      // Önce Firebase Authentication ile giriş yap
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Firebase authentication başarısız');
      }

      // Firebase'den admin kullanıcı bilgilerini al
      final adminUser = await _adminUserRepository.getAdminUserByEmail(email);
      
      if (adminUser == null) {
        // Admin kullanıcı yoksa oluştur (ilk giriş için)
        if (email == 'yusuffrkn73@gmail.com') {
          final newAdminUser = DefaultAdminUser.yusufAdmin.copyWith(
            email: email,
            lastLoginAt: DateTime.now(),
          );
          
          final userId = await _adminUserRepository.addAdminUser(newAdminUser);
          _currentUser = newAdminUser.copyWith(id: userId);
          
          print('Yeni admin kullanıcısı oluşturuldu: $email');
        } else {
          throw Exception('Bu e-posta ile admin kullanıcısı bulunamadı');
        }
      } else {
        // Mevcut admin kullanıcıyı kullan
        _currentUser = adminUser;
        
        // Son giriş zamanını güncelle
        await _adminUserRepository.updateLastLogin(adminUser.id);
      }

      // Kullanıcı aktif mi kontrol et
      if (!_currentUser!.isActive) {
        throw Exception('Hesap aktif değil');
      }

      _setLoading(false);
      notifyListeners();
      
      print('Admin girişi başarılı: ${_currentUser!.email} (${_currentUser!.role})');
      return true;

    } catch (e) {
      _setLoading(false);
      
      String errorMessage = 'Giriş hatası';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
            break;
          case 'wrong-password':
            errorMessage = 'Hatalı şifre';
            break;
          case 'invalid-credential':
            errorMessage = 'Geçersiz kimlik bilgileri';
            break;
          case 'user-disabled':
            errorMessage = 'Bu hesap devre dışı bırakılmış';
            break;
          case 'too-many-requests':
            errorMessage = 'Çok fazla başarısız giriş denemesi. Lütfen daha sonra tekrar deneyin';
            break;
          default:
            errorMessage = 'Giriş hatası: ${e.message}';
        }
      }
      
      print('Admin giriş hatası: $e');
      throw Exception(errorMessage);
    }
  }

  // Admin çıkış işlemi
  Future<void> logout() async {
    try {
      _setLoading(true);
      
      // Firebase'den çıkış yap
      await _firebaseAuth.signOut();
      
      // Mevcut kullanıcı bilgilerini temizle
      _currentUser = null;
      
      _setLoading(false);
      notifyListeners();
      
      print('Admin çıkışı başarılı');
    } catch (e) {
      _setLoading(false);
      print('Admin çıkış hatası: $e');
    }
  }

  // Kullanıcı izinlerini kontrol et
  bool hasPermission(String permission) {
    return _currentUser?.hasPermission(permission) ?? false;
  }

  // Birden fazla izin kontrolü
  bool hasAnyPermission(List<String> permissions) {
    return permissions.any((permission) => hasPermission(permission));
  }

  // Tüm izinleri kontrol et
  bool hasAllPermissions(List<String> permissions) {
    return permissions.every((permission) => hasPermission(permission));
  }

  // Kullanıcı bilgilerini güncelle
  Future<void> updateCurrentUser(AdminUser updatedUser) async {
    try {
      await _adminUserRepository.updateAdminUser(updatedUser);
      
      // Mevcut kullanıcıyı güncelle
      if (_currentUser?.id == updatedUser.id) {
        _currentUser = updatedUser;
        notifyListeners();
      }
      
      print('Kullanıcı bilgileri güncellendi');
    } catch (e) {
      print('Kullanıcı güncelleme hatası: $e');
      rethrow;
    }
  }

  // Kullanıcı rolünü güncelle
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _adminUserRepository.updateUserRole(userId, newRole);
      
      // Mevcut kullanıcıysa güncelle
      if (_currentUser?.id == userId) {
        _currentUser = _currentUser!.copyWith(role: newRole);
        notifyListeners();
      }
      
      print('Kullanıcı rolü güncellendi: $newRole');
    } catch (e) {
      print('Rol güncelleme hatası: $e');
      rethrow;
    }
  }

  // Kullanıcı izinlerini güncelle
  Future<void> updateUserPermissions(String userId, List<String> permissions) async {
    try {
      await _adminUserRepository.updateUserPermissions(userId, permissions);
      
      // Mevcut kullanıcıysa güncelle
      if (_currentUser?.id == userId) {
        _currentUser = _currentUser!.copyWith(permissions: permissions);
        notifyListeners();
      }
      
      print('Kullanıcı izinleri güncellendi');
    } catch (e) {
      print('İzin güncelleme hatası: $e');
      rethrow;
    }
  }

  // Kullanıcı bilgilerini yenile
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      try {
        final refreshedUser = await _adminUserRepository.getAdminUserById(_currentUser!.id);
        if (refreshedUser != null) {
          _currentUser = refreshedUser;
          notifyListeners();
        }
      } catch (e) {
        print('Kullanıcı bilgileri yenileme hatası: $e');
      }
    }
  }

  // Loading durumunu ayarla
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Demo kullanıcı bilgileri
  static Map<String, String> get demoCredentials => {
    'yusuffrkn73@gmail.com': '123456',
    'demo@oyunlab.com': '123456',
  };

  // Firebase Authentication'da admin kullanıcısı oluştur
  Future<void> createFirebaseAdminUser(String email, String password) async {
    try {
      // Önce kullanıcı var mı kontrol et
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        print('Firebase kullanıcısı zaten mevcut: $email');
        return;
      }

      // Yeni kullanıcı oluştur
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        print('Firebase admin kullanıcısı oluşturuldu: $email');
        
        // Kullanıcı profilini güncelle
        await userCredential.user!.updateDisplayName('Yusuf Admin');
      }
    } catch (e) {
      print('Firebase admin kullanıcısı oluşturma hatası: $e');
      rethrow;
    }
  }

  // Demo kullanıcı mı kontrol et
  bool isDemoUser() {
    return _currentUser?.email == 'demo@oyunlab.com';
  }

  // Admin kullanıcı mı kontrol et
  bool isAdminUser() {
    return _currentUser?.email == 'yusuffrkn73@gmail.com';
  }

  // Uygulama başlangıcında mevcut giriş durumunu kontrol et
  Future<void> checkCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && user.email != null) {
        print('Firebase Auth\'da kullanıcı bulundu: ${user.email}');
        
        // Firebase Auth'da kullanıcı var, admin mi kontrol et
        final adminUser = await _adminUserRepository.getAdminUserByEmail(user.email!);
        if (adminUser != null && adminUser.isActive) {
          // Admin kullanıcı
          _currentUser = adminUser;
          await _adminUserRepository.updateLastLogin(adminUser.id);
          notifyListeners();
          print('Mevcut admin kullanıcı oturumu bulundu: ${adminUser.email} (Role: ${adminUser.role})');
          print('isAdmin: ${isAdmin}, isManager: ${isManager}, isStaff: ${isStaff}');
        } else {
          // Normal kullanıcı - sadece Firebase Auth ile giriş yapılmış
          _currentUser = null; // Admin bilgisi yok
          notifyListeners();
          print('Normal kullanıcı oturumu bulundu: ${user.email}');
        }
      } else {
        print('Firebase Auth\'da kullanıcı bulunamadı');
        _currentUser = null;
        notifyListeners();
      }
    } catch (e) {
      print('Mevcut kullanıcı kontrolü hatası: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  // Firebase Auth state değişikliklerini dinle
  void setupAuthStateListener() {
    _firebaseAuth.authStateChanges().listen((User? user) async {
      print('Auth state değişikliği: ${user?.email ?? 'null'}');
      
      if (user != null && user.email != null) {
        // Kullanıcı giriş yaptı - admin mi kontrol et
        try {
          final adminUser = await _adminUserRepository.getAdminUserByEmail(user.email!);
          if (adminUser != null && adminUser.isActive) {
            // Admin kullanıcı - Firestore'dan bilgileri al
            _currentUser = adminUser;
            await _adminUserRepository.updateLastLogin(adminUser.id);
            notifyListeners();
            print('Admin kullanıcı oturumu başlatıldı: ${adminUser.email}');
          } else {
            // Normal kullanıcı - sadece Firebase Auth ile giriş yapıldı
            _currentUser = null; // Admin bilgisi yok
            notifyListeners();
            print('Normal kullanıcı girişi: ${user.email}');
          }
        } catch (e) {
          print('Auth state listener hatası: $e');
          // Hata durumunda da kullanıcı giriş yapmış sayılır
          _currentUser = null;
          notifyListeners();
        }
      } else {
        // Kullanıcı çıkış yaptı
        _currentUser = null;
        notifyListeners();
        print('Kullanıcı oturumu sonlandırıldı');
      }
    });
  }

  // Kullanıcı rolünü string olarak getir
  String get userRoleString {
    if (_currentUser == null) return 'Misafir';
    
    switch (_currentUser!.role) {
      case UserRole.admin:
        return 'Sistem Yöneticisi';
      case UserRole.manager:
        return 'Yönetici';
      case UserRole.staff:
        return 'Personel';
      case UserRole.viewer:
        return 'Görüntüleyici';
    }
  }

  // Kullanıcı rolünü renk olarak getir
  int get userRoleColor {
    if (_currentUser == null) return 0xFF9E9E9E; // Gri
    
    switch (_currentUser!.role) {
      case UserRole.admin:
        return 0xFFE53935; // Kırmızı
      case UserRole.manager:
        return 0xFF1976D2; // Mavi
      case UserRole.staff:
        return 0xFF388E3C; // Yeşil
      case UserRole.viewer:
        return 0xFFFF9800; // Turuncu
    }
  }
}
