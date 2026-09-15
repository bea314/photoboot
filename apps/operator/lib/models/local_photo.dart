enum PhotoSyncStatus { pendingUpload, synced, error, pendingDelete }

class LocalPhoto {
  const LocalPhoto({
    required this.clientPhotoId,
    required this.eventId,
    required this.takenAt,
    required this.createdAt,
    required this.syncStatus,
    this.serverId,
    this.errorMessage,
    this.printedAt,
    this.thumbUrl,
    this.originalUrl,
  });

  final String clientPhotoId;
  final String eventId;
  final DateTime takenAt;
  final DateTime createdAt;
  final PhotoSyncStatus syncStatus;
  final String? serverId;
  final String? errorMessage;
  final DateTime? printedAt;
  final String? thumbUrl;
  final String? originalUrl;

  bool get isPrinted => printedAt != null;
  bool get canUpload =>
      syncStatus == PhotoSyncStatus.pendingUpload ||
      syncStatus == PhotoSyncStatus.error;
  bool get isPendingDelete => syncStatus == PhotoSyncStatus.pendingDelete;

  LocalPhoto copyWith({
    String? serverId,
    PhotoSyncStatus? syncStatus,
    String? errorMessage,
    DateTime? printedAt,
    String? thumbUrl,
    String? originalUrl,
    bool clearError = false,
  }) {
    return LocalPhoto(
      clientPhotoId: clientPhotoId,
      eventId: eventId,
      takenAt: takenAt,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      printedAt: printedAt ?? this.printedAt,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      originalUrl: originalUrl ?? this.originalUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientPhotoId': clientPhotoId,
      'eventId': eventId,
      'takenAt': takenAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus.name,
      'serverId': serverId,
      'errorMessage': errorMessage,
      'printedAt': printedAt?.toIso8601String(),
      'thumbUrl': thumbUrl,
      'originalUrl': originalUrl,
    };
  }

  factory LocalPhoto.fromMap(Map map) {
    return LocalPhoto(
      clientPhotoId: map['clientPhotoId'] as String,
      eventId: map['eventId'] as String,
      takenAt: DateTime.parse(map['takenAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      syncStatus: PhotoSyncStatus.values.firstWhere(
        (value) => value.name == map['syncStatus'],
        orElse: () => PhotoSyncStatus.pendingUpload,
      ),
      serverId: map['serverId'] as String?,
      errorMessage: map['errorMessage'] as String?,
      printedAt: map['printedAt'] == null
          ? null
          : DateTime.parse(map['printedAt'] as String),
      thumbUrl: map['thumbUrl'] as String?,
      originalUrl: map['originalUrl'] as String?,
    );
  }
}
