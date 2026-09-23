import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// True when a real filesystem is reachable — gates model download/scan UI.
const bool kHasFileSystem = true;

/// Human label for the current runtime, used in status banners.
const String kRuntimeLabel = 'device';

Widget localImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? errorWidget,
}) =>
    Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) =>
          errorWidget ?? _brokenImage(width, height),
    );

Widget _brokenImage(double? width, double? height) => Container(
      width: width,
      height: height,
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.black26),
      ),
    );

bool localFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Future<int> localFileSize(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return 0;
  }
}

Future<Uint8List?> localFileBytes(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Copy a picked image out of the picker's temp dir so the reference survives.
Future<String> persistPickedImage(String srcPath) async {
  final dir = await getApplicationDocumentsDirectory();
  final target =
      File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await File(srcPath).copy(target.path);
  return target.path;
}

Future<void> writeDocText(String name, String text) async {
  final dir = await getApplicationDocumentsDirectory();
  await File('${dir.path}/$name').writeAsString(text);
}

Future<String?> readDocText(String name) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$name');
    if (!await f.exists()) return null;
    return await f.readAsString();
  } catch (_) {
    return null;
  }
}

const _modelExtensions = {
  '.litertlm', '.tflite', '.task', '.bin', '.gguf', '.pt'
};

/// Best-effort sweep of the usual Android download/document folders.
Future<List<String>> scanForModelFiles() async {
  // If the user denies, we still try — most Android versions let us read
  // Download/ via the MediaStore without it.
  try {
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  } catch (_) {}
  try {
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
  } catch (_) {}

  final found = <String>{};
  final dirs = <String>[
    '/storage/emulated/0/Download/gemma_model',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/TrailGuardModels',
  ];

  try {
    final appExt = await getExternalStorageDirectory();
    if (appExt != null) {
      dirs.add(appExt.path);
      dirs.add('${appExt.path}/gemma_model');
    }
  } catch (_) {}

  for (final p in dirs) {
    await _scanDir(Directory(p), found, depth: 2);
  }
  return found.toList();
}

Future<void> _scanDir(Directory dir, Set<String> acc, {int depth = 2}) async {
  try {
    if (!await dir.exists()) return;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File) {
        final lower = e.path.toLowerCase();
        if (_modelExtensions.any(lower.endsWith)) {
          acc.add(e.path);
        }
      } else if (e is Directory && depth > 0) {
        await _scanDir(e, acc, depth: depth - 1);
      }
    }
  } catch (_) {}
}


/// Where imported models live: app-private, so it is readable on every Android
/// version without any storage permission at all.
Future<Directory> modelDirectory() async {
  final base = await getExternalStorageDirectory() ??
      await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/gemma_model');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Ask for "All files access" and report whether it was actually granted.
///
/// This is the only way an app can read `/storage/emulated/0/Download` on
/// Android 11+. `requestLegacyExternalStorage` does nothing past targetSdk 29,
/// and READ_MEDIA_* does not cover a `.litertlm` file because it is not media.
Future<bool> ensureAllFilesAccess() async {
  try {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  } catch (_) {
    return false;
  }
}

/// Let the user hand us the model through the system file picker.
///
/// This path needs no storage permission — the picker grants access to the one
/// file the user chose — so it works even when All files access is denied.
/// Returns the new in-app path, or null if the user cancelled.
Future<String?> importModelFile() async {
  final result = await FilePicker.platform.pickFiles(
    withData: false,
    allowMultiple: false,
  );
  final sourcePath = result?.files.single.path;
  if (sourcePath == null) return null;

  final dir = await modelDirectory();
  final target = File('${dir.path}/${result!.files.single.name}');
  final source = File(sourcePath);

  // The picker already staged a copy in our cache, so a rename is a cheap
  // metadata move on the same volume. Only fall back to a real copy — which
  // for a 2.6 GB model is slow and needs double the free space — if it is not.
  try {
    await source.rename(target.path);
  } catch (_) {
    await source.copy(target.path);
    try {
      await source.delete();
    } catch (_) {}
  }
  return target.path;
}
