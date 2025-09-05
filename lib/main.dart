import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/di/service_locator.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/menu_repository.dart';
import 'data/services/admin_auth_service.dart';
import 'data/repositories/admin_user_repository.dart';
import 'data/repositories/business_settings_repository.dart';
import 'firebase_options.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/register_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/table_order_screen.dart';
import 'presentation/screens/sales_screen.dart';
import 'presentation/screens/operations_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/business_management_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase başlatma durumunu gösteren enum
enum FirebaseInitStatus { notInitialized, initializing, initialized, error }

// Global Firebase başlatma durumu
FirebaseInitStatus firebaseStatus = FirebaseInitStatus.notInitialized;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlat
  firebaseStatus = FirebaseInitStatus.initializing;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseStatus = FirebaseInitStatus.initialized;
    print('Firebase başarıyla başlatıldı');

    // Firebase bağlantı testi kaldırıldı

    // Firestore erişimini test et
    try {
      final firestore = FirebaseFirestore.instance;
      final testResult = await firestore.collection('_test').limit(1).get();
      print(
          'Firestore erişimi başarılı: ${testResult.docs.length} döküman bulundu');

      // Menü koleksiyonunu kontrol et
      final menuResult =
          await firestore.collection('menu_items').limit(1).get();
      print(
          'menu_items koleksiyonu erişimi başarılı: ${menuResult.docs.length} döküman bulundu');
    } catch (e) {
      print('Firestore erişim testi başarısız: $e');

      if (e is FirebaseException) {
        print('FirebaseException kodu: ${e.code}, mesajı: ${e.message}');
        if (e.code == 'permission-denied') {
          print('İZİN HATASI: Firestore güvenlik kurallarını kontrol edin!');
        }
      }
    }
  } catch (e) {
    firebaseStatus = FirebaseInitStatus.error;
    print('Firebase başlatma hatası: $e');

    // Hatayı detaylı logla
    if (e is PlatformException) {
      print(
        'Platform hatası detayları: Kod=${e.code}, Mesaj=${e.message}, Detaylar=${e.details}',
      );
    }
  }

  // Menü verilerini başlat
  try {
    print('Menü verileri yükleniyor...');
    final menuRepo = MenuRepository();
    await menuRepo.loadMenuItems();

    // Test verisi ekleme kaldırıldı
    print('${menuRepo.menuItems.length} menü öğesi başarıyla yüklendi');
  } catch (e) {
    print('Menü verileri yüklenirken hata: $e');
  }

  // Admin kullanıcılarını başlat
  try {
    print('Admin kullanıcıları yükleniyor...');
    final adminUserRepo = AdminUserRepository();
    await adminUserRepo.addDefaultAdminUser();
    print('Admin kullanıcıları başarıyla yüklendi');
    
    // Firebase Authentication admin kullanıcısı oluşturma kaldırıldı
  } catch (e) {
    print('Admin kullanıcıları yüklenirken hata: $e');
  }

  // İşletme ayarlarını başlat
  try {
    print('İşletme ayarları yükleniyor...');
    final businessSettingsRepo = BusinessSettingsRepository();
    await businessSettingsRepo.addDefaultBusinessSettings();
    print('İşletme ayarları başarıyla yüklendi');
  } catch (e) {
    print('İşletme ayarları yüklenirken hata: $e');
  }

  // Auth state listener artık AdminAuthService constructor'ında otomatik başlatılıyor

  // Dependency injection kurulumu - Firebase başarıyla başlatılsın ya da başlatılmasın
  // uygulamayı offline modda başlatabilmek için devam ediyoruz
  await ServiceLocator.setupDependencies();

  // Durum çubuğunu şeffaf yap
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Türkçe dil desteği ekle
  await initializeDateFormatting('tr_TR', null);
  Intl.defaultLocale = 'tr_TR';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminAuthService()),
      ],
      child: const OyunLabApp(),
    ),
  );
}

