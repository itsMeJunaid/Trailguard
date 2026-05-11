import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  try {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFE8FFF0),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  } catch (_) {}

  // Fire-and-forget init. If the plugin bridge isn't ready yet we don't
  // want to block startup — the download screen will lazily call init
  // when the user actually taps DOWNLOAD.
  unawaited(() async {
    try {
      await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
    } catch (_) {}
  }());

  runApp(const ProviderScope(child: TrailGuardApp()));
}

void unawaited(Future<void> f) {}
