import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../core/platform/local_files.dart';

/// Downloads a model file using flutter_downloader so the OS can keep the
/// transfer alive while the app is backgrounded. Progress is surfaced via
/// a static ReceivePort and pushed to the registered [onProgress] listener.
///
/// Total bytes aren't exposed by flutter_downloader — we do a HEAD request
/// to get Content-Length up front and derive `received` from `percent`.
class ModelDownloadService {
  static const _kReceiverName = 'trailguard_downloader_port';

  final ReceivePort _port = ReceivePort();
  String? _activeTaskId;
  int _totalBytes = 0;

  /// Called repeatedly with (received, total, percent 0..1, bps).
  void Function(int received, int total, double percent, double bps)?
      onProgress;

  /// Called once on completion with the file path (null on failure).
  void Function(String? savedPath, String? error)? onComplete;

  int _lastBytes = 0;
  DateTime _lastTick = DateTime.now();

  Future<void> init() async {
    await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
    _registerPort();
    FlutterDownloader.registerCallback(_downloadCallback);
  }

  void _registerPort() {
    IsolateNameServer.removePortNameMapping(_kReceiverName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _kReceiverName);
    _port.listen((dynamic data) {
      if (data is! List || data.length < 3) return;
      final taskId = data[0] as String;
      final statusInt = data[1] as int;
      final progress = data[2] as int;
      if (_activeTaskId != null && taskId != _activeTaskId) return;
      _handleEvent(DownloadTaskStatus.fromInt(statusInt), progress);
    });
  }

  @pragma('vm:entry-point')
  static void _downloadCallback(String id, int statusInt, int progress) {
    final send = IsolateNameServer.lookupPortByName(_kReceiverName);
    send?.send([id, statusInt, progress]);
  }

  Future<void> _handleEvent(DownloadTaskStatus status, int pct) async {
    final total = _totalBytes;
    final received = total > 0 ? ((total * pct) ~/ 100) : 0;

    final now = DateTime.now();
    final dtMs = now.difference(_lastTick).inMilliseconds.clamp(1, 60000);
    final delta = (received - _lastBytes).clamp(0, 1 << 31);
    final bps = delta / (dtMs / 1000.0);
    _lastTick = now;
    _lastBytes = received;

    onProgress?.call(received, total, pct / 100.0, bps);

    if (status == DownloadTaskStatus.complete) {
      final rows = await FlutterDownloader.loadTasksWithRawQuery(
        query: "SELECT * FROM task WHERE task_id='${_activeTaskId ?? ""}'",
      );
      final row = (rows != null && rows.isNotEmpty) ? rows.first : null;
      final path = row == null ? null : '${row.savedDir}/${row.filename ?? ""}';
      onComplete?.call(path, null);
      _activeTaskId = null;
    } else if (status == DownloadTaskStatus.failed ||
        status == DownloadTaskStatus.canceled) {
      onComplete?.call(
        null,
        status == DownloadTaskStatus.canceled ? 'cancelled' : 'failed',
      );
      _activeTaskId = null;
    }
  }

  Future<int> _headContentLength(String url, Map<String, String>? headers) async {
    try {
      final dio = Dio();
      final r = await dio.head(url,
          options: Options(
            followRedirects: true,
            headers: headers,
          ));
      final cl = r.headers.value(Headers.contentLengthHeader);
      if (cl != null) return int.tryParse(cl) ?? 0;
    } catch (_) {}
    return 0;
  }

  /// App-private external storage. Writable on every Android version with no
  /// permission at all, and it is one of the folders the model scanner checks.
  ///
  /// This used to try `/storage/emulated/0/Download/gemma_model` first, which
  /// on Android 11+ throws unless the user has granted All-files access — and
  /// a model saved there is then unreadable by the very app that saved it.
  Future<String> _resolveTargetDir() async => (await modelDirectory()).path;

  Future<String?> startDownload({
    required String url,
    required String filename,
    Map<String, String>? headers,
  }) async {
    final dir = await _resolveTargetDir();

    final existing = File('$dir/$filename');
    if (await existing.exists() &&
        await existing.length() > 50 * 1024 * 1024) {
      onComplete?.call(existing.path, null);
      return existing.path;
    }

    _totalBytes = await _headContentLength(url, headers);
    _lastBytes = 0;
    _lastTick = DateTime.now();

    _activeTaskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir,
      fileName: filename,
      headers: headers ?? {},
      showNotification: true,
      openFileFromNotification: false,
      allowCellular: true,
      requiresStorageNotLow: false,
      saveInPublicStorage: false,
    );
    return _activeTaskId;
  }

  Future<void> cancel() async {
    if (_activeTaskId != null) {
      try {
        await FlutterDownloader.cancel(taskId: _activeTaskId!);
      } catch (_) {}
      _activeTaskId = null;
    }
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(_kReceiverName);
    _port.close();
  }
}
