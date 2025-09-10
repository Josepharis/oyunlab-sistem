import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../core/di/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskComplaintDialog extends StatefulWidget {
  final Task task;

  const TaskComplaintDialog({
    super.key,
    required this.task,
  });

  @override
  State<TaskComplaintDialog> createState() => _TaskComplaintDialogState();
}

class _TaskComplaintDialogState extends State<TaskComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isAnonymous = true;
  bool _isLoading = false;
  late TaskRepository _taskRepository;

  @override
  void initState() {
    super.initState();
    _taskRepository = ServiceLocator.locator<TaskRepository>();
  }

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilirken hata: $e')),
        );
      }
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen fotoğraf ekleyin')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Fotoğrafı yükle
      final imageUrl = await _taskRepository.uploadTaskImage(_selectedImage!, widget.task.id);
      
      // Kullanıcı bilgilerini al
      final currentUser = FirebaseAuth.instance.currentUser;
      String? reporterName;
      
      if (!_isAnonymous && currentUser != null) {
        // Kullanıcı adını al (burada admin repository'den alabilirsiniz)
        reporterName = currentUser.displayName ?? 'Bilinmeyen Kullanıcı';
      }

      // Şikayeti oluştur
      final complaint = TaskComplaint.create(
        complaintText: _complaintController.text.trim(),
        complaintImageUrl: imageUrl,
        isAnonymous: _isAnonymous,
        reporterName: reporterName,
      );

      // Şikayeti kaydet
      await _taskRepository.addComplaint(widget.task.id, complaint);

      if (mounted) {
        Navigator.of(context).pop(true); // Başarılı olduğunu belirt
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikayetiniz başarıyla gönderildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şikayet gönderilirken hata: $e')),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şikayet Et'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Görev: ${widget.task.title}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              // Anonim seçenekleri
              Text(
                'Kimlik Bilgileri:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              RadioListTile<bool>(
                title: const Text('Anonim'),
                value: true,
                groupValue: _isAnonymous,
                onChanged: (value) {
                  setState(() {
                    _isAnonymous = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                title: const Text('Bilgilerim gözüksün'),
                value: false,
                groupValue: _isAnonymous,
                onChanged: (value) {
                  setState(() {
                    _isAnonymous = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              
              // Açıklama
              Text(
                'Şikayet Açıklaması:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _complaintController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Şikayetinizi detaylı bir şekilde açıklayın...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen şikayet açıklaması girin';
                  }
                  if (value.trim().length < 20) {
                    return 'Şikayet açıklaması en az 20 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Fotoğraf seçimi
              Text(
                'Fotoğraf (Zorunlu):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedImage == null ? Colors.red : Colors.green,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fotoğraf eklemek için tıklayın',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '(Zorunlu)',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Fotoğrafı Kaldır'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitComplaint,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gönder'),
        ),
      ],
    );
  }
}

