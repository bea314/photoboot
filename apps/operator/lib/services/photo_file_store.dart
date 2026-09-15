import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

class PhotoFileStore {
  Box<dynamic>? _box;

  Future<void> init() async {
    _box = Hive.isBoxOpen('photo_files')
        ? Hive.box('photo_files')
        : await Hive.openBox('photo_files');
  }

  Future<void> writeOriginal(String clientPhotoId, Uint8List bytes) {
    return _write(_originalKey(clientPhotoId), bytes);
  }

  Future<void> writeThumb(String clientPhotoId, Uint8List bytes) {
    return _write(_thumbKey(clientPhotoId), bytes);
  }

  Future<Uint8List?> readOriginal(String clientPhotoId) {
    return _read(_originalKey(clientPhotoId));
  }

  Future<Uint8List?> readThumb(String clientPhotoId) {
    return _read(_thumbKey(clientPhotoId));
  }

  Future<Uint8List?> readBest(String clientPhotoId) async {
    return await readThumb(clientPhotoId) ?? await readOriginal(clientPhotoId);
  }

  Future<void> delete(String clientPhotoId) async {
    await _delete(_originalKey(clientPhotoId));
    await _delete(_thumbKey(clientPhotoId));
  }

  String _originalKey(String id) => '$id.original.jpg';
  String _thumbKey(String id) => '$id.thumb.jpg';

  Future<void> _write(String key, Uint8List bytes) {
    return _box!.put(key, bytes);
  }

  Future<Uint8List?> _read(String key) async {
    final raw = _box!.get(key);
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  Future<void> _delete(String key) {
    return _box!.delete(key);
  }
}
