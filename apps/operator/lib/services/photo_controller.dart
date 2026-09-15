import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fotoboot_operator/models/local_photo.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/services/photo_file_store.dart';
import 'package:fotoboot_operator/services/photo_store.dart';
import 'package:uuid/uuid.dart';

class PhotoController extends ChangeNotifier {
  PhotoController({
    required ApiClient api,
    required AuthController auth,
    PhotoStore? store,
    PhotoFileStore? files,
  })  : _api = api,
        _auth = auth,
        _store = store ?? PhotoStore(),
        files = files ?? PhotoFileStore();

  final ApiClient _api;
  final AuthController _auth;
  final PhotoStore _store;
  final PhotoFileStore files;
  final _uuid = const Uuid();

  bool _started = false;
  bool _syncing = false;
  String? _eventId;
  String? _error;
  List<LocalPhoto> _photos = [];
  Timer? _timer;

  String? get eventId => _eventId;
  String? get error => _error;
  bool get started => _started;
  bool get syncing => _syncing;
  List<LocalPhoto> get photos => List.unmodifiable(_photos);
  ApiClient get api => _api;

  /// Local mark used after a successful booth print (API may also set printedAt).
  Future<void> markPrintedLocally(String clientPhotoId) async {
    final photo = _store.getById(clientPhotoId);
    if (photo == null || photo.printedAt != null) return;
    await _store.upsert(photo.copyWith(printedAt: DateTime.now()));
    _reloadLocal();
    notifyListeners();
  }

  Future<void> bind() async {
    _auth.addListener(_onAuthChanged);
    if (_auth.authenticated) {
      await start();
    }
  }

  void _onAuthChanged() {
    if (_auth.authenticated && !_started) {
      unawaited(start());
    } else if (!_auth.authenticated && _started) {
      unawaited(stop());
    }
  }

