import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Local bytes for template backgrounds / logos (Hive, same pattern as photos).
class TemplateAssetStore {
  TemplateAssetStore({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const boxName = 'template_assets';

  final Uuid _uuid;
  Box<dynamic>? _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);
    _ready = true;
  }

  Future<String> putBytes(Uint8List bytes, {String? preferredKey}) async {
    await init();
    final key = preferredKey ?? _uuid.v4();
    await _box!.put(key, bytes);
    return key;
  }

  Future<Uint8List?> read(String key) async {
    await init();
    final raw = _box!.get(key);
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  Future<void> delete(String key) async {
    await init();
    await _box!.delete(key);
  }
}
