import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/business_settings_model.dart';
import '../../data/repositories/business_settings_repository.dart';
import '../../data/services/admin_auth_service.dart';

class BusinessManagementScreen extends StatefulWidget {
  const BusinessManagementScreen({Key? key}) : super(key: key);

  @override
  State<BusinessManagementScreen> createState() => _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen> {
  final BusinessSettingsRepository _repository = BusinessSettingsRepository();
  List<BusinessSettings> _businessSettings = [];
  bool _isLoading = true;
  BusinessCategory? _selectedCategory;
  BusinessSettings? _selectedSetting;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadBusinessSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // İşletme ayarlarını yükle
  Future<void> _loadBusinessSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final settings = await _repository.getAllBusinessSettings();
      
      if (settings.isEmpty) {
        // Varsayılan ayarları ekle
        await _repository.addDefaultBusinessSettings();
        final newSettings = await _repository.getAllBusinessSettings();
        setState(() {
          _businessSettings = newSettings;
        });
      } else {
        setState(() {
          _businessSettings = settings;
        });
      }

      // Debug: Kategorileri logla
      print('Yüklenen kategoriler:');
      for (final setting in _businessSettings) {
        print('- ${setting.name}: ${setting.category}');
      }

      // İlk kategoriyi seç
      if (_businessSettings.isNotEmpty) {
        _selectedCategory = _businessSettings.first.category;
        _updateSelectedSetting();
      }
    } catch (e) {
      print('İşletme ayarları yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşletme ayarları yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Seçilen kategoriye göre ayarları güncelle
  void _updateSelectedSetting() {
    if (_selectedCategory != null) {
      try {
        _selectedSetting = _businessSettings.firstWhere(
          (setting) => setting.category == _selectedCategory,
        );
        print('Seçilen kategori: ${_selectedSetting?.name} (${_selectedSetting?.category})');
      } catch (e) {
        print('Kategori bulunamadı: $_selectedCategory');
        _selectedSetting = null;
      }
    }
  }

  // Kategori değiştiğinde
  void _onCategoryChanged(BusinessCategory? category) {
    setState(() {
      _selectedCategory = category;
      _updateSelectedSetting();
    });
  }

  // Yeni kategori ekleme dialog'u
  void _showAddCategoryDialog() {
    _nameController.clear();
    _descriptionController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_business, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Yeni Kategori Ekle'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Kategori Adı',
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kategori adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Açıklama gerekli';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  // Yeni kategori oluştur
                  final newSetting = BusinessSettings(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    category: BusinessCategory.values.first, // Geçici olarak ilk kategori
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim(),
                    durationPrices: [],
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await _repository.addBusinessSetting(newSetting);
                  Navigator.pop(context);
                  _loadBusinessSettings();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kategori başarıyla eklendi: ${newSetting.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kategori eklenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // Yeni süre/fiyat ekleme dialog'u
  void _showAddDurationPriceDialog() {
    _durationController.clear();
    _priceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('${_selectedSetting?.name ?? 'Kategori'} - Yeni Seçenek Ekle'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _selectedSetting?.category == BusinessCategory.oyunAlani 
                      ? 'Dakika' 
                      : 'Seans Sayısı',
                  prefixIcon: Icon(
                    _selectedSetting?.category == BusinessCategory.oyunAlani 
                        ? Icons.access_time 
                        : Icons.event_note
                  ),
                  helperText: _selectedSetting?.category == BusinessCategory.oyunAlani 
                      ? 'Örnek: 30, 60, 120 (dakika)'
                      : 'Örnek: 1, 4, 8 (seans)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bu alan gerekli';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fiyat (₺)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fiyat gerekli';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price < 0) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  final duration = int.parse(_durationController.text);
                  final price = double.parse(_priceController.text);

                  // Yeni süre/fiyat ekle
                  final newDurationPrice = DurationPrice(
                    duration: duration,
                    price: price,
                    isActive: true,
                  );

                  final updatedSetting = _selectedSetting!.copyWith(
                    durationPrices: [..._selectedSetting!.durationPrices, newDurationPrice],
                    updatedAt: DateTime.now(),
                  );

                  await _repository.updateBusinessSetting(updatedSetting);
                  Navigator.pop(context);
                  
                  // Sadece mevcut kategoriyi güncelle, tüm listeyi yeniden yükleme
                  setState(() {
                    _selectedSetting = updatedSetting;
                    // Mevcut kategorideki ayarları güncelle
                    final index = _businessSettings.indexWhere(
                      (setting) => setting.id == updatedSetting.id
                    );
                    if (index != -1) {
                      _businessSettings[index] = updatedSetting;
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seçenek başarıyla eklendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seçenek eklenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // Fiyat düzenleme dialog'u
  void _showEditPriceDialog(DurationPrice durationPrice) {
    final priceController = TextEditingController(
      text: durationPrice.price.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(_selectedSetting?.categoryIcon ?? '📋', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('${_selectedSetting?.name ?? 'Kategori'} - ${durationPrice.formattedDuration}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yeni fiyat girin:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Fiyat (₺)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice >= 0) {
                try {
                  await _repository.updateCategoryPrice(
                    _selectedSetting!.id,
                    durationPrice.duration,
                    newPrice,
                  );
                  
                  Navigator.pop(context);
                  
                  // Sadece mevcut kategoriyi güncelle
                  setState(() {
                    // Mevcut kategorideki fiyatı güncelle
                    final updatedDurationPrices = _selectedSetting!.durationPrices.map((dp) {
                      if (dp.duration == durationPrice.duration) {
                        return dp.copyWith(price: newPrice);
                      }
                      return dp;
                    }).toList();
                    
                    _selectedSetting = _selectedSetting!.copyWith(
                      durationPrices: updatedDurationPrices,
                    );
                    
                    // Ana listedeki ayarları da güncelle
                    final index = _businessSettings.indexWhere(
                      (setting) => setting.id == _selectedSetting!.id
                    );
                    if (index != -1) {
                      _businessSettings[index] = _selectedSetting!;
                    }
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fiyat başarıyla güncellendi: ${newPrice.toStringAsFixed(2)} ₺'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fiyat güncellenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen geçerli bir fiyat girin'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  // Kategori silme dialog'u
  void _showDeleteCategoryDialog(BusinessSettings setting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Kategori Sil'),
          ],
        ),
        content: Text(
          '${setting.name} kategorisini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _repository.deleteBusinessSetting(setting.id);
                Navigator.pop(context);
                _loadBusinessSettings();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${setting.name} kategorisi silindi'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kategori silinirken hata oluştu: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Çıkış yapma dialog'u
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Çıkış Yap'),
          ],
        ),
        content: const Text('Uygulamadan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<AdminAuthService>(context, listen: false).logout();
              Navigator.pop(context); // Dialog'u kapat
              
              // Login sayfasına yönlendir
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login', // Route adı
                (route) => false, // Tüm route'ları temizle
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminAuthService = Provider.of<AdminAuthService>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Icon(Icons.business, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'İşletme Yönetimi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          // Kullanıcı bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  adminAuthService.userRoleString,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Geri butonu kaldırıldı
      ),
      body: Column(
        children: [
          // Kategori seçimi ve yönetimi
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.category, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Kategori Seçimi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Yeni kategori ekleme butonu
                    IconButton(
                      onPressed: _showAddCategoryDialog,
                      icon: Icon(Icons.add_circle, color: AppTheme.primaryColor),
                      tooltip: 'Yeni Kategori Ekle',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Kategori dropdown
                DropdownButtonFormField<BusinessCategory>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori Seçin',
                    prefixIcon: Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _businessSettings
                      .map((setting) => setting.category)
                      .toSet() // Duplicate kategorileri kaldır
                      .map((category) {
                    final setting = _businessSettings.firstWhere(
                      (s) => s.category == category,
                    );
                    print('Dropdown item: ${setting.name} -> ${category}');
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Text(setting.categoryIcon),
                          const SizedBox(width: 8),
                          Text(setting.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _onCategoryChanged,
                ),
                
                const SizedBox(height: 16),
                
                // Seçilen kategori bilgileri
                if (_selectedSetting != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedSetting!.categoryIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSetting!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _selectedSetting!.description,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Kategori silme butonu
                        IconButton(
                          onPressed: () => _showDeleteCategoryDialog(_selectedSetting!),
                          icon: Icon(Icons.delete, color: Colors.red.shade600),
                          tooltip: 'Kategoriyi Sil',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // İçerik
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _selectedSetting == null
                    ? _buildEmptyState()
                    : _buildCategoryContent(),
          ),
        ],
      ),
      floatingActionButton: _selectedSetting != null
          ? FloatingActionButton.extended(
              onPressed: _showAddDurationPriceDialog,
              icon: const Icon(Icons.add),
              label: Text('${_selectedSetting!.name} Seçeneği Ekle'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildCategoryContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Başlık
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                _selectedSetting!.categoryIcon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedSetting!.name} Seçenekleri',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Mevcut süre ve fiyat seçenekleri',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Seçenekler listesi
        if (_selectedSetting!.durationPrices.isEmpty)
          _buildEmptyOptionsState()
        else
          ..._selectedSetting!.durationPrices.map((durationPrice) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Süre/Seans
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                                                 Icon(
                           _selectedSetting!.category == BusinessCategory.oyunAlani
                               ? Icons.access_time
                               : Icons.event_note,
                           size: 20,
                           color: Colors.grey.shade600,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           _selectedSetting!.category == BusinessCategory.oyunAlani
                               ? '${durationPrice.duration} dakika'
                               : durationPrice.formattedDuration,
                           style: const TextStyle(
                             fontWeight: FontWeight.w600,
                             fontSize: 16,
                           ),
                         ),
                      ],
                    ),
                  ),
                  
                  // Fiyat
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 20,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          durationPrice.formattedPrice,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Düzenle butonu
                  IconButton(
                    onPressed: () => _showEditPriceDialog(durationPrice),
                    icon: Icon(
                      Icons.edit,
                      color: AppTheme.primaryColor,
                    ),
                    tooltip: 'Fiyatı Düzenle',
                  ),
                ],
              ),
            );
          }).toList(),
        
        const SizedBox(height: 16),
        
        // Çıkış butonu - Sayfanın altına eklendi
        Container(
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'Çıkış Yap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_center,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Kategori Seçin',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yukarıdan bir kategori seçin veya yeni kategori ekleyin',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOptionsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Seçenek Yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu kategori için henüz süre/fiyat seçeneği eklenmemiş',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDurationPriceDialog,
            icon: const Icon(Icons.add),
            label: Text('${_selectedSetting!.name} Seçeneği Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
