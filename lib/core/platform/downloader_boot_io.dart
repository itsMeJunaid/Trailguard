import 'package:flutter_downloader/flutter_downloader.dart';

Future<void> bootDownloader() =>
    FlutterDownloader.initialize(debug: false, ignoreSsl: false);
