import 'package:flutter/material.dart';
import '../../data/models/issue_model.dart';
import '../../data/repositories/issue_repository.dart';
import '../../core/di/service_locator.dart';
import '../widgets/issue_card.dart';
import '../widgets/create_issue_dialog.dart';

class IssuesTab extends StatefulWidget {
  const IssuesTab({super.key});

  @override
  State<IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<IssuesTab> {
  late IssueRepository _issueRepository;
  List<Issue> _issues = [];
  bool _isLoading = false;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _issueRepository = ServiceLocator.locator<IssueRepository>();
    
    // Widget'ın mounted olduğundan emin ol
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadIssues();
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
    super.dispose();
  }

  Future<void> _loadIssues() async {
    // Widget mounted değilse işlemi durdur
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Gerçek verileri IssueRepository'den al
      final issues = await _issueRepository.getUnresolvedIssues();

      // Widget hala mounted mı kontrol et
      if (!mounted) return;

      setState(() {
        _issues = issues;
      });
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('Eksikler yüklenirken hata: $e')),
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



  Future<void> _createIssue() async {
    await showDialog(
      context: context,
      builder: (context) => CreateIssueDialog(
        onIssueCreated: (Issue issue) async {
          try {
            // Eksik veritabanına kaydet
            await _issueRepository.createIssue(issue);
            
            // Widget hala mounted mı kontrol et
            if (!mounted) return;
            
            // Verileri yeniden yükle (Firebase'den güncel verileri al)
            await _loadIssues();
            
            if (mounted) {
              _scaffoldMessenger?.showSnackBar(
                const SnackBar(content: Text('Eksik başarıyla eklendi')),
              );
            }
          } catch (e) {
            if (!mounted) return;
            if (mounted) {
              _scaffoldMessenger?.showSnackBar(
                SnackBar(content: Text('Eksik eklenirken hata: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _resolveIssue(Issue issue) async {
    try {
      // Eksik veritabanında çöz
      await _issueRepository.resolveIssue(issue.id, 'current_user_id'); // TODO: Gerçek user ID kullanılacak
      
      // Widget hala mounted mı kontrol et
      if (!mounted) return;
      
      // Verileri yeniden yükle (Firebase'den güncel verileri al)
      await _loadIssues();
      
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text('Eksik çözüldü olarak işaretlendi')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('Eksik çözülürken hata: $e')),
        );
      }
    }
  }

  void _deleteIssue(Issue issue) async {
    try {
      // Eksik veritabanından sil
      await _issueRepository.deleteIssue(issue.id);
      
      // Widget hala mounted mı kontrol et
      if (!mounted) return;
      
      // Verileri yeniden yükle (Firebase'den güncel verileri al)
      await _loadIssues();
      
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text('Eksik silindi')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text('Eksik silinirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Eksikler ve Sorunlar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _createIssue,
                  icon: const Icon(Icons.add),
                  label: const Text('Eksik Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _issues.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Henüz eksik yok',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Yeni eksik eklemek için + butonuna tıklayın',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadIssues,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _issues.length,
                          itemBuilder: (context, index) {
                            final issue = _issues[index];
                            return IssueCard(
                              issue: issue,
                              onIssueResolved: () => _resolveIssue(issue),
                              onIssueDeleted: () => _deleteIssue(issue),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
