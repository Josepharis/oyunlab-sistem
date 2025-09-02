import 'package:flutter/material.dart';

class ComplaintDialog extends StatefulWidget {
  final String taskId;

  const ComplaintDialog({
    super.key,
    required this.taskId,
  });

  @override
  State<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends State<ComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  bool _isAnonymous = true;
  bool _isLoading = false;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şikayet Bildir'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Görev hakkında şikayetinizi bildirin. Şikayetler anonim olarak kaydedilir.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _complaintController,
              decoration: const InputDecoration(
                labelText: 'Şikayet Detayı',
                border: OutlineInputBorder(),
                hintText: 'Şikayetinizi detaylı olarak açıklayın...',
                helperText: 'Görev neden doğru yapılmadı?',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Şikayet detayı gereklidir';
                }
                if (value.trim().length < 20) {
                  return 'Şikayet detayı en az 20 karakter olmalıdır';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value ?? true;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'Şikayeti anonim olarak gönder',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            if (!_isAnonymous) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anonim olmayan şikayetlerde kimlik bilgileriniz kaydedilecektir',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitComplaint,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Şikayet Gönder'),
        ),
      ],
    );
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: TaskRepository implement edildikten sonra gerçek veriler kullanılacak
      // final complaint = TaskComplaint.create(
      //   complaintText: _complaintController.text.trim(),
      //   isAnonymous: _isAnonymous,
      // );
      // final taskRepository = TaskRepository(FirebaseService());
      // await taskRepository.addComplaint(widget.taskId, complaint);

      // Geçici olarak başarı mesajı gösteriyoruz
      await Future.delayed(const Duration(seconds: 1));
      
      Navigator.of(context).pop();
      
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Şikayetiniz başarıyla gönderildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text('Şikayet gönderilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
