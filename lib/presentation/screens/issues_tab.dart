import 'package:flutter/material.dart';
import '../../data/models/issue_model.dart';
import '../widgets/issue_card.dart';
import '../widgets/create_issue_dialog.dart';

class IssuesTab extends StatefulWidget {
  const IssuesTab({super.key});

  @override
  State<IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<IssuesTab> {
  List<Issue> _issues = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: IssueRepository implement edildikten sonra gerçek veriler kullanılacak
      await Future.delayed(const Duration(milliseconds: 500));
      final issues = _getMockIssues();

      setState(() {
        _issues = issues;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  List<Issue> _getMockIssues() {
    return [
      Issue.create(
        title: 'Oyun alanı temizlik malzemesi',
        description: 'Oyun alanı temizliği için gerekli malzemeler eksik',
        category: IssueCategory.supplies,
        priority: IssuePriority.high,
        createdBy: 'Ahmet Yılmaz',
      ).copyWith(
        id: '1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Issue.create(
        title: 'Güvenlik ekipmanları kontrolü',
        description: 'Güvenlik ekipmanlarının kontrol edilmesi gerekiyor',
        category: IssueCategory.safety,
        priority: IssuePriority.medium,
        createdBy: 'Fatma Demir',
      ).copyWith(
        id: '2',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Issue.create(
        title: 'Bakım planı yapılmalı',
        description: 'Düzenli bakım planı oluşturulması gerekiyor',
        category: IssueCategory.maintenance,
        priority: IssuePriority.low,
        createdBy: 'Mehmet Kaya',
      ).copyWith(
        id: '3',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  Future<void> _createIssue() async {
    await showDialog(
      context: context,
      builder: (context) => CreateIssueDialog(
        onIssueCreated: (Issue issue) {
          setState(() {
            _issues.insert(0, issue);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eksik başarıyla eklendi')),
          );
        },
      ),
    );
  }

  void _resolveIssue(Issue issue) {
    setState(() {
      final resolvedIssue = issue.copyWith(
        isResolved: true,
        resolvedAt: DateTime.now(),
        resolvedBy: 'current_user_id',
      );
      
      _issues.remove(issue);
      // Çözülen eksikler listeden kaldırılıyor
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eksik çözüldü olarak işaretlendi')),
    );
  }

  void _deleteIssue(Issue issue) {
    setState(() {
      _issues.remove(issue);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eksik silindi')),
    );
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
