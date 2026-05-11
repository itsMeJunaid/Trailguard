import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/model_download_service.dart';

class DownloadState {
  final bool inProgress;
  final int received;
  final int total;
  final double percent;
  final double bytesPerSec;
  final String? error;
  final String? savedPath;

  const DownloadState({
    this.inProgress = false,
    this.received = 0,
    this.total = 0,
    this.percent = 0,
    this.bytesPerSec = 0,
    this.error,
    this.savedPath,
  });

  DownloadState copyWith({
    bool? inProgress,
    int? received,
    int? total,
    double? percent,
    double? bytesPerSec,
    String? error,
    String? savedPath,
  }) =>
      DownloadState(
        inProgress: inProgress ?? this.inProgress,
        received: received ?? this.received,
        total: total ?? this.total,
        percent: percent ?? this.percent,
        bytesPerSec: bytesPerSec ?? this.bytesPerSec,
        error: error,
        savedPath: savedPath ?? this.savedPath,
      );

  String get receivedMB => (received / 1024 / 1024).toStringAsFixed(1);
  String get totalMB =>
      total > 0 ? (total / 1024 / 1024).toStringAsFixed(0) : '--';

  String get speedLabel {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  String get etaLabel {
    if (bytesPerSec <= 0 || total <= 0) return '--';
    final remaining = total - received;
    final seconds = (remaining / bytesPerSec).round();
    if (seconds < 60) return '${seconds}s left';
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m}m ${s}s left';
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final ModelDownloadService _service = ModelDownloadService();
  bool _inited = false;
  final _completer = <Completer<String?>>[];

  DownloadNotifier() : super(const DownloadState()) {
    _service.onProgress = (rec, tot, pct, bps) {
      if (!mounted) return;
      state = state.copyWith(
        inProgress: true,
        received: rec,
        total: tot,
        percent: pct,
        bytesPerSec: bps,
      );
    };
    _service.onComplete = (path, err) {
      if (!mounted) return;
      state = state.copyWith(
        inProgress: false,
        savedPath: path,
        error: err,
        percent: path != null ? 1.0 : state.percent,
      );
      for (final c in _completer) {
        if (!c.isCompleted) c.complete(path);
      }
      _completer.clear();
    };
  }

  Future<String?> startDownload({
    required String url,
    required String filename,
    Map<String, String>? headers,
  }) async {
    if (!_inited) {
      await _service.init();
      _inited = true;
    }
    state = const DownloadState(inProgress: true);
    final completer = Completer<String?>();
    _completer.add(completer);
    try {
      await _service.startDownload(
        url: url,
        filename: filename,
        headers: headers,
      );
    } catch (e) {
      state = state.copyWith(inProgress: false, error: e.toString());
      completer.complete(null);
    }
    return completer.future;
  }

  void cancel() {
    _service.cancel();
    state = state.copyWith(inProgress: false);
  }

  void reset() => state = const DownloadState();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>(
  (_) => DownloadNotifier(),
);
