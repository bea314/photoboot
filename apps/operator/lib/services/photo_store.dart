import 'package:fotoboot_operator/models/local_photo.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PhotoStore {
  static const _photosName = 'photos';
  static const _settingsName = 'photo_settings';

  late Box _photos;
  late Box _settings;

  Future<void> init() async {
    _photos = Hive.isBoxOpen(_photosName)
        ? Hive.box(_photosName)
        : await Hive.openBox(_photosName);
    _settings = Hive.isBoxOpen(_settingsName)
        ? Hive.box(_settingsName)
        : await Hive.openBox(_settingsName);
  }

  String? get lastEventId => _settings.get('lastEventId') as String?;

  Future<void> setLastEventId(String eventId) {
    return _settings.put('lastEventId', eventId);
  }

  List<LocalPhoto> listForEvent(String eventId) {
    return _photos.values
        .map((raw) => LocalPhoto.fromMap(Map<String, dynamic>.from(raw as Map)))
        .where((photo) => photo.eventId == eventId)
        .toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  LocalPhoto? getById(String clientPhotoId) {
    final raw = _photos.get(clientPhotoId);
    if (raw == null) return null;
    return LocalPhoto.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> upsert(LocalPhoto photo) {
    return _photos.put(photo.clientPhotoId, photo.toMap());
  }

  Future<void> delete(String clientPhotoId) {
    return _photos.delete(clientPhotoId);
  }
}
