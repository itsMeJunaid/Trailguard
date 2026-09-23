import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The browser has no user-visible filesystem we can sweep for model files.
const bool kHasFileSystem = false;

const String kRuntimeLabel = 'browser';

/// `image_picker` and `camera` both hand back `blob:` object URLs on web,
/// which [Image.network] resolves directly.
Widget localImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? errorWidget,
}) =>
    Image.network(
      path,
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

/// A blob URL handed to us this session is assumed live; there is nothing to
/// stat synchronously in the browser.
bool localFileExists(String path) => path.isNotEmpty;

Future<int> localFileSize(String path) async {
  final bytes = await localFileBytes(path);
  return bytes?.length ?? 0;
}

Future<Uint8List?> localFileBytes(String path) async {
  try {
    return (await http.get(Uri.parse(path))).bodyBytes;
  } catch (_) {
    return null;
  }
}

/// Blob URLs stay valid for the life of the page, so there is nothing to copy.
Future<String> persistPickedImage(String srcPath) async => srcPath;

Future<void> writeDocText(String name, String text) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('doc_$name', text);
}

Future<String?> readDocText(String name) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('doc_$name');
  } catch (_) {
    return null;
  }
}

Future<List<String>> scanForModelFiles() async => const [];


/// No filesystem to import into, and no LiteRT-LM engine to feed.
Future<bool> ensureAllFilesAccess() async => false;
Future<String?> importModelFile() async => null;
