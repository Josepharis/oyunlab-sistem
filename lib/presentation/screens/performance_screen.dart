import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/sale_service.dart';
import '../../data/models/task_model.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/admin_user_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/admin_user_repository.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({Key? key}) : super(key: key);

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Task> _completedTasks = [];
  List<Staff> _staffList = [];
  Map<String, double> _taskScores = {};
  Map<String, double> _salesPerformance = {};
  bool _isLoading = true;
  
  // Tarih filtreleme
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Grafik verileri
  List<BarChartGroupData> _taskScoreBars = [];
  List<BarChartGroupData> _salesBars = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPerformanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPerformanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Tamamlanan görevleri yükle
      await _loadCompletedTasks();
      
      // Personel listesini yükle
      await _loadStaffList();
      
      // Görev puanlarını hesapla
      _calculateTaskScores();
      
      // Satış performansını hesapla
      await _calculateSalesPerformance();
      
      // Grafik verilerini oluştur
      _generateChartData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Performans verileri yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompletedTasks() async {
    try {
      final taskRepository = TaskRepository(FirebaseService());
      _completedTasks = await taskRepository.getCompletedTasks();
      
      // Tarih filtresini uygula
      _completedTasks = _completedTasks.where((task) {
        if (task.completedAt == null) return false;
        return task.completedAt!.isAfter(_startDate) && 
               task.completedAt!.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      print('Tamamlanan görevler yüklenirken hata: $e');
      _completedTasks = [];
    }
  }

  Future<void> _loadStaffList() async {
    try {
      // AdminUserRepository'den tüm kullanıcıları çek ve staff olanları filtrele
      final adminUserRepository = AdminUserRepository();
      final allUsers = await adminUserRepository.getAllAdminUsers();
      
      _staffList = allUsers
          .where((user) => user.role == UserRole.staff)
          .map((user) => Staff(
                id: user.id,
                name: user.name,
                email: user.email,
                createdAt: user.createdAt,
              ))
          .toList();
      
      print('PERFORMANCE: ${_staffList.length} personel yüklendi');
    } catch (e) {
      print('Personel listesi yüklenirken hata: $e');
      _staffList = [];
    }
  }

  void _calculateTaskScores() {
    _taskScores.clear();
    
    for (final task in _completedTasks) {
      // Sadece tamamlanan görevler için puan hesapla
      if (task.status != TaskStatus.completed || task.completedByStaffIds.isEmpty) {
        continue;
      }
      
      // Görev zorluğuna göre puan belirle
      double baseScore;
      switch (task.difficulty) {
        case TaskDifficulty.easy:
          baseScore = 1.0;
          break;
        case TaskDifficulty.medium:
          baseScore = 2.0;
          break;
        case TaskDifficulty.hard:
          baseScore = 3.0;
          break;
      }
      
      // Görevi tamamlayan kişi sayısına eşit olarak böl
      final completedByCount = task.completedByStaffIds.length;
      final scorePerPerson = baseScore / completedByCount;
      
      // Her tamamlayan kişiye eşit pay ver
      for (final staffId in task.completedByStaffIds) {
        _taskScores[staffId] = (_taskScores[staffId] ?? 0.0) + scorePerPerson;
      }
    }
  }

  Future<void> _calculateSalesPerformance() async {
    _salesPerformance.clear();
    
    try {
      // Tüm personellere başlangıçta 0 satış ata
      for (final staff in _staffList) {
        _salesPerformance[staff.id] = 0.0;
      }
      
      // SaleService'den her personelin satış verilerini çek
      final saleService = SaleService();
      
      // Önce tüm satış verilerini çek
      final allSales = await saleService.getAllSales(
        startDate: _startDate,
        endDate: _endDate.add(const Duration(days: 1)),
      );
      
      print('PERFORMANCE: Toplam ${allSales.length} satış kaydı bulundu');
      
      // Her satış kaydının userId'sini logla
      for (var sale in allSales.take(3)) {
        print('PERFORMANCE: Satış - userId: ${sale.userId}, amount: ${sale.amount}₺');
      }
      
      // UserId'leri personel ID'leri ile eşleştir
      final Map<String, String> userIdToStaffId = {
        'BEFJaZjpIcWcJLXretgminPv3f62': '8Du1xz4Mjp6XoYUqTwNb', // Deneme
        'B26gwidYH2TfiJ4NITBYjejYsvL2': 'wNSdTHJopYJ9BwwzTsLE', // Ali
        // Diğer userId'ler için varsayılan atama
      };
      
      // Her personel için satış verilerini hesapla
      for (final staff in _staffList) {
        try {
          print('PERFORMANCE: ${staff.name} (ID: ${staff.id}) için satış aranıyor...');
          
          // Personelin ID'si ile eşleşen satışları bul
          double totalSales = 0.0;
          final staffSales = allSales.where((sale) {
            // Önce doğrudan eşleşme kontrol et
            if (sale.userId == staff.id) return true;
            
            // Sonra userId mapping'den kontrol et
            final mappedStaffId = userIdToStaffId[sale.userId];
            return mappedStaffId == staff.id;
          }).toList();
          
          for (var sale in staffSales) {
            totalSales += sale.amount;
          }
          
          _salesPerformance[staff.id] = totalSales;
          print('PERFORMANCE: ${staff.name} - ${totalSales}₺ satış (${staffSales.length} kayıt)');
        } catch (e) {
          print('PERFORMANCE: ${staff.name} satış hesaplama hatası: $e');
          _salesPerformance[staff.id] = 0.0;
        }
      }
      
      print('PERFORMANCE: Satış performansı hesaplandı - ${_salesPerformance.length} personel');
    } catch (e) {
      print('Satış performansı hesaplanırken hata: $e');
      // Hata durumunda tüm personellere 0 satış ata
      for (final staff in _staffList) {
        _salesPerformance[staff.id] = 0.0;
      }
    }
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarih Aralığı Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Son 7 Gün'),
              onTap: () => _setDateRange(7),
            ),
            ListTile(
              title: const Text('Son 30 Gün'),
              onTap: () => _setDateRange(30),
            ),
            ListTile(
              title: const Text('Son 90 Gün'),
              onTap: () => _setDateRange(90),
            ),
            ListTile(
              title: const Text('Özel Aralık'),
              onTap: () => _showCustomDateRange(),
            ),
          ],
        ),
      ),
    );
  }

  void _setDateRange(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = DateTime.now().subtract(Duration(days: days));
    });
    _loadPerformanceData();
  }

  void _showCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadPerformanceData();
    }
    Navigator.pop(context);
  }

  void _generateChartData() {
    // Görev puanı bar chart verileri (her personel için ayrı bar)
    _taskScoreBars = _staffList.asMap().entries.map((entry) {
      final index = entry.key;
      final staff = entry.value;
      final score = _taskScores[staff.id] ?? 0.0;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: score,
            color: _getScoreColor(score),
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
    
    // Satış bar chart verileri (her personel için ayrı bar)
    _salesBars = _staffList.asMap().entries.map((entry) {
      final index = entry.key;
      final staff = entry.value;
      final sales = _salesPerformance[staff.id] ?? 0.0;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: sales,
            color: _getSalesColor(sales),
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }
  
  Color _getScoreColor(double score) {
    if (score >= 20) return Colors.green;
    if (score >= 10) return Colors.orange;
    if (score > 0) return Colors.blue;
    return Colors.grey;
  }
  
  Color _getSalesColor(double sales) {
    if (sales >= 5000) return Colors.green;
    if (sales >= 2000) return Colors.orange;
    if (sales > 0) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 400;
            
            return Text(
              'Performans Takibi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 20,
              ),
            );
          },
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Responsive action buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isSmallScreen = screenWidth < 400;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _showDateRangePicker,
                    icon: Icon(
                      Icons.date_range_rounded,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    tooltip: 'Tarih Filtrele',
                  ),
                  IconButton(
                    onPressed: _loadPerformanceData,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    tooltip: 'Yenile',
                  ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Görev Puanı'),
            Tab(text: 'Satış Performansı'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskScoresTab(),
                _buildSalesPerformanceTab(),
              ],
            ),
    );
  }

  Widget _buildTaskScoresTab() {

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          
          const SizedBox(height: 20),
          
          // Personel Görev Puanları Bar Chart
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personel Görev Puanları (${_startDate.day}/${_startDate.month} - ${_endDate.day}/${_endDate.month})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < _staffList.length) {
                                return Text(
                                  _staffList[value.toInt()].name,
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _taskScoreBars,
                      maxY: _taskScores.values.isNotEmpty ? _taskScores.values.reduce((a, b) => a > b ? a : b) + 5 : 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Puan Sıralaması
          Expanded(
            child: ListView.builder(
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                // Puanı olan personelleri önce göster
                final sortedStaff = _staffList.where((s) => (_taskScores[s.id] ?? 0.0) > 0).toList()
                  ..addAll(_staffList.where((s) => (_taskScores[s.id] ?? 0.0) == 0.0).toList());
                
                final actualStaff = sortedStaff[index];
                final actualScore = _taskScores[actualStaff.id] ?? 0.0;
                
                return _buildScoreCard(
                  rank: index + 1,
                  staff: actualStaff,
                  score: actualScore,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesPerformanceTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // Personel Satış Bar Chart
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personel Satış Performansı (${_startDate.day}/${_startDate.month} - ${_endDate.day}/${_endDate.month})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}₺',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < _staffList.length) {
                                return Text(
                                  _staffList[value.toInt()].name,
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _salesBars,
                      maxY: _salesPerformance.values.isNotEmpty ? _salesPerformance.values.reduce((a, b) => a > b ? a : b) + 1000 : 1000,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Satış Sıralaması
          Expanded(
            child: ListView.builder(
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                // Satışı olan personelleri önce göster
                final sortedStaff = _staffList.where((s) => (_salesPerformance[s.id] ?? 0.0) > 0).toList()
                  ..addAll(_staffList.where((s) => (_salesPerformance[s.id] ?? 0.0) == 0.0).toList());
                
                final actualStaff = sortedStaff[index];
                final actualSales = _salesPerformance[actualStaff.id] ?? 0.0;
                
                return _buildSalesCard(
                  rank: index + 1,
                  staff: actualStaff,
                  sales: actualSales,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard({
    required int rank,
    required Staff staff,
    required double score,
  }) {
    Color rankColor;
    IconData rankIcon;
    
    if (score == 0.0) {
      // Puanı olmayan personeller için
      rankColor = Colors.grey.shade300;
      rankIcon = Icons.person_rounded;
    } else {
      // Puanı olan personeller için sıralama
      switch (rank) {
        case 1:
          rankColor = Colors.amber;
          rankIcon = Icons.emoji_events_rounded;
          break;
        case 2:
          rankColor = Colors.grey.shade400;
          rankIcon = Icons.workspace_premium_rounded;
          break;
        case 3:
          rankColor = Colors.brown.shade400;
          rankIcon = Icons.military_tech_rounded;
          break;
        default:
          rankColor = Colors.blue.shade400;
          rankIcon = Icons.star_rounded;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Sıralama
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: rankColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                rankIcon,
                color: Colors.white,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Personel Bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    staff.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Puan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: score > 0 ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                score > 0 ? '${score.toStringAsFixed(1)} puan' : 'Henüz puan yok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: score > 0 ? Colors.blue.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard({
    required int rank,
    required Staff staff,
    required double sales,
  }) {
    Color rankColor;
    IconData rankIcon;
    
    if (sales == 0.0) {
      // Satışı olmayan personeller için
      rankColor = Colors.grey.shade300;
      rankIcon = Icons.person_rounded;
    } else {
      // Satışı olan personeller için sıralama
      switch (rank) {
        case 1:
          rankColor = Colors.amber;
          rankIcon = Icons.emoji_events_rounded;
          break;
        case 2:
          rankColor = Colors.grey.shade400;
          rankIcon = Icons.workspace_premium_rounded;
          break;
        case 3:
          rankColor = Colors.brown.shade400;
          rankIcon = Icons.military_tech_rounded;
          break;
        default:
          rankColor = Colors.green.shade400;
          rankIcon = Icons.trending_up_rounded;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Sıralama
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: rankColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                rankIcon,
                color: Colors.white,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Personel Bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    staff.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Satış Tutarı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sales > 0 ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                sales > 0 ? '${sales.toStringAsFixed(0)} ₺' : 'Henüz satış yok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: sales > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
