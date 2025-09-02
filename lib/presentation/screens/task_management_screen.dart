import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../widgets/task_card.dart';
import '../widgets/create_task_dialog.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // TODO: Dependency injection ile TaskRepository alınmalı
  // late TaskRepository _taskRepository;
  List<Task> _pendingTasks = [];
  List<Task> _completedTasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // TODO: Dependency injection ile TaskRepository alınmalı
    // _taskRepository = context.read<TaskRepository>();
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: TaskRepository implement edildikten sonra gerçek veriler kullanılacak
      // final pendingTasks = await _taskRepository.getPendingTasks();
      // final completedTasks = await _taskRepository.getCompletedTasks();
      
      // Geçici mock data
      await Future.delayed(const Duration(milliseconds: 500));
      final pendingTasks = _getMockPendingTasks();
      final completedTasks = _getMockCompletedTasks();

      setState(() {
        _pendingTasks = pendingTasks;
        _completedTasks = completedTasks;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görevler yüklenirken hata: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Task> _getMockPendingTasks() {
    return [
      Task.create(
        title: 'Oyun Alanı Temizliği',
        description: 'Oyun alanındaki tüm oyuncakları topla ve yerleri temizle',
        difficulty: TaskDifficulty.medium,
      ).copyWith(
        id: '1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Task.create(
        title: 'Güvenlik Kontrolü',
        description: 'Tüm güvenlik ekipmanlarını kontrol et ve eksik olanları raporla',
        difficulty: TaskDifficulty.hard,
      ).copyWith(
        id: '2',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }

  List<Task> _getMockCompletedTasks() {
    return [
      Task.create(
        title: 'Giriş Temizliği',
        description: 'Giriş alanını temizle ve dezenfekte et',
        difficulty: TaskDifficulty.easy,
      ).copyWith(
        id: '3',
        status: TaskStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
        completedByStaffIds: ['staff1', 'staff2'],
        completedImageUrl: 'https://example.com/cleaning.jpg',
      ),
    ];
  }

  Future<void> _createTask() async {
    await showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(
        onTaskCreated: (Task task) {
          setState(() {
            _pendingTasks.insert(0, task);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Görev başarıyla oluşturuldu')),
          );
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
                                // TODO: TaskRepository implement edildikten sonra gerçek veriler kullanılacak
                                // await _loadTasks();
                                
                                // Geçici olarak mock data'yı güncelle
                                setState(() {
                                  final completedTask = task.copyWith(
                                    status: TaskStatus.completed,
                                    completedAt: DateTime.now(),
                                    completedByStaffIds: ['current_staff'],
                                  );
                                  _pendingTasks.remove(task);
                                  _completedTasks.insert(0, completedTask);
                                });
                              },
                              onTaskDeleted: () {
                                setState(() {
                                  _pendingTasks.remove(task);
                                });
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Görev silindi')),
                                );
                              },
                            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedTasksTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_completedTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz tamamlanan görev yok',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _completedTasks.length,
        itemBuilder: (context, index) {
          final task = _completedTasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TaskCard(
              task: task,
              onTaskCompleted: () async {
                // TODO: TaskRepository implement edildikten sonra gerçek veriler kullanılacak
                // await _loadTasks();
                
                // Tamamlanan görevler için herhangi bir işlem yapmaya gerek yok
              },
            ),
          );
        },
      ),
    );
  }
}
