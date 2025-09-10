import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/storage_service.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  // Kontrolcüler
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  // Menü repository
  final MenuRepository _menuRepository = MenuRepository();

  // Durum değişkenleri
  String _searchQuery = '';
  List<ProductItem> _menuItems = [];
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _imageUrl;
  int _selectedCategoryIndex = 0;
  bool _isGridView = false;
  bool _isSearchFocused = false;
  bool _isLoading = true;
  bool _isSaving = false; // Kaydetme durumu için

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: ProductCategory.values.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
    _pageController = PageController(initialPage: 0);

    // Menü öğelerini repository'den al
    _menuItems = List.from(_menuRepository.menuItems);

    // Menü öğelerini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _menuRepository.loadMenuItems();
        _menuItems = List.from(_menuRepository.menuItems);
        
        print("📦 Menü yüklendi: ${_menuItems.length} ürün");
        
        if (_menuItems.isEmpty) {
          print("Menü listesi boş! Kullanıcı kendi ürünlerini ekleyebilir.");
        } else {
          print("Mevcut menü yüklendi: ${_menuItems.length} ürün");
        }
      } catch (e) {
        print("Menü yükleme hatası: $e");
      }

      // Yükleme durumunu kapat
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedCategoryIndex = _tabController.index;
        _pageController.animateToPage(
          _selectedCategoryIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    // Kaydetme işlemi kaldırıldı - zaten her işlemde kaydediliyor
    // Gereksiz duplicate kayıtları önlemek için

    _searchController.dispose();
    _tabController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Kategoriye göre ürünleri filtrele
  List<ProductItem> _getFilteredProducts(ProductCategory category) {
    return _searchQuery.isEmpty
        ? _menuItems.where((item) => item.category == category).toList()
        : _menuItems
            .where(
              (item) =>
                  (item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (item.description
                              ?.toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ??
                          false)),
            )
            .toList();
  }

  // Arama işlemini temizle
  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchQuery = '';
      _isSearchFocused = false;
    });
  }

  // Görsel seçme ve Firebase Storage'a yükleme işlemi
  Future<void> _pickImage({Function? onComplete, required String productId, required ProductCategory category}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        
        // Görsel formatını kontrol et
        if (!StorageService.isValidImageFormat(image.path)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Desteklenmeyen dosya formatı. Lütfen JPG, PNG veya WebP formatında bir görsel seçin.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        
        // Görsel boyutunu kontrol et
        final bool isValidSize = await StorageService.validateImageSize(imageFile);
        if (!isValidSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Görsel çok büyük. Lütfen 5MB\'dan küçük bir görsel seçin.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _selectedImage = imageFile;
        });

        // Loading göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Görsel yükleniyor...'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Firebase Storage'a yükle
        final String downloadUrl = await StorageService.uploadCategoryImage(
          imageFile: imageFile,
          category: category.name,
          productId: productId,
        );

        setState(() {
          _imageUrl = downloadUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Görsel başarıyla yüklendi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        if (onComplete != null) {
          onComplete();
        }
      }
    } catch (e) {
      // Hata durumunda kullanıcıya bildirim göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Dialog için görsel yükleme işlemleri
  Future<void> _pickImageForDialog(StateSetter setDialogState, ProductCategory category, String productId) async {
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Görsel Seç',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF303030),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Kamera Seçeneği
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _getImageFromSource(ImageSource.camera, setDialogState, category, productId);
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                          child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Kamera',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Galeri Seçeneği
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _getImageFromSource(ImageSource.gallery, setDialogState, category, productId);
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                          child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
                          Icon(
                            Icons.photo_library_rounded,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Galeri',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // İptal Butonu
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print("Görsel seçim diyaloğu hatası: $e");
      _showErrorSnackbar("Görsel seçim işlemi başlatılamadı");
    }
  }

  // Belirtilen kaynaktan görsel getirme ve Firebase Storage'a yükleme
  Future<void> _getImageFromSource(
      ImageSource source, StateSetter setDialogState, ProductCategory category, String productId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        
        // Görsel formatını kontrol et
        if (!StorageService.isValidImageFormat(image.path)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Desteklenmeyen dosya formatı. Lütfen JPG, PNG veya WebP formatında bir görsel seçin.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        
        // Görsel boyutunu kontrol et
        final bool isValidSize = await StorageService.validateImageSize(imageFile);
        if (!isValidSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Görsel çok büyük. Lütfen 5MB\'dan küçük bir görsel seçin.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Yükleniyor göstergesi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Görsel yükleniyor...'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        try {
          // Firebase Storage'a yükle
          final String downloadUrl = await StorageService.uploadCategoryImage(
            imageFile: imageFile,
            category: category.name,
            productId: productId,
          );

          setDialogState(() {
            _selectedImage = imageFile;
            _imageUrl = downloadUrl;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Görsel başarıyla yüklendi!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (uploadError) {
          print("Firebase Storage yükleme hatası: $uploadError");
          _showErrorSnackbar("Görsel yüklenirken hata oluştu: ${uploadError.toString()}");
        }
      }
    } catch (e) {
      print("Görsel seçme hatası: $e");
      _showErrorSnackbar("Görsel seçilirken bir hata oluştu: ${e.toString()}");
    }
  }

  // Hata mesajı için yardımcı metot
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Ürün ekleme diyaloğu
  void _showAddProductDialog([
    ProductCategory? initialCategory,
    ProductItem? productToEdit,
  ]) {
    final isEditing = productToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? productToEdit.name : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? productToEdit.price.toString() : '',
    );
    final descriptionController = TextEditingController(
      text: isEditing ? productToEdit.description ?? '' : '',
    );
    final stockController = TextEditingController(
      text: isEditing ? productToEdit.stock.toString() : '0',
    );

    // Düzenleme modunda seçili kategoriyi ayarla
    var selectedCategory = initialCategory ??
        (isEditing
            ? productToEdit.category
            : ProductCategory.values[_selectedCategoryIndex]);

    // ProductId oluştur (yeni ürün için)
    final String productId = isEditing 
        ? productToEdit.id 
        : DateTime.now().millisecondsSinceEpoch.toString();

    // Düzenleme modunda mevcut görseli göster
    if (isEditing && productToEdit.imageUrl != null) {
      _imageUrl = productToEdit.imageUrl;
      _selectedImage = null; // URL tabanlı görsel için File kullanmıyoruz
    } else {
      _imageUrl = null;
      _selectedImage = null;
    }

    // Form validasyonu için
    bool _isNameValid = true;
    bool _isPriceValid = true;
    bool _isStockValid = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.zero,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width > 600
                          ? 560
                          : MediaQuery.of(context).size.width * 0.92,
                      height: MediaQuery.of(context).size.height * 0.85,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Başlık
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isEditing
                                              ? Icons.edit_rounded
                                              : Icons.add_rounded,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isEditing
                                                ? 'Ürünü Düzenle'
                                                : 'Yeni Ürün Ekle',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF303030),
                                            ),
                                          ),
                                          Text(
                                            isEditing
                                                ? 'Mevcut ürün bilgilerini güncelleyin'
                                                : 'Menüye yeni bir ürün ekleyin',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.grey.shade100,
                                      foregroundColor: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // İçerik
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                                    // Ürün Adı
                                    const Text(
                                      'Ürün Adı',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _isNameValid
                                              ? Colors.grey.shade200
                                              : Colors.red.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: nameController,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            _isNameValid = value.isNotEmpty;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Ürün adını girin',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 15,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.restaurant_menu_rounded,
                                            color: Colors.grey.shade500,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF303030),
                                        ),
                                      ),
                                    ),
                                    if (!_isNameValid)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 6, left: 12),
                                        child: Text(
                                          'Ürün adı boş olamaz',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade500,
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 24),

                                    // Kategori
                                    const Text(
                                      'Kategori',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 16),
                                        itemCount:
                                            ProductCategory.values.length,
                                        itemBuilder: (context, index) {
                                          final category =
                                              ProductCategory.values[index];
                                          final isSelected =
                                              category == selectedCategory;

                                          return GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                selectedCategory = category;
                                              });
                                            },
                                            child: Container(
                                              width: 80,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    _getCategoryIcon(category),
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.grey.shade700,
                                                    size: 28,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    getCategoryTitle(category),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : Colors
                                                              .grey.shade700,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Açıklama
                                    const Text(
                                      'Ürün Açıklaması',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: descriptionController,
                                        maxLines: 3,
                                        maxLength: 200,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Ürün hakkında kısa bir açıklama yazın',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 15,
                                          ),
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, top: 12),
                                            child: Icon(
                                              Icons.description_outlined,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 16, 16, 8),
                                          counterStyle: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF303030),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Ürün Görseli
                                    const Text(
                                      'Ürün Görseli',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Görsel Önizleme
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: _selectedImage != null
                                                  ? Image.file(
                                                      _selectedImage!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_rounded,
                                                            size: 64,
                                                            color: Colors
                                                                .grey.shade400,
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : _imageUrl != null
                                                      ? Image.network(
                                                          _imageUrl!,
                                                          fit: BoxFit.cover,
                                                          loadingBuilder: (context, child, loadingProgress) {
                                                            if (loadingProgress == null) return child;
                                                            return Center(
                                                              child: CircularProgressIndicator(
                                                                value: loadingProgress.expectedTotalBytes != null
                                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                                    : null,
                                                                color: AppTheme.primaryColor,
                                                              ),
                                                            );
                                                          },
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Center(
                                                              child: Icon(
                                                                Icons.broken_image_rounded,
                                                                size: 64,
                                                                color: Colors.grey.shade400,
                                                              ),
                                                            );
                                                          },
                                                        )
                                                      : Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .add_photo_alternate_rounded,
                                                                size: 52,
                                                                color: Colors
                                                                    .grey.shade300,
                                                              ),
                                                              const SizedBox(
                                                                  height: 12),
                                                              Text(
                                                                'Görsel Eklemek İçin Tıklayın',
                                                                style: TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors.grey
                                                                      .shade600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                            ),
                                          ),

                                          // Görsel Ekleme Butonu
                                          Positioned.fill(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  // Doğrudan dialog için özel yükleme metodunu çağır
                                                  _pickImageForDialog(
                                                      setDialogState, selectedCategory, productId);
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                splashColor: Colors.black
                                                    .withOpacity(0.1),
                                                highlightColor:
                                                    Colors.transparent,
                                              ),
                                            ),
                                          ),

                                          // Silme butonu (eğer görsel varsa)
                                          if (_selectedImage != null || _imageUrl != null)
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    setDialogState(() {
                                                      _selectedImage = null;
                                                      _imageUrl = null;
                                                    });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.7),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Ürün Fiyatı
                                    const Text(
                                      'Ürün Fiyatı',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _isPriceValid
                                              ? Colors.grey.shade200
                                              : Colors.red.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: priceController,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        onChanged: (value) {
                                          final priceText =
                                              value.replaceAll(',', '.');
                                          final price =
                                              double.tryParse(priceText);
                                          setDialogState(() {
                                            _isPriceValid =
                                                price != null && price > 0;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: '0.00',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 15,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.attach_money_rounded,
                                            color: Colors.grey.shade500,
                                          ),
                                          suffixText: '₺',
                                          suffixStyle: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF303030),
                                        ),
                                      ),
                                    ),
                                    if (!_isPriceValid)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 6, left: 12),
                                        child: Text(
                                          'Geçerli bir fiyat giriniz',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade500,
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 24),

                                    // Ürün Stoku
                                    const Text(
                                      'Ürün Stoku',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _isStockValid
                                              ? Colors.grey.shade200
                                              : Colors.red.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: stockController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: false,
                                        ),
                                        onChanged: (value) {
                                          final stock = int.tryParse(value);
                                          setDialogState(() {
                                            _isStockValid = stock != null && stock >= 0;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 15,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.inventory_2_rounded,
                                            color: Colors.grey.shade500,
                                          ),
                                          suffixText: 'adet',
                                          suffixStyle: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF303030),
                                        ),
                                      ),
                                    ),
                                    if (!_isStockValid)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 6, left: 12),
                                        child: Text(
                                          'Geçerli bir stok miktarı giriniz',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Alt Butonlar
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, -4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // İptal Butonu
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('İptal'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF505050),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),

                                  // Kaydet Butonu
                                  ElevatedButton.icon(
                                    onPressed: _isSaving ? null : () async {
                                      // Ad validasyonu
                                      if (nameController.text.isEmpty) {
                                        setDialogState(() {
                                          _isNameValid = false;
                                        });
                                        return;
                                      }

                                      // Fiyat validasyonu
                                      final priceText = priceController.text
                                          .replaceAll(',', '.');
                                      final price = double.tryParse(priceText);
                                      if (price == null || price <= 0) {
                                        setDialogState(() {
                                          _isPriceValid = false;
                                        });
                                        return;
                                      }

                                      // Stok validasyonu
                                      final stock = int.tryParse(stockController.text);
                                      if (stock == null || stock < 0) {
                                        setDialogState(() {
                                          _isStockValid = false;
                                        });
                                        return;
                                      }

                                      // Ürünü kaydet
                                      await _saveProduct(
                                        nameController.text,
                                        priceController.text,
                                        descriptionController.text,
                                        selectedCategory,
                                        isEditing ? productToEdit : null,
                                        stockController.text,
                                      );
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    icon: _isSaving 
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.save_rounded),
                                    label: Text(
                                      _isSaving 
                                          ? 'Kaydediliyor...' 
                                          : (isEditing ? 'Güncelle' : 'Kaydet'),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Dialog kapandığında state'i güncelle
      setState(() {});
    });
  }

  // Adım göstergesi widget'ı
  Widget _buildStepIndicator(
    StateSetter setState,
    int step,
    int currentStep,
    String label,
    IconData icon,
  ) {
    final isActive = step == currentStep;
    final isCompleted = step < currentStep;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (step < currentStep) {
            setState(() {
              currentStep = step;
            });
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : (isActive ? AppTheme.primaryColor : Colors.grey.shade200),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20)
                    : Icon(
                        icon,
                        color: isActive ? Colors.white : Colors.grey.shade500,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color:
                    isActive ? const Color(0xFF303030) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Adım bağlantı çizgisi
  Widget _buildStepConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? Colors.green : Colors.grey.shade200,
      ),
    );
  }

  // Fiyat formatı
  String _formatPrice(String priceText) {
    if (priceText.isEmpty) return '0.00';

    final price = double.tryParse(priceText.replaceAll(',', '.')) ?? 0.0;
    return price.toStringAsFixed(2);
  }

  // Ürün kaydet
  Future<void> _saveProduct(
    String name,
    String priceText,
    String description,
    ProductCategory category,
    ProductItem? productToEdit,
    String stockText,
  ) async {
    // Zaten kaydetme işlemi devam ediyorsa bekle
    if (_isSaving) {
      print("⚠️ Kaydetme işlemi zaten devam ediyor, atlanıyor...");
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final price = double.parse(priceText.replaceAll(',', '.'));
      final stock = int.parse(stockText);

      final newProduct = ProductItem(
        id: productToEdit?.id ?? _uuid.v4(), // Mevcut ürün varsa ID'sini kullan, yoksa güvenli UUID oluştur
        name: name,
        price: price,
        category: category,
        imageUrl: _imageUrl,
        description: description.isNotEmpty ? description : null,
        stock: stock,
      );

      // Local listeyi güncelle
      setState(() {
        if (productToEdit != null) {
          // Ürünü güncelle
          final index = _menuItems.indexOf(productToEdit);
          if (index != -1) {
            _menuItems[index] = newProduct;
          }
        } else {
          // Yeni ürün ekle
          _menuItems.add(newProduct);
        }
      });

      // MenuRepository üzerinden kaydet - Firebase ve yerel depolamaya kaydet
      await _menuRepository.saveMenuItems(_menuItems);

      // Başarı bildirimi göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              productToEdit != null
                  ? '${newProduct.name} güncellendi'
                  : '${newProduct.name} eklendi',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ Ürün kaydetme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ürün kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  // Ürün silme işlemi
  void _deleteProduct(ProductItem product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Ürünü Sil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF303030),
              ),
            ),
          ],
        ),
        content: Text(
          '${product.name} ürününü silmek istediğinize emin misiniz?',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF505050),
          ),
        ),
        actions: [
          // İptal Butonu
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF505050),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Text(
              'İptal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sil Butonu
          ElevatedButton(
            onPressed: _isSaving ? null : () async {
              try {
                setState(() {
                  _isSaving = true;
                  _menuItems.remove(product);
                });

                // MenuRepository üzerinden kaydet - Firebase ve yerel depolamaya kaydet
                await _menuRepository.saveMenuItems(_menuItems);
                
                if (mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} silindi'),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                print("❌ Ürün silme hatası: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ürün silinirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isSaving = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Kategori simgesini getir
  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.food:
        return Icons.restaurant_rounded;
      case ProductCategory.drink:
        return Icons.local_cafe_rounded;
      case ProductCategory.dessert:
        return Icons.cake_rounded;
      case ProductCategory.toy:
        return Icons.toys_rounded;
    }
  }

  // Kategori değiştirme
  void _changeCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _tabController.animateTo(index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // Görünüm değiştirme (Grid/Liste)
  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık ve Arama Kısmı
            buildHeader(),

            // Ana İçerik - Tab Bar ve Ürün Listesi
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      children: [
                        buildTabBar(),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _selectedCategoryIndex = index;
                                _tabController.animateTo(index);
                              });
                            },
                            itemCount: ProductCategory.values.length,
                            itemBuilder: (context, index) {
                              final category = ProductCategory.values[index];
                              final products = _getFilteredProducts(category);

                              if (products.isEmpty) {
                                return buildEmptyState(category);
                              } else {
                                return buildProductGrid(products);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Başlık ve Arama Kısmı
  Widget buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Geri ve başlık
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: const Color(0xFF303030),
                      iconSize: 22,
                      tooltip: 'Geri',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menü Yönetimi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF303030),
                        ),
                      ),
                      Text(
                        '${_menuItems.length} ürün',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Görünüm modu ve ekleme butonu
              Row(
                children: [
                  // Görünüm modu switch
                  buildViewModeSwitch(),

                  const SizedBox(width: 12),

                  // Yeni ürün ekleme butonu
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _showAddProductDialog(
                          ProductCategory.values[_selectedCategoryIndex]),
                      color: Colors.white,
                      iconSize: 22,
                      tooltip: 'Yeni Ürün Ekle',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Arama çubuğu
          buildSearchBar(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Arama Çubuğu
  Widget buildSearchBar() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSearchFocused = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: _isSearchFocused ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                _isSearchFocused ? AppTheme.primaryColor : Colors.grey.shade200,
            width: _isSearchFocused ? 2 : 1,
          ),
          boxShadow: _isSearchFocused
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: _isSearchFocused
                  ? AppTheme.primaryColor
                  : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onTap: () {
                  setState(() {
                    _isSearchFocused = true;
                  });
                },
                onSubmitted: (_) {
                  setState(() {
                    _isSearchFocused = false;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Ürün ara...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF303030),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSearch,
                color: Colors.grey.shade500,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  // Kategori Sekmeleri
  Widget buildTabBar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerHeight: 0,
        indicatorWeight: 3,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: AppTheme.primaryColor,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: ProductCategory.values.map((category) {
          return Tab(
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(getCategoryTitle(category)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Ürün Kılavuzu
  Widget buildProductGrid(List<ProductItem> products) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Bilgi satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${products.length} ürün gösteriliyor',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Sıralama seçenekleri
              buildSortOptions(),
            ],
          ),

          const SizedBox(height: 16),

          // Ürün kılavuzu
          Expanded(
            child:
                _isGridView ? buildGridView(products) : buildListView(products),
          ),
        ],
      ),
    );
  }

  // Grid görünümü
  Widget buildGridView(List<ProductItem> products) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive grid settings
    int crossAxisCount;
    double childAspectRatio;
    double spacing;
    
    if (screenWidth < 360) {
      // Very small screens
      crossAxisCount = 1;
      childAspectRatio = 1.2;
      spacing = 12;
    } else if (screenWidth < 600) {
      // Small to medium screens
      crossAxisCount = 2;
      childAspectRatio = 0.75; // Increased from 0.68 to prevent overflow
      spacing = 16;
    } else if (screenWidth < 900) {
      // Tablets
      crossAxisCount = 3;
      childAspectRatio = 0.8;
      spacing = 20;
    } else {
      // Large screens
      crossAxisCount = 4;
      childAspectRatio = 0.85;
      spacing = 24;
    }
    
    return GridView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return buildProductCard(products[index]);
      },
    );
  }

  // Liste görünümü
  Widget buildListView(List<ProductItem> products) {
    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return buildProductListItem(products[index]);
      },
    );
  }

  // Ürün Kartı - Grid görünümü için
  Widget buildProductCard(ProductItem product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 360;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showAddProductDialog(product.category, product),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ürün görseli
              Hero(
                tag: 'product_${product.name}',
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.2,
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderImage(product.category);
                              },
                            )
                          : _buildPlaceholderImage(product.category),
                    ),

                    // Kategori etiketi
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(product.category),
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              getCategoryTitle(product.category),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Düzenleme butonu
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        children: [
                          // Düzenleme butonu
                          _buildActionButton(
                            onTap: () => _showAddProductDialog(
                                product.category, product),
                            icon: Icons.edit_rounded,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          // Silme butonu
                          _buildActionButton(
                            onTap: () => _deleteProduct(product),
                            icon: Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Ürün bilgileri
              Flexible(
                child: Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ürün adı
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 14),
                          color: const Color(0xFF303030),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Ürün açıklaması
                      if (product.description != null) ...[
                        SizedBox(height: isVerySmallScreen ? 2 : 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                            color: Colors.grey.shade600,
                          ),
                          maxLines: isVerySmallScreen ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const Spacer(),

                      // Fiyat ve Stok
                      Row(
                        children: [
                          // Fiyat
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Fiyat',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 8 : 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: isVerySmallScreen ? 1 : 2),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isVerySmallScreen ? 6 : 8,
                                    vertical: isVerySmallScreen ? 3 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${product.price.toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 14),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isVerySmallScreen ? 6 : 8),
                          // Stok
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Stok',
                                style: TextStyle(
                                  fontSize: isVerySmallScreen ? 8 : 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: isVerySmallScreen ? 1 : 2),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 6 : 8,
                                  vertical: isVerySmallScreen ? 3 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: product.stock > 0 ? Colors.blue.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${product.stock}',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                                    fontWeight: FontWeight.bold,
                                    color: product.stock > 0 ? Colors.blue.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ürün Listesi Öğesi - Liste görünümü için
  Widget buildProductListItem(ProductItem product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showAddProductDialog(product.category, product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Ürün görseli
                Hero(
                  tag: 'product_${product.name}_list',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderImage(product.category);
                              },
                            )
                          : _buildPlaceholderImage(product.category),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Ürün bilgileri
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori etiketi
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(product.category),
                                  color: AppTheme.primaryColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  getCategoryTitle(product.category),
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Ürün adı
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF303030),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Ürün açıklaması
                      if (product.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2, // 1'den 2'ye çıkarıldı
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Fiyat ve işlem butonları
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Fiyat ve Stok
                          Row(
                            children: [
                              // Fiyat
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Fiyat',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${product.price.toStringAsFixed(2)} ₺',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // Stok
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Stok',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: product.stock > 0 ? Colors.blue.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${product.stock}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: product.stock > 0 ? Colors.blue.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // İşlem butonları
                          Row(
                            children: [
                              // Düzenleme butonu
                              _buildActionButton(
                                onTap: () => _showAddProductDialog(
                                    product.category, product),
                                icon: Icons.edit_rounded,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              // Silme butonu
                              _buildActionButton(
                                onTap: () => _deleteProduct(product),
                                icon: Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Boş durumda gösterilecek widget
  Widget buildEmptyState(ProductCategory category) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 56,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                children: [
                  TextSpan(
                    text: '${getCategoryTitle(category)} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: _searchQuery.isEmpty
                        ? 'kategorisinde ürün bulunamadı'
                        : 'kategorisinde eşleşen ürün bulunamadı',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Bu kategori için menünüze ürün ekleyin.'
                  : 'Farklı anahtar kelimelerle tekrar arayın veya filtrelerinizi temizleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (_searchQuery.isNotEmpty) {
                  _clearSearch();
                } else {
                  _showAddProductDialog(category);
                }
              },
              icon: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.clear_rounded
                    : Icons.add_rounded,
                size: 18,
              ),
              label: Text(
                _searchQuery.isNotEmpty ? 'Filtreleri Temizle' : 'Ürün Ekle',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yüzen Eylem Butonu
  Widget buildFloatingActionButton() {
    return FloatingActionButton(
      heroTag: 'menu_management_fab',
      onPressed: () =>
          _showAddProductDialog(ProductCategory.values[_selectedCategoryIndex]),
      backgroundColor: AppTheme.primaryColor,
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  // Sıralama Seçenekleri
  Widget buildSortOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 16,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'Sırala',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }

  // Görünüm Modu Değiştirme Butonu
  Widget buildViewModeSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildViewModeButton(
            isActive: _isGridView,
            icon: Icons.grid_view_rounded,
            onTap: () {
              if (!_isGridView) {
                setState(() {
                  _isGridView = true;
                });
              }
            },
          ),
          _buildViewModeButton(
            isActive: !_isGridView,
            icon: Icons.view_list_rounded,
            onTap: () {
              if (_isGridView) {
                setState(() {
                  _isGridView = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // Görünüm Modu Butonu
  Widget _buildViewModeButton({
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }

  // Ürün placeholder görseli
  Widget _buildPlaceholderImage(ProductCategory category) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 32,
          color: Colors.grey.shade300,
        ),
      ),
    );
  }

  // İşlem butonu
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
