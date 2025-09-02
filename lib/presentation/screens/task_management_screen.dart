import 'package:flutter/material.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../core/di/service_locator.dart';
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
  late TaskRepository _taskRepository;
  List<Task> _pendingTasks = [];
  List<Task> _completedTasks = [];
  bool _isLoading = false;

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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    // Widget mounted değilse işlemi durdur
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Gerçek verileri TaskRepository'den al
      final pendingTasks = await _taskRepository.getPendingTasks();
      final completedTasks = await _taskRepository.getCompletedTasks();

      // Widget hala mounted mı kontrol et
      if (!mounted) return;

      setState(() {
        _pendingTasks = pendingTasks;
        _completedTasks = completedTasks;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görevler yüklenirken hata: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Görev başarıyla oluşturuldu')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Görev oluşturulurken hata: $e')),
            );
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
                                  // Görevi veritabanında tamamla
                                  await _taskRepository.completeTask(
                                    task.id,
                                    ['current_staff'], // TODO: Gerçek staff ID'si kullanılacak
                                    null, // completedImageUrl
                                  );
                                  
                                  // Widget hala mounted mı kontrol et
                                  if (!mounted) return;
                                  
                                  // Verileri yeniden yükle (Firebase'den güncel verileri al)
                                  await _loadTasks();
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Görev tamamlandı')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Görev tamamlanırken hata: $e')),
                                  );
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
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Görev silindi')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Görev silinirken hata: $e')),
                                  );
                                }
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
