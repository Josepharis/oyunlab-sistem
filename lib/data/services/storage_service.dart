import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Görsel yükleme
  static Future<String> uploadImage({
    required File imageFile,
    required String folder,
    required String fileName,
  }) async {
    try {
      // Dosya uzantısını al
      final String fileExtension = path.extension(imageFile.path);
      final String fullFileName = '$fileName$fileExtension';
      
      // Storage referansı oluştur
      final Reference ref = _storage
          .ref()
          .child(folder)
          .child(fullFileName);

      // Dosyayı yükle
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      
      // Download URL'ini al
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Görsel yüklenirken hata oluştu: $e');
    }
  }

  // Görsel silme
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Görsel silinirken hata oluştu: $e');
    }
  }

  // Ürün görseli yükleme
  static Future<String> uploadProductImage({
    required File imageFile,
    required String productId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'products',
      fileName: productId,
    );
  }

  // Kategori klasörüne göre görsel yükleme
  static Future<String> uploadCategoryImage({
    required File imageFile,
    required String category,
    required String productId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'products/$category',
      fileName: productId,
    );
  }

  // Görsel boyutunu kontrol et
  static Future<bool> validateImageSize(File imageFile) async {
    try {
      final int fileSizeInBytes = await imageFile.length();
      const int maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      
      return fileSizeInBytes <= maxSizeInBytes;
    } catch (e) {
      return false;
    }
  }

  // Desteklenen görsel formatlarını kontrol et
  static bool isValidImageFormat(String filePath) {
    final String extension = path.extension(filePath).toLowerCase();
    const List<String> validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    
    return validExtensions.contains(extension);
  }
}
