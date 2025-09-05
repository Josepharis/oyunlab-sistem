import 'package:get_it/get_it.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/business_settings_repository.dart';
import '../../data/repositories/staff_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/issue_repository.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/sale_service.dart';

/// Servis locator sınıfı, uygulama genelinde servis ve repository'lere
/// tek bir yerden erişim sağlar. Dependency Injection'ı basit şekilde uygular.
class ServiceLocator {
  static final GetIt locator = GetIt.instance;
  static bool _isSetup = false;

  /// Servis ve repository'leri başlatır
  static Future<void> setupDependencies() async {
    if (_isSetup) return;

    try {
      // Servisler
      if (!locator.isRegistered<FirebaseService>()) {
        // FirebaseService'i singleton olarak kaydet
        final firebaseService = FirebaseService();
        locator.registerSingleton<FirebaseService>(firebaseService);

        // Servisin başlatma işleminin tamamlanmasını bekle (isteğe bağlı)
        await Future.delayed(const Duration(seconds: 1));
      }

      // SaleService'i kaydet
      if (!locator.isRegistered<SaleService>()) {
        locator.registerLazySingleton<SaleService>(() => SaleService());
      }

      // Repository'ler
      await _setupRepositories();

      _isSetup = true;
      print('ServiceLocator başarıyla kuruldu');
    } catch (e) {
      print('ServiceLocator kurulumunda hata: $e');

      // Hata durumunda mock/boş implementasyonlarla devam et
      _setupFallbackServices();
    }
  }

  /// Hata durumunda temel servisleri başlatır
  static void _setupFallbackServices() {
    try {
      print('Fallback servisler başlatılıyor...');

      // Eğer FirebaseService kaydedilemezse, en azından bir instance oluştur
      if (!locator.isRegistered<FirebaseService>()) {
        locator.registerSingleton<FirebaseService>(FirebaseService());
      }

      // Repository'i FirebaseService ile başlat
      if (!locator.isRegistered<CustomerRepository>()) {
        locator.registerLazySingleton<CustomerRepository>(
          () => CustomerRepository(firebaseService: locator<FirebaseService>()),
        );
      }

      // TaskRepository'yi de fallback olarak ekle
      if (!locator.isRegistered<TaskRepository>()) {
        locator.registerLazySingleton<TaskRepository>(
          () => TaskRepository(locator<FirebaseService>()),
        );
      }

      // IssueRepository'yi de fallback olarak ekle
      if (!locator.isRegistered<IssueRepository>()) {
        locator.registerLazySingleton<IssueRepository>(
          () => IssueRepository(locator<FirebaseService>()),
        );
      }

      _isSetup = true;
    } catch (e) {
      print('Fallback servisler başlatılırken de hata oluştu: $e');
    }
  }

  /// Kaynakları temizler ve uygulamayı kapatır
  static void dispose() {
    try {
      if (locator.isRegistered<CustomerRepository>()) {
        locator<CustomerRepository>().dispose();
      }

      _isSetup = false;
    } catch (e) {
      print('ServiceLocator kapatılırken hata: $e');
    }
  }

  static Future<void> _setupRepositories() async {
    // Müşteri repository
    locator.registerLazySingleton<CustomerRepository>(
      () => CustomerRepository(firebaseService: locator<FirebaseService>()),
    );

    // Menü repository
    locator.registerLazySingleton<MenuRepository>(
      () => MenuRepository(),
    );

    // İşletme ayarları repository
    locator.registerLazySingleton<BusinessSettingsRepository>(
      () => BusinessSettingsRepository(),
    );

    // Personel repository
    locator.registerLazySingleton<StaffRepository>(
      () => StaffRepository(),
    );

    // Görev repository
    locator.registerLazySingleton<TaskRepository>(
      () => TaskRepository(locator<FirebaseService>()),
    );

    // Eksik repository
    locator.registerLazySingleton<IssueRepository>(
      () => IssueRepository(locator<FirebaseService>()),
    );
  }
}
