import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fotoboot_operator/services/api_client.dart';

class PrintJobReport {
  const PrintJobReport({
    required this.eventId,
    required this.printerProfile,
    required this.copies,
    required this.localStatus,
    this.photoIds = const [],
    this.type = 'photo',
    this.error,
    this.serverJobId,
  });

  final String eventId;
  final String printerProfile;
  final int copies;
  final String localStatus; // queued | printed | failed
  final List<String> photoIds;
  final String type; // photo | test
  final String? error;
  final String? serverJobId;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'printerProfile': printerProfile,
        'copies': copies,
        'localStatus': localStatus,
        'photoIds': photoIds,
        'type': type,
        'error': error,
        'serverJobId': serverJobId,
      };

  factory PrintJobReport.fromJson(Map<String, dynamic> json) {
    return PrintJobReport(
      eventId: json['eventId'] as String,
      printerProfile: json['printerProfile'] as String,
      copies: json['copies'] as int? ?? 1,
      localStatus: json['localStatus'] as String? ?? 'queued',
      photoIds: (json['photoIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      type: json['type'] as String? ?? 'photo',
      error: json['error'] as String?,
      serverJobId: json['serverJobId'] as String?,
    );
  }
}

/// Reports print outcomes to the API; queues locally when offline.
class PrintJobReporter {
  PrintJobReporter({
    required ApiClient api,
    FlutterSecureStorage? storage,
  })  : _api = api,
        _storage = storage ?? const FlutterSecureStorage();

  static const _queueKey = 'fotoboot_print_job_queue';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<PrintJobInfo?> report(PrintJobReport report) async {
    try {
      final created = await _api.createPrintJob(
        eventId: report.eventId,
        printerProfile: report.printerProfile,
        copies: report.copies,
        photoIds: report.photoIds,
        type: report.type,
        localStatus: report.localStatus,
        error: report.error,
      );
      await flushQueue();
      return created;
    } on ApiException catch (e) {
      if (e.statusCode == 401) rethrow;
      await _enqueue(report);
      return null;
    } catch (_) {
      await _enqueue(report);
      return null;
    }
  }

  Future<void> flushQueue() async {
    final pending = await _readQueue();
    if (pending.isEmpty) return;

    final remaining = <PrintJobReport>[];
    for (final job in pending) {
      try {
        await _api.createPrintJob(
          eventId: job.eventId,
          printerProfile: job.printerProfile,
          copies: job.copies,
          photoIds: job.photoIds,
          type: job.type,
          localStatus: job.localStatus,
          error: job.error,
        );
      } catch (_) {
        remaining.add(job);
      }
    }
    await _writeQueue(remaining);
  }

  Future<int> pendingCount() async => (await _readQueue()).length;

  Future<void> _enqueue(PrintJobReport report) async {
    final q = await _readQueue();
    q.add(report);
    await _writeQueue(q);
  }

  Future<List<PrintJobReport>> _readQueue() async {
    final raw = await _storage.read(key: _queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PrintJobReport.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<PrintJobReport> jobs) {
    return _storage.write(
      key: _queueKey,
      value: jsonEncode(jobs.map((j) => j.toJson()).toList()),
    );
  }
}