  Future<void> start() async {
    await _store.init();
    await files.init();
    _started = true;
    _eventId = _store.lastEventId;
    if (_eventId != null) {
      _reloadLocal();
    }

    await refreshEvent();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(syncNow());
    });
    await syncNow();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _eventId = null;
    _photos = [];
    _error = null;
    notifyListeners();
  }

  Future<void> refreshEvent() async {
    try {
      final event = await _api.getCurrentEvent();
      _eventId = event.id;
      await _store.setLastEventId(event.id);
      _error = null;
      _reloadLocal();
      notifyListeners();
    } on ApiException catch (e) {
      if (_eventId == null) {
        _error = e.message;
        notifyListeners();
      }
    } catch (_) {
      if (_eventId == null) {
        _error = 'No se pudo cargar el evento';
        notifyListeners();
      }
    }
  }

  LocalPhoto? byId(String clientPhotoId) {
    try {
      return _photos.firstWhere((photo) => photo.clientPhotoId == clientPhotoId);
    } catch (_) {
      return _store.getById(clientPhotoId);
    }
  }

  Future<LocalPhoto> ingestCapture({
    required Uint8List bytes,
    DateTime? takenAt,
  }) async {
    if (_eventId == null) {
      await refreshEvent();
    }
    final eventId = _eventId;
    if (eventId == null) {
      throw ApiException('No hay evento activo para guardar la foto');
    }

    final now = takenAt ?? DateTime.now();
    final photo = LocalPhoto(
      clientPhotoId: _uuid.v4(),
      eventId: eventId,
      takenAt: now,
      createdAt: DateTime.now(),
      syncStatus: PhotoSyncStatus.pendingUpload,
    );

    await files.writeOriginal(photo.clientPhotoId, bytes);
    await _store.upsert(photo);
    _reloadLocal();
    notifyListeners();
    unawaited(syncNow());
    return photo;
  }

  Future<void> deleteOne(String clientPhotoId) async {
    final photo = byId(clientPhotoId);
    if (photo == null) return;

    if (photo.serverId == null) {
      await files.delete(clientPhotoId);
      await _store.delete(clientPhotoId);
      _reloadLocal();
      notifyListeners();
      return;
    }

    final marked = photo.copyWith(syncStatus: PhotoSyncStatus.pendingDelete);
    await _store.upsert(marked);
    _reloadLocal();
    notifyListeners();
    await syncNow();
  }

  Future<void> deleteMany(Iterable<String> ids) async {
    for (final id in ids) {
      await deleteOne(id);
    }
  }

  Future<void> syncNow() async {
    if (!_started || _syncing) return;
    if (_eventId == null) {
      await refreshEvent();
      if (_eventId == null) return;
    }

    _syncing = true;
    notifyListeners();
    try {
      await _flushDeletes();
      await _flushUploads();
      await _reconcile();
    } finally {
      _syncing = false;
      _reloadLocal();
      notifyListeners();
    }
  }

  Future<void> _flushDeletes() async {
    final pending = _store
        .listForEvent(_eventId!)
        .where((photo) => photo.isPendingDelete && photo.serverId != null);
    for (final photo in pending) {
      try {
        await _api.deletePhoto(photo.serverId!);
        await files.delete(photo.clientPhotoId);
        await _store.delete(photo.clientPhotoId);
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          await files.delete(photo.clientPhotoId);
          await _store.delete(photo.clientPhotoId);
        }
      } catch (_) {
        // Stay pending_delete and retry later.
      }
    }
  }

  Future<void> _flushUploads() async {
    final pending = _store
        .listForEvent(_eventId!)
        .where((photo) => photo.canUpload);
    for (final photo in pending) {
      final bytes = await files.readOriginal(photo.clientPhotoId);
      if (bytes == null) {
        await _store.upsert(
          photo.copyWith(
            syncStatus: PhotoSyncStatus.error,
            errorMessage: 'Archivo local no encontrado',
          ),
        );
        continue;
      }

      try {
        final remote = await _api.uploadPhoto(
          eventId: photo.eventId,
          clientPhotoId: photo.clientPhotoId,
          takenAt: photo.takenAt,
          bytes: bytes,
        );
        await _store.upsert(
          photo.copyWith(
            serverId: remote.id,
            syncStatus: PhotoSyncStatus.synced,
            thumbUrl: remote.thumbUrl,
            originalUrl: remote.originalUrl,
            printedAt: remote.printedAt,
            clearError: true,
          ),
        );
      } on ApiException catch (e) {
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          await _store.upsert(
            photo.copyWith(
              syncStatus: PhotoSyncStatus.error,
              errorMessage: e.message,
            ),
          );
        }
      } catch (_) {
        // Keep pending_upload for network issues.
      }
    }
  }

  Future<void> _reconcile() async {
    List<RemotePhoto> remote;
    try {
      remote = await _api.listPhotos(_eventId!);
    } catch (_) {
      return;
    }

    final remoteByClient = {
      for (final photo in remote) photo.clientPhotoId: photo,
    };
    final local = _store.listForEvent(_eventId!);
    final localIds = {for (final photo in local) photo.clientPhotoId};

    for (final photo in local) {
      if (photo.isPendingDelete) continue;
      final match = remoteByClient[photo.clientPhotoId];
      if (match == null && photo.syncStatus == PhotoSyncStatus.synced) {
        await files.delete(photo.clientPhotoId);
        await _store.delete(photo.clientPhotoId);
        continue;
      }
      if (match != null && photo.syncStatus != PhotoSyncStatus.synced) {
        await _store.upsert(
          photo.copyWith(
            serverId: match.id,
            syncStatus: PhotoSyncStatus.synced,
            thumbUrl: match.thumbUrl,
            originalUrl: match.originalUrl,
            printedAt: match.printedAt,
            clearError: true,
          ),
        );
      } else if (match != null && match.printedAt != photo.printedAt) {
        await _store.upsert(photo.copyWith(printedAt: match.printedAt));
      }
    }

    for (final remotePhoto in remote) {
      if (localIds.contains(remotePhoto.clientPhotoId)) continue;
      final imported = LocalPhoto(
        clientPhotoId: remotePhoto.clientPhotoId,
        eventId: remotePhoto.eventId,
        takenAt: remotePhoto.takenAt,
        createdAt: DateTime.now(),
        syncStatus: PhotoSyncStatus.synced,
        serverId: remotePhoto.id,
        printedAt: remotePhoto.printedAt,
        thumbUrl: remotePhoto.thumbUrl,
        originalUrl: remotePhoto.originalUrl,
      );
      await _store.upsert(imported);
      try {
        final thumb = await _api.downloadPhotoFile(
          remotePhoto.id,
          variant: 'thumb',
        );
        await files.writeThumb(remotePhoto.clientPhotoId, thumb);
      } catch (_) {
        // Gallery can retry later / show placeholder.
      }
    }
  }

  void _reloadLocal() {
    final eventId = _eventId;
    if (eventId == null) {
      _photos = [];
      return;
    }
    _photos = _store
        .listForEvent(eventId)
        .where((photo) => !photo.isPendingDelete)
        .toList();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _timer?.cancel();
    super.dispose();
  }
}