class OyunLabApp extends StatelessWidget {
  const OyunLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OyunLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
      initialRoute: '/', // Ana route'dan başla
      routes: {
        '/': (context) => Consumer<AdminAuthService>(
          builder: (context, authService, child) {
            // Auth durumunu kontrol et ve uygun ekranı göster
            if (authService.isLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (authService.isLoggedIn && authService.currentUser != null) {
              return const MainScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final CustomerRepository _customerRepository;
  int? _tableNumber; // Filtrelenecek masa numarası

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    // GetIt üzerinden CustomerRepository'yi al
    _customerRepository = ServiceLocator.locator<CustomerRepository>();
    _initializeScreens();
  }

  // Masa detay ekranına direkt geçiş
  void _navigateToTableDetail(int ticketNumber) {
    print('🔄 MAIN: _navigateToTableDetail çağrıldı - Bilet: $ticketNumber');
    // Masa ekranına geç ve bilet numarasını parametre olarak gönder
    setState(() {
      _selectedIndex = 1;
      _tableNumber = ticketNumber;
      print('🔄 MAIN: _tableNumber güncellendi: $_tableNumber');
      // Ekranları yeniden oluştur
      _initializeScreens();
      print('🔄 MAIN: Ekranlar yeniden oluşturuldu');
    });
  }

  void _initializeScreens() {
    _screens.clear();
    _screens.addAll([
      HomeScreen(
        customerRepository: _customerRepository,
        onDataCleared: () {
          // Sales screen otomatik olarak stream'den güncellenecek
        },
        onGoToTable: (ticketNumber) {
          print('🏠 HOME_SCREEN: Masaya git butonuna tıklandı - Bilet: $ticketNumber');
          // Masa ekranına git (index 1) ve bilet numarasına göre masayı filtrele
          setState(() {
            _selectedIndex = 1;
          });
          // Masa detay ekranına direkt geçiş için callback'i çağır
          _navigateToTableDetail(ticketNumber);
        },
      ),
      TableOrderScreen(
        customerRepository: _customerRepository,
        filterTableNumber: _tableNumber,
      ),
      SalesScreen(customerRepository: _customerRepository),
      Consumer<AdminAuthService>(
        builder: (context, authService, child) {
          return OperationsScreen(
            customerRepository: _customerRepository,
            menuRepository: ServiceLocator.locator<MenuRepository>(),
          );
        },
      ),
      // Kullanıcı rolüne göre ekran seçimi
      Consumer<AdminAuthService>(
        builder: (context, authService, child) {
          print('Ekran seçimi - isAdmin: ${authService.isAdmin}, isLoggedIn: ${authService.isLoggedIn}');
          if (authService.isAdmin) {
            return const BusinessManagementScreen();
          } else {
            return const ProfileScreen();
          }
        },
      ),
    ]);
  }

  // Navigation bar item'larını oluştur
  List<BottomNavigationBarItem> _buildNavigationItems(AdminAuthService authService) {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        label: 'Ana Sayfa',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_rounded),
        label: 'Masa Siparişi',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_rounded),
        label: 'Müşteriler',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.analytics_rounded),
        label: 'İşleyiş',
      ),
      // Kullanıcı rolüne göre son sekme
      authService.isAdmin
          ? const BottomNavigationBarItem(
              icon: Icon(Icons.business_rounded),
              label: 'İşletmem',
            )
          : const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
    ];
  }

  @override
  void dispose() {
    // Repository manuel olarak dispose etmeye gerek yok, artık ServiceLocator'da yönetiliyor
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      // Çevrimdışı mod göstergesi
      bottomSheet: _customerRepository.isOfflineMode
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.orange,
              child: const Text(
                'ÇEVRİMDIŞI MOD - Veritabanı bağlantısı kurulamadı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          child: Consumer<AdminAuthService>(
            builder: (context, authService, child) {
              return BottomNavigationBar(
                items: _buildNavigationItems(authService),
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: Colors.grey.shade500,
                showUnselectedLabels: true,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                elevation: 0,
              );
            },
          ),
        ),
      ),
    );
  }
}
