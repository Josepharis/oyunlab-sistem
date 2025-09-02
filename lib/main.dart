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
import 'data/models/order_model.dart';
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
import 'core/utils/firebase_test_util.dart';

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

    // Firebase bağlantı ve izin testlerini çalıştır
    await FirebaseTestUtil.testFirestoreConnection();

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

    // Test amaçlı - menü boşsa örnek veri ekle
    if (menuRepo.menuItems.isEmpty) {
      print('Menü boş! Test verisi ekleniyor...');
      final testItems = [
        ProductItem(
          id: 'test_burger_1',
          name: "Flutter Burger",
          price: 45.99,
          category: ProductCategory.food,
          description: "Lezzetli Flutter burger",
        ),
        ProductItem(
          id: 'test_pizza_1',
          name: "Dart Pizza",
          price: 35.99,
          category: ProductCategory.food,
          description: "Özel Dart pizza",
        ),
      ];

      await menuRepo.saveMenuItems(testItems);
      print('Test menü öğeleri başarıyla kaydedildi!');
    } else {
      print('${menuRepo.menuItems.length} menü öğesi başarıyla yüklendi');
    }
  } catch (e) {
    print('Menü verileri yüklenirken hata: $e');
  }

  // Admin kullanıcılarını başlat
  try {
    print('Admin kullanıcıları yükleniyor...');
    final adminUserRepo = AdminUserRepository();
    await adminUserRepo.addDefaultAdminUser();
    print('Admin kullanıcıları başarıyla yüklendi');
    
    // Firebase Authentication'da admin kullanıcısı oluştur
    print('Firebase Authentication admin kullanıcısı oluşturuluyor...');
    final adminAuthService = AdminAuthService();
    await adminAuthService.createFirebaseAdminUser('yusuffrkn73@gmail.com', '123456');
    print('Firebase Authentication admin kullanıcısı başarıyla oluşturuldu');
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
      child: Consumer<AdminAuthService>(
        builder: (context, authService, child) {
          return OyunLabApp(authService: authService);
        },
      ),
    ),
  );
}

class OyunLabApp extends StatelessWidget {
  final AdminAuthService authService;
  
  const OyunLabApp({super.key, required this.authService});

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
      initialRoute: authService.isLoggedIn ? '/home' : '/login',
      routes: {
        '/': (context) => const LoginScreen(), // Ana route eklendi
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

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    // GetIt üzerinden CustomerRepository'yi al
    _customerRepository = ServiceLocator.locator<CustomerRepository>();
    _initializeScreens();
  }

  void _initializeScreens() {
    _screens.clear();
    _screens.addAll([
      HomeScreen(
        customerRepository: _customerRepository,
        onDataCleared: () {
          // Sales screen otomatik olarak stream'den güncellenecek
        },
      ),
      TableOrderScreen(customerRepository: _customerRepository),
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
