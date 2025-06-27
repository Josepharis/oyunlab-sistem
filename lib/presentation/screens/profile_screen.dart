import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mesai bilgileri
  bool _isShiftActive = false;
  DateTime? _shiftStartTime;
  Duration _currentShiftDuration = Duration.zero;
  List<ShiftRecord> _shiftHistory = [];
  Timer? _shiftTimer;

  // Satış verileri
  final List<SaleRecord> _salesHistory = [];

  // Personel bilgileri
  final String _staffName = "Ayşe Yılmaz";
  final String _staffPosition = "Oyun Alanı Personeli";
  final String _staffId = "P-10023";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Örnek mesai geçmişi
    final now = DateTime.now();
    _shiftHistory = [
      ShiftRecord(
        startTime: now.subtract(const Duration(days: 1, hours: 9)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
      ),
      ShiftRecord(
        startTime: now.subtract(const Duration(days: 2, hours: 8)),
        endTime: now.subtract(const Duration(days: 2)),
      ),
      ShiftRecord(
        startTime: now.subtract(const Duration(days: 3, hours: 9)),
        endTime: now.subtract(const Duration(days: 3, hours: 1)),
      ),
    ];

    // Örnek satış geçmişi
    _salesHistory.addAll([
      SaleRecord(
        date: now.subtract(const Duration(days: 1, hours: 3)),
        customerName: "Ali Can",
        amount: 60.0,
        description: "2 saat oyun alanı",
      ),
      SaleRecord(
        date: now.subtract(const Duration(days: 1, hours: 4)),
        customerName: "Mehmet Yıldız",
        amount: 45.0,
        description: "1.5 saat oyun alanı",
      ),
      SaleRecord(
        date: now.subtract(const Duration(days: 1, hours: 6)),
        customerName: "Zeynep Kaya",
        amount: 30.0,
        description: "1 saat oyun alanı",
      ),
      SaleRecord(
        date: now.subtract(const Duration(days: 2, hours: 5)),
        customerName: "Ayşe Demir",
        amount: 50.0,
        description: "1.5 saat oyun alanı + yiyecek",
      ),
      SaleRecord(
        date: now.subtract(const Duration(days: 2, hours: 7)),
        customerName: "Can Özcan",
        amount: 65.0,
        description: "2 saat oyun alanı + içecek",
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shiftTimer?.cancel();
    super.dispose();
  }

  // Mesaiye başla
  void _startShift() {
    if (!_isShiftActive) {
      setState(() {
        _isShiftActive = true;
        _shiftStartTime = DateTime.now();
        _currentShiftDuration = Duration.zero;
      });

      // Timer başlat ve her saniye güncelle
      _shiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_shiftStartTime != null) {
          setState(() {
            _currentShiftDuration = DateTime.now().difference(_shiftStartTime!);
          });
        }
      });
    }
  }

  // Mesaiden çık
  void _endShift() {
    if (_isShiftActive && _shiftStartTime != null) {
      _shiftTimer?.cancel();

      final endTime = DateTime.now();

      // Mesai kaydını ekle
      setState(() {
        _shiftHistory.insert(
          0,
          ShiftRecord(startTime: _shiftStartTime!, endTime: endTime),
        );

        _isShiftActive = false;
        _shiftStartTime = null;
        _currentShiftDuration = Duration.zero;
      });

      // Başarılı mesaj göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesainiz başarıyla kaydedildi!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Mesai kaydını düzenle
  void _editShiftRecord(
    ShiftRecord shiftRecord,
    DateTime newStartTime,
    DateTime newEndTime,
  ) {
    setState(() {
      final index = _shiftHistory.indexWhere(
        (shift) => shift.id == shiftRecord.id,
      );
      if (index != -1) {
        _shiftHistory[index] = ShiftRecord(
          startTime: newStartTime,
          endTime: newEndTime,
          id: shiftRecord.id,
        );
      }
    });

    // Başarılı mesaj göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mesai kaydı başarıyla güncellendi!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Mesai kaydını sil
  void _deleteShiftRecord(ShiftRecord shift) {
    setState(() {
      _shiftHistory.removeWhere((shift) => shift.id == shift.id);
    });

    // Başarılı mesaj göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mesai kaydı başarıyla silindi!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Satış kaydını düzenle
  void _editSaleRecord(
    SaleRecord saleRecord,
    DateTime newDate,
    String newCustomerName,
    double newAmount,
    String newDescription,
  ) {
    setState(() {
      final index = _salesHistory.indexWhere(
        (sale) => sale.id == saleRecord.id,
      );
      if (index != -1) {
        _salesHistory[index] = SaleRecord(
          date: newDate,
          customerName: newCustomerName,
          amount: newAmount,
          description: newDescription,
          id: saleRecord.id,
        );
      }
    });

    // Başarılı mesaj göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Satış kaydı başarıyla güncellendi!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Satış kaydını sil
  void _deleteSaleRecord(SaleRecord sale) {
    setState(() {
      _salesHistory.removeWhere((sale) => sale.id == sale.id);
    });

    // Başarılı mesaj göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Satış kaydı başarıyla silindi!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Toplam mesai süresini hesapla
  Duration _calculateTotalShiftDuration() {
    int totalMinutes = 0;

    for (var shift in _shiftHistory) {
      totalMinutes += shift.duration.inMinutes;
    }

    return Duration(minutes: totalMinutes);
  }

  // Toplam satış tutarını hesapla
  double _calculateTotalSales() {
    return _salesHistory.fold(0.0, (sum, sale) => sum + sale.amount);
  }

  @override
  Widget build(BuildContext context) {
    final totalShiftDuration = _calculateTotalShiftDuration();
    final totalSales = _calculateTotalSales();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - Profil bilgileri
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profil ve mesai durumu
                  Row(
                    children: [
                      // Profil resmi
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          size: 36,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Profil bilgileri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _staffName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _staffPosition,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: $_staffId',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Mesai durumu
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _isShiftActive
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _isShiftActive
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isShiftActive ? Icons.timer : Icons.timer_off,
                              size: 16,
                              color:
                                  _isShiftActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isShiftActive ? 'Mesaide' : 'Mesai Dışı',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    _isShiftActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Özet bilgiler
                  Row(
                    children: [
                      // Toplam mesai
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.watch_later_outlined,
                          iconColor: AppTheme.primaryColor,
                          title: 'Toplam Mesai',
                          value:
                              '${totalShiftDuration.inHours} sa ${totalShiftDuration.inMinutes % 60} dk',
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Toplam satış
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.monetization_on_outlined,
                          iconColor: Colors.green.shade700,
                          title: 'Toplam Satış',
                          value: '${totalSales.toStringAsFixed(2)} ₺',
                        ),
                      ),
                    ],
                  ),

                  // Aktif mesai süresi
                  if (_isShiftActive) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Aktif Mesai Süresi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDuration(_currentShiftDuration),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _shiftStartTime != null
                                ? 'Başlangıç: ${DateFormat('HH:mm, d MMM', 'tr_TR').format(_shiftStartTime!)}'
                                : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Mesai başlat/bitir butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isShiftActive ? _endShift : _startShift,
                      icon: Icon(
                        _isShiftActive ? Icons.exit_to_app : Icons.play_arrow,
                      ),
                      label: Text(
                        _isShiftActive ? 'Mesai Çıkışı Yap' : 'Mesaiye Başla',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isShiftActive
                                ? Colors.red.shade600
                                : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryColor,
                    tabs: const [
                      Tab(text: 'Mesai Geçmişi'),
                      Tab(text: 'Satışlarım'),
                    ],
                  ),
                ],
              ),
            ),

            // Tab içerikleri
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Mesai geçmişi
                  _buildShiftHistoryList(),

                  // Satış geçmişi
                  _buildSalesHistoryList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Özet bilgi kartları
  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Mesai geçmişi listesi
  Widget _buildShiftHistoryList() {
    if (_shiftHistory.isEmpty) {
      return _buildEmptyState(
        'Mesai Kaydı Bulunamadı',
        'Henüz mesai kaydı bulunmuyor.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shiftHistory.length,
      itemBuilder: (context, index) {
        final shift = _shiftHistory[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tarih
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'd MMMM yyyy, EEEE',
                        'tr_TR',
                      ).format(shift.startTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    // İşlem menüsü
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditShiftDialog(shift);
                        } else if (value == 'delete') {
                          _showDeleteShiftDialog(shift);
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.blue.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Düzenle'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Sil'),
                                ],
                              ),
                            ),
                          ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Başlangıç - Bitiş - Süre
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeColumn(
                        icon: Icons.login,
                        iconColor: Colors.green.shade600,
                        title: 'Başlangıç',
                        time: shift.startTime,
                      ),
                    ),

                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade200,
                    ),

                    Expanded(
                      child: _buildTimeColumn(
                        icon: Icons.logout,
                        iconColor: Colors.red.shade600,
                        title: 'Bitiş',
                        time: shift.endTime,
                      ),
                    ),

                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade200,
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timelapse,
                                size: 14,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Toplam',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${shift.duration.inHours} sa ${shift.duration.inMinutes % 60} dk',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Satış geçmişi listesi
  Widget _buildSalesHistoryList() {
    if (_salesHistory.isEmpty) {
      return _buildEmptyState(
        'Satış Kaydı Bulunamadı',
        'Henüz satış kaydı bulunmuyor.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _salesHistory.length,
      itemBuilder: (context, index) {
        final sale = _salesHistory[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fiyat ikonu
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.payment,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Satış detayları
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sale.customerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${sale.amount.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat(
                          'd MMM yyyy, HH:mm',
                          'tr_TR',
                        ).format(sale.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // İşlem menüsü
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditSaleDialog(sale);
                    } else if (value == 'delete') {
                      _showDeleteSaleDialog(sale);
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                color: Colors.blue.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text('Düzenle'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text('Sil'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Zaman bilgisi sütunu
  Widget _buildTimeColumn({
    required IconData icon,
    required Color iconColor,
    required String title,
    required DateTime time,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('HH:mm', 'tr_TR').format(time),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Boş durum gösterimi
  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Süre formatı
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  // Mesai düzenleme diyaloğu
  void _showEditShiftDialog(ShiftRecord shift) {
    final startTimeController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(shift.startTime),
    );
    final endTimeController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(shift.endTime),
    );

    DateTime? newStartTime = shift.startTime;
    DateTime? newEndTime = shift.endTime;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_calendar,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mesai Kaydını Düzenle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Başlangıç zamanı
                  const Text(
                    'Başlangıç Zamanı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: shift.startTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('tr', 'TR'),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryColor,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.white,
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(shift.startTime),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime != null) {
                          newStartTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          startTimeController.text = DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'tr_TR',
                          ).format(newStartTime!);
                          setState(() {});
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'tr_TR',
                            ).format(newStartTime!),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('HH:mm', 'tr_TR').format(newStartTime!),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bitiş zamanı
                  const Text(
                    'Bitiş Zamanı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: shift.endTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('tr', 'TR'),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryColor,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.white,
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(shift.endTime),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime != null) {
                          newEndTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          endTimeController.text = DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'tr_TR',
                          ).format(newEndTime!);
                          setState(() {});
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'tr_TR',
                            ).format(newEndTime!),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('HH:mm', 'tr_TR').format(newEndTime!),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Toplam süre
                  if (newStartTime != null && newEndTime != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Toplam Süre: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            '${newEndTime!.difference(newStartTime!).inHours} saat ${newEndTime!.difference(newStartTime!).inMinutes % 60} dakika',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (newStartTime != null && newEndTime != null) {
                            if (newEndTime!.isAfter(newStartTime!)) {
                              Navigator.of(context).pop();
                              _editShiftRecord(
                                shift,
                                newStartTime!,
                                newEndTime!,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bitiş zamanı başlangıç zamanından sonra olmalıdır!',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Mesai silme diyaloğu
  void _showDeleteShiftDialog(ShiftRecord shift) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.delete_forever,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mesai Kaydını Sil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Uyarı metni
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bu mesai kaydı kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Silinecek veri bilgileri
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silinecek Mesai Kaydı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tarih
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'd MMMM yyyy',
                                'tr_TR',
                              ).format(shift.startTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Saat aralığı
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${DateFormat('HH:mm', 'tr_TR').format(shift.startTime)} - ${DateFormat('HH:mm', 'tr_TR').format(shift.endTime)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Toplam süre
                        Row(
                          children: [
                            Icon(
                              Icons.timelapse,
                              size: 16,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Toplam: ${shift.duration.inHours} saat ${shift.duration.inMinutes % 60} dakika',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Vazgeç',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteShiftRecord(shift);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Sil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Satış düzenleme diyaloğu
  void _showEditSaleDialog(SaleRecord sale) {
    final dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date),
    );
    final customerNameController = TextEditingController(
      text: sale.customerName,
    );
    final amountController = TextEditingController(
      text: sale.amount.toString(),
    );
    final descriptionController = TextEditingController(text: sale.description);

    DateTime? newDate = sale.date;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.paid_rounded,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Satış Kaydını Düzenle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Tarih seçici
                    const Text(
                      'Satış Tarihi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: sale.date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('tr', 'TR'),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(sale.date),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppTheme.primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                  dialogBackgroundColor: Colors.white,
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (pickedTime != null) {
                            newDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            dateController.text = DateFormat(
                              'dd/MM/yyyy HH:mm',
                              'tr_TR',
                            ).format(newDate!);
                            setState(() {});
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat(
                                'dd MMMM yyyy',
                                'tr_TR',
                              ).format(newDate!),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('HH:mm', 'tr_TR').format(newDate!),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Müşteri Adı
                    const Text(
                      'Müşteri Adı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: customerNameController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            color: Colors.grey.shade600,
                          ),
                          hintText: 'Müşteri adını girin',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tutar
                    const Text(
                      'Satış Tutarı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.monetization_on,
                            color: Colors.green.shade600,
                          ),
                          suffixText: '₺',
                          suffixStyle: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: 'Tutarı girin',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Açıklama
                    const Text(
                      'Açıklama',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, top: 12),
                            child: Icon(
                              Icons.description,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          alignLabelWithHint: true,
                          hintText: 'Satış hakkında açıklama girin',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Butonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'İptal',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            // Form kontrolü
                            if (customerNameController.text.isEmpty ||
                                amountController.text.isEmpty ||
                                descriptionController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Lütfen tüm alanları doldurun!',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Tutar doğrulaması
                            double? amount;
                            try {
                              amount = double.parse(
                                amountController.text.replaceAll(',', '.'),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Geçersiz tutar formatı!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tutar 0\'dan büyük olmalıdır!',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            Navigator.of(context).pop();
                            _editSaleRecord(
                              sale,
                              newDate!,
                              customerNameController.text,
                              amount,
                              descriptionController.text,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Kaydet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  // Satış silme diyaloğu
  void _showDeleteSaleDialog(SaleRecord sale) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.delete_forever,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Satış Kaydını Sil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Uyarı metni
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bu satış kaydı kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Silinecek veri bilgileri
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silinecek Satış Kaydı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Müşteri
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sale.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Tutar
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 16,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${sale.amount.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Açıklama
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.description,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sale.description,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Tarih
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'd MMMM yyyy, HH:mm',
                                'tr_TR',
                              ).format(sale.date),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Vazgeç',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteSaleRecord(sale);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Sil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// Mesai kaydı sınıfı
class ShiftRecord {
  final DateTime startTime;
  final DateTime endTime;
  final String id;

  ShiftRecord({required this.startTime, required this.endTime, String? id})
    : this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Duration get duration => endTime.difference(startTime);
}

// Satış kaydı sınıfı
class SaleRecord {
  final DateTime date;
  final String customerName;
  final double amount;
  final String description;
  final String id;

  SaleRecord({
    required this.date,
    required this.customerName,
    required this.amount,
    required this.description,
    String? id,
  }) : this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}
