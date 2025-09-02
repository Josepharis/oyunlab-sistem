import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/admin_auth_service.dart';
import '../../data/models/task_model.dart';
import '../../data/models/staff_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/staff_repository.dart';

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
  String _selectedPeriod = 'Son 30 Gün';
  
  // Grafik verileri
  List<FlSpot> _taskScoreTrend = [];
  List<FlSpot> _salesTrend = [];

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
      _calculateSalesPerformance();
      
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
    // TODO: TaskRepository'den tamamlanan görevleri al
    // Şimdilik mock data kullanıyoruz
          _completedTasks = [
        Task(
          id: '1',
          title: 'Oyun alanı temizliği',
          description: 'Oyun alanının temizlenmesi',
          difficulty: TaskDifficulty.easy,
          status: TaskStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          completedAt: DateTime.now().subtract(const Duration(hours: 2)),
          assignedStaffIds: ['staff1', 'staff2'],
          completedByStaffIds: ['staff1', 'staff2'],
          complaints: [],
          isActive: true,
        ),
        Task(
          id: '2',
          title: 'Ekipman kontrolü',
          description: 'Tüm ekipmanların kontrol edilmesi',
          difficulty: TaskDifficulty.medium,
          status: TaskStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          completedAt: DateTime.now().subtract(const Duration(hours: 5)),
          assignedStaffIds: ['staff1'],
          completedByStaffIds: ['staff1'],
          complaints: [],
          isActive: true,
        ),
        Task(
          id: '3',
          title: 'Güvenlik kontrolü',
          description: 'Güvenlik sistemlerinin kontrol edilmesi',
          difficulty: TaskDifficulty.hard,
          status: TaskStatus.completed,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          completedAt: DateTime.now().subtract(const Duration(hours: 1)),
          assignedStaffIds: ['staff2', 'staff3', 'staff4'],
          completedByStaffIds: ['staff2', 'staff3', 'staff4'],
          complaints: [],
          isActive: true,
        ),
      ];
  }

  Future<void> _loadStaffList() async {
    // TODO: StaffRepository'den personel listesini al
    // Şimdilik mock data kullanıyoruz
          _staffList = [
        Staff(
          id: 'staff1', 
          name: 'Ahmet Yılmaz', 
          email: 'ahmet@oyunlab.com',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Staff(
          id: 'staff2', 
          name: 'Fatma Demir', 
          email: 'fatma@oyunlab.com',
          createdAt: DateTime.now().subtract(const Duration(days: 25)),
        ),
        Staff(
          id: 'staff3', 
          name: 'Mehmet Kaya', 
          email: 'mehmet@oyunlab.com',
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
        ),
        Staff(
          id: 'staff4', 
          name: 'Ayşe Özkan', 
          email: 'ayse@oyunlab.com',
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];
  }

  void _calculateTaskScores() {
    _taskScores.clear();
    
    for (final task in _completedTasks) {
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
      
      // Kişi sayısına böl
      final personCount = task.assignedStaffIds.length;
      final scorePerPerson = baseScore / personCount;
      
      // Her kişiye puan ekle
      for (final staffId in task.assignedStaffIds) {
        _taskScores[staffId] = (_taskScores[staffId] ?? 0.0) + scorePerPerson;
      }
    }
  }

  void _calculateSalesPerformance() {
    _salesPerformance.clear();
    
    // TODO: Gerçek satış verilerinden hesapla
    // Şimdilik mock data kullanıyoruz
    _salesPerformance = {
      'staff1': 1250.0,
      'staff2': 980.0,
      'staff3': 2100.0,
      'staff4': 750.0,
    };
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
      _selectedPeriod = 'Son $days Gün';
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
        _selectedPeriod = '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';
      });
      _loadPerformanceData();
    }
    Navigator.pop(context);
  }

  void _generateChartData() {
    // Görev puanı trend grafiği (son 7 gün)
    _taskScoreTrend = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final dayScore = _taskScores.values.fold(0.0, (sum, score) => sum + score) / 7;
      return FlSpot(index.toDouble(), dayScore);
    });

    // Satış trend grafiği (son 7 gün)
    _salesTrend = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final daySales = _salesPerformance.values.fold(0.0, (sum, sales) => sum + sales) / 7;
      return FlSpot(index.toDouble(), daySales);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Performans Takibi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showDateRangePicker,
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Tarih Filtrele',
          ),
          IconButton(
            onPressed: _loadPerformanceData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
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
    // Puanlara göre sırala
    final sortedScores = _taskScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          
          const SizedBox(height: 20),
          
          // Trend Grafiği
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
                  'Görev Puanı Trendi (Son 7 Gün)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
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
                              const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                              return Text(
                                days[value.toInt()],
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _taskScoreTrend,
                          isCurved: true,
                          color: Colors.blue.shade400,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.shade100.withOpacity(0.3),
                          ),
                        ),
                      ],
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
              itemCount: sortedScores.length,
              itemBuilder: (context, index) {
                final entry = sortedScores[index];
                final staff = _staffList.firstWhere(
                  (s) => s.id == entry.key,
                  orElse: () => Staff(
                    id: '', 
                    name: 'Bilinmeyen', 
                    email: '',
                    createdAt: DateTime.now(),
                  ),
                );
                
                return _buildScoreCard(
                  rank: index + 1,
                  staff: staff,
                  score: entry.value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesPerformanceTab() {
    // Satış performansına göre sırala
    final sortedSales = _salesPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          
          const SizedBox(height: 20),
          
          // Trend Grafiği
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
                  'Satış Trendi (Son 7 Gün)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
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
                              const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                              return Text(
                                days[value.toInt()],
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _salesTrend,
                          isCurved: true,
                          color: Colors.green.shade400,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.green.shade100.withOpacity(0.3),
                          ),
                        ),
                      ],
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
              itemCount: sortedSales.length,
              itemBuilder: (context, index) {
                final entry = sortedSales[index];
                final staff = _staffList.firstWhere(
                  (s) => s.id == entry.key,
                  orElse: () => Staff(
                    id: '', 
                    name: 'Bilinmeyen', 
                    email: '',
                    createdAt: DateTime.now(),
                  ),
                );
                
                return _buildSalesCard(
                  rank: index + 1,
                  staff: staff,
                  sales: entry.value,
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
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${score.toStringAsFixed(1)} puan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
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
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${sales.toStringAsFixed(0)} ₺',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
