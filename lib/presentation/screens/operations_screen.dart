import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/models/customer_model.dart';
import '../../data/services/admin_auth_service.dart';
import 'task_management_screen.dart';
import 'issues_tab.dart';
import 'performance_screen.dart';

class OperationsScreen extends StatefulWidget {
  final CustomerRepository customerRepository;
  final MenuRepository menuRepository;

  const OperationsScreen({
    Key? key,
    required this.customerRepository,
    required this.menuRepository,
  }) : super(key: key);

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<Customer> _todayCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTodayData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Bugünün müşterilerini al
      final allCustomers = widget.customerRepository.customers;
      final todayStart = DateTime.now().subtract(const Duration(days: 1));
      
      _todayCustomers = allCustomers
          .where((customer) => customer.entryTime.isAfter(todayStart))
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('İşleyiş verileri yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'İşleyiş',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Admin için performans butonu, normal kullanıcılar için yenile butonu
          Consumer<AdminAuthService>(
            builder: (context, authService, child) {
              if (authService.isAdmin) {
                return IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PerformanceScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_rounded, color: Colors.white),
                  tooltip: 'Performans',
                );
              } else {
                return IconButton(
                  onPressed: _loadTodayData,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Yenile',
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Görevler'),
            Tab(text: 'Eksikler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildIssuesTab(),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return const TaskManagementScreen();
  }

  Widget _buildIssuesTab() {
    return const IssuesTab();
  }
}
