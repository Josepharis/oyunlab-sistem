# Görev Sistemi (Task Management System)

Bu dokümantasyon, OyunLab uygulamasındaki görev yönetimi sistemini açıklamaktadır.

## Genel Bakış

Görev sistemi, işletme personelinin günlük görevlerini yönetmek, takip etmek ve tamamlamak için tasarlanmıştır. Sistem **İşleyiş ekranının "Görevler" sekmesinde** yer alır ve iki ana alt sekmeden oluşur:

1. **Bekleyen Görevler** - Henüz tamamlanmamış görevler
2. **Tamamlanan Görevler** - Tamamlanmış görevler

## Özellikler

### Görev Oluşturma
- Görev adı (zorunlu)
- Görev açıklaması (zorunlu)
- Zorluk seviyesi (Kolay/Orta/Zor)
- Otomatik oluşturulma tarihi

### Görev Tamamlama
- Görsel yükleme (zorunlu)
- **Mevcut kullanıcı otomatik olarak eklenir**
- **Birlikte çalışan personeller sistemde kayıtlı personellerden seçilir**
- Otomatik tamamlanma tarihi
- Durum güncelleme

### Şikayet Sistemi
- Anonim şikayet bildirimi
- Şikayet detayı (minimum 20 karakter)
- Şikayet tarihi

## Teknik Detaylar

### Model Yapısı

#### Task Model
```dart
class Task {
  final String id;
  final String title;
  final String description;
  final TaskDifficulty difficulty;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> assignedStaffIds;
  final List<String> completedByStaffIds;
  final String? completedImageUrl;
  final List<TaskComplaint> complaints;
  final bool isActive;
}
```

#### TaskComplaint Model
```dart
class TaskComplaint {
  final String id;
  final String complaintText;
  final DateTime createdAt;
  final bool isAnonymous;
}
```

### Enum'lar

#### TaskDifficulty
- `easy` - Kolay
- `medium` - Orta  
- `hard` - Zor

#### TaskStatus
- `pending` - Bekliyor
- `inProgress` - Devam Ediyor
- `completed` - Tamamlandı

### Repository Pattern

`TaskRepository` sınıfı, görev verilerini yönetmek için aşağıdaki metodları sağlar:

- `getPendingTasks()` - Bekleyen görevleri getir
- `getCompletedTasks()` - Tamamlanan görevleri getir
- `createTask(Task task)` - Yeni görev oluştur
- `updateTask(Task task)` - Görevi güncelle
- `completeTask(...)` - Görevi tamamla
- `addComplaint(...)` - Şikayet ekle
- `deleteTask(String taskId)` - Görevi sil
- `deactivateTask(String taskId)` - Görevi devre dışı bırak

### Firebase Entegrasyonu

Görev verileri Firestore'da `tasks` koleksiyonunda saklanır. Her görev dökümanı şu alanları içerir:

- `id` - Benzersiz görev ID'si
- `title` - Görev başlığı
- `description` - Görev açıklaması
- `difficulty` - Zorluk seviyesi
- `status` - Görev durumu
- `createdAt` - Oluşturulma tarihi
- `completedAt` - Tamamlanma tarihi (opsiyonel)
- `assignedStaffIds` - Atanan personel ID'leri
- `completedByStaffIds` - Tamamlayan personel ID'leri
- `completedImageUrl` - Tamamlanma görseli URL'i (opsiyonel)
- `complaints` - Şikayet listesi
- `isActive` - Görev aktif mi?

## Kullanım

### Görev Oluşturma
1. İşleyiş ekranında "Görevler" sekmesine git
2. Sağ alt köşedeki + butonuna tıkla
3. Görev adı, açıklaması ve zorluk seviyesini gir
4. "Oluştur" butonuna tıkla

### Görev Tamamlama
1. Bekleyen görevler sekmesinde "Görevi Tamamla" butonuna tıkla
2. **Mevcut kullanıcı otomatik olarak seçilir**
3. **Birlikte çalışan personelleri checkbox'lardan seç**
4. Görsel seç (zorunlu)
5. "Tamamla" butonuna tıkla

### Şikayet Bildirimi
1. Tamamlanan görevler sekmesinde "Şikayet Et" butonuna tıkla
2. Şikayet detayını gir (minimum 20 karakter)
3. Anonim gönderim seçeneğini belirle
4. "Şikayet Gönder" butonuna tıkla

## Ekran Görüntüleri

### Ana Ekran
- **İşleyiş ekranında "Görevler" sekmesi**
- Alt tab yapısı ile bekleyen ve tamamlanan görevler
- Her görev için detaylı bilgi kartı
- Zorluk seviyesi ve durum etiketleri
- Görsel önizleme (tamamlanan görevler için)

### Görev Kartı
- Görev başlığı ve açıklaması
- Zorluk seviyesi (renkli etiket)
- Durum bilgisi (renkli etiket)
- Oluşturulma ve tamamlanma tarihleri
- Tamamlayan personel bilgisi
- Tamamlanma görseli
- Aksiyon butonları

## Gelecek Geliştirmeler

- [ ] Firebase Storage entegrasyonu (görsel yükleme)
- [ ] Personel yönetimi sistemi
- [ ] Görev öncelik sistemi
- [ ] Görev şablonları
- [ ] Otomatik görev atama
- [ ] Görev raporlama ve analitik
- [ ] Push notification sistemi
- [ ] Görev takvimi entegrasyonu

## Notlar

- Şu anda sistem mock data ile çalışmaktadır
- Firebase entegrasyonu tamamlandıktan sonra gerçek veriler kullanılacak
- Görsel yükleme özelliği henüz implement edilmemiştir
- **Personel seçimi sistemde kayıtlı personellerden yapılmaktadır**
- **Mevcut kullanıcı otomatik olarak görev tamamlayanlar listesine eklenir**

## Sorun Giderme

### Yaygın Hatalar
1. **Görev oluşturulamıyor**: Form validasyonunu kontrol edin
2. **Görev tamamlanamıyor**: Görsel seçildiğinden emin olun
3. **Şikayet gönderilemiyor**: Minimum 20 karakter gereklidir

### Log Mesajları
Sistem, tüm işlemleri konsola loglar. Hata ayıklama için bu logları takip edin:
- `TASK_REPO:` prefix'i ile başlayan mesajlar
- `FIREBASE_SERVICE:` prefix'i ile başlayan mesajlar
