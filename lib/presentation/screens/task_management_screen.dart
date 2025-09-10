import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_completion_history_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../core/di/service_locator.dart';
import '../widgets/task_card.dart';
import '../widgets/completed_task_history_card.dart';
import '../widgets/create_task_dialog.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TaskRepository _taskRepository;
  List<Task> _pendingTasks = [];
  List<TaskCompletionHistory> _completedTasksHistory = [];
  bool _isLoading = false;
  ScaffoldMessengerState? _scaffoldMessenger;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _taskRepository = ServiceLocator.locator<TaskRepository>();
    
    // Widget'ın mounted olduğundan emin ol
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTasks();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }



  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Sadece gün değiştiğinde görevleri sıfırla
  Future<void> _checkAndResetTasksIfNeeded() async {
    try {
      final today = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastResetDateString = prefs.getString('last_task_reset_date');
      
      DateTime? lastResetDate;
      if (lastResetDateString != null) {
        lastResetDate = DateTime.parse(lastResetDateString);
      }
      
      // Eğer son sıfırlama bugün değilse sıfırla
      if (lastResetDate == null || 
          lastResetDate.year != today.year ||
          lastResetDate.month != today.month ||
          lastResetDate.day != today.day) {
        
        print('TASK_MANAGEMENT: Gün değişti, görevler sıfırlanıyor...');
        await _taskRepository.resetAllTasks();
        await prefs.setString('last_task_reset_date', today.toIso8601String());
        print('TASK_MANAGEMENT: Görevler sıfırlandı');
      } else {
        print('TASK_MANAGEMENT: Görevler bugün zaten sıfırlanmış');
      }
    } catch (e) {
      print('TASK_MANAGEMENT: Görev sıfırlama kontrolü sırasında hata: $e');
    }
  }

  Future<void> _loadTasks() async {
    // Widget mounted değilse işlemi durdur
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Sadece gün değiştiğinde görevleri sıfırla
      await _checkAndResetTasksIfNeeded();
      
      // Gerçek verileri TaskRepository'den al
      final pendingTasks = await _taskRepository.getPendingTasks();
      
      // Tamamlanan görevleri geçmiş kayıtlarından al
      final completedTasksHistory = await _taskRepository.getTaskCompletionHistoryForDate(_selectedDate);

      // Widget hala mounted mı kontrol et
      if (!mounted) return;

      setState(() {
        _pendingTasks = pendingTasks;
        _completedTasksHistory = completedTasksHistory;
      });
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('Görevler yüklenirken hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  // Tarih seçici
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Tarih değiştiğinde görevleri yeniden yükle
      await _loadTasks();
    }
  }

  // Tarih formatı
  String _formatDate(DateTime date) {
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _createTask() async {
    await showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(
        onTaskCreated: (Task task) async {
          try {
            // Görevi veritabanına kaydet
            await _taskRepository.createTask(task);
            
            // Widget hala mounted mı kontrol et
            if (!mounted) return;
            
            // Verileri yeniden yükle (Firebase'den güncel verileri al)
            await _loadTasks();
            
            if (mounted) {
              _scaffoldMessenger?.showSnackBar(
                const SnackBar(content: Text('Görev başarıyla oluşturuldu')),
              );
            }
          } catch (e) {
            if (!mounted) return;
            if (mounted) {
              _scaffoldMessenger?.showSnackBar(
                SnackBar(content: Text('Görev oluşturulurken hata: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Bekleyen Görevler'),
                Tab(text: 'Tamamlanan Görevler'),
              ],
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTasksTab(),
                _buildCompletedTasksTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'task_management_fab',
        onPressed: _createTask,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPendingTasksTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz bekleyen görev yok',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Yeni görev oluşturmak için + butonuna tıklayın',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingTasks.length,
        itemBuilder: (context, index) {
          final task = _pendingTasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
                                        child: TaskCard(
                              task: task,
                              onTaskCompleted: () async {
                                try {
                                  // CompleteTaskDialog zaten completeTask çağırıyor, burada sadece UI'ı güncelle
                                  if (!mounted) return;
                                  
                                  // Bekleyen görevlerden tamamlanan görevi kaldır
                                  setState(() {
                                    _pendingTasks.removeWhere((t) => t.id == task.id);
                                  });
                                  
                                  // Tamamlanan görevleri yenile
                                  final completedTasksHistory = await _taskRepository.getTaskCompletionHistoryForDate(_selectedDate);
                                  
                                  if (mounted) {
                                    setState(() {
                                      _completedTasksHistory = completedTasksHistory;
                                    });
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  if (mounted) {
                                    _scaffoldMessenger?.showSnackBar(
                                      SnackBar(content: Text('Görev tamamlanırken hata: $e')),
                                    );
                                  }
                                }
                              },
                              onTaskDeleted: () async {
                                try {
                                  // Görevi veritabanından sil
                                  await _taskRepository.deleteTask(task.id);
                                  
                                  // Widget hala mounted mı kontrol et
                                  if (!mounted) return;
                                  
                                  // Verileri yeniden yükle (Firebase'den güncel verileri al)
                                  await _loadTasks();
                                  
                                  if (mounted) {
                                    _scaffoldMessenger?.showSnackBar(
                                      const SnackBar(content: Text('Görev silindi')),
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  if (mounted) {
                                    _scaffoldMessenger?.showSnackBar(
                                      SnackBar(content: Text('Görev silinirken hata: $e')),
                                    );
                                  }
                                }
                              },
                            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedTasksTab() {
    return Column(
      children: [
        // Tarih seçici header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tarih: ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bugün butonu
              TextButton(
                onPressed: () {
                  final today = DateTime.now();
                  if (_selectedDate.day != today.day ||
                      _selectedDate.month != today.month ||
                      _selectedDate.year != today.year) {
                    setState(() {
                      _selectedDate = today;
                    });
                    _loadTasks();
                  }
                },
                child: const Text(
                  'Bugün',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        // İçerik
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _completedTasksHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_formatDate(_selectedDate)} tarihinde\nhenüz tamamlanan görev yok',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Farklı bir tarih seçmeyi deneyin',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadTasks();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _completedTasksHistory.length,
                        itemBuilder: (context, index) {
                          final history = _completedTasksHistory[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CompletedTaskHistoryCard(history: history),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
