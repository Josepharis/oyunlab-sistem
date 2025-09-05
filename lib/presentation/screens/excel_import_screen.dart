import 'package:flutter/material.dart';
import '../../data/simple_excel_import.dart';

/// Excel import ekranı
class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final SimpleExcelImport _excelImport = SimpleExcelImport();
  bool _isLoading = false;
  String _statusMessage = '';
  List<Map<String, dynamic>> _excelData = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Veri Aktarımı'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Durum mesajı
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅') 
                      ? Colors.green.shade100 
                      : _statusMessage.contains('❌')
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('✅') 
                        ? Colors.green 
                        : _statusMessage.contains('❌')
                            ? Colors.red
                            : Colors.blue,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 14),
                ),
              ),

            // Excel dosyasını oku butonu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _readExcelFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Excel Dosyasını Oku'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // Veri önizleme
            if (_excelData.isNotEmpty) ...[
              Text(
                'Excel Verileri (${_excelData.length} satır)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _excelData.length,
                  itemBuilder: (context, index) {
                    final item = _excelData[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          item['childName'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Telefon: ${item['phoneNumber']}'),
                        trailing: const Icon(Icons.person, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Import butonları
            if (_excelData.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _importToFirestore,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Firestore\'a Aktar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _clearData,
                      icon: const Icon(Icons.clear),
                      label: const Text('Temizle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Mevcut verileri temizle butonu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _clearExistingData,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Mevcut Müşteri Verilerini Temizle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            // Loading indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Excel dosyasını oku
  Future<void> _readExcelFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '📊 Excel dosyası okunuyor...';
    });

    try {
      final data = await _excelImport.readExcelData();
      setState(() {
        _excelData = data;
        _statusMessage = data.isEmpty 
            ? '❌ Excel dosyasında veri bulunamadı'
            : '✅ ${data.length} satır veri okundu';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Excel dosyası okuma hatası: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Verileri Firestore'a aktar
  Future<void> _importToFirestore() async {
    if (_excelData.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '🔥 Firestore\'a veri aktarılıyor...';
    });

    try {
      await _excelImport.importToFirestore(_excelData);
      setState(() {
        _statusMessage = '✅ Veriler başarıyla Firestore\'a aktarıldı!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Firestore aktarım hatası: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Verileri temizle
  void _clearData() {
    setState(() {
      _excelData = [];
      _statusMessage = '🗑️ Veriler temizlendi';
    });
  }

  /// Mevcut verileri temizle
  Future<void> _clearExistingData() async {
    // Onay iste
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verileri Temizle'),
        content: const Text(
          'Tüm mevcut müşteri verileri silinecek. Bu işlem geri alınamaz!\n\nDevam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '🗑️ Mevcut veriler temizleniyor...';
    });

    try {
      await _excelImport.clearExistingCustomers();
      setState(() {
        _statusMessage = '✅ Mevcut veriler temizlendi';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Veri temizleme hatası: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
