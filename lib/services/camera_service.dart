import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class CameraService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isReady = false;

  bool get isReady => _isReady;

  static const Map<String, String> _safetyHints = {
    'mushroom': '⚠️ Do not eat unless 100% identified. Many are deadly.',
    'snake': '🐍 Back away slowly. Do not provoke. Seek medical help if bitten.',
    'bear': '🐻 Make noise, back away slowly. Do NOT run.',
    'water': '💧 Purify before drinking. Risk of giardia/bacteria.',
    'plant': '🌿 Do not consume unknown plants. Some are toxic.',
    'fire': '🔥 Check wind direction. Clear 3m radius.',
    'default': '✅ Identified. Proceed with caution in unfamiliar terrain.',
  };

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenet_v2.tflite',
      );
      _labels = await _loadLabels();
      _isReady = true;
    } catch (e) {
      _isReady = false;
    }
  }

  Future<List<String>> _loadLabels() async {
    return ['mushroom', 'snake', 'bear', 'plant', 'water', 'fire', 'tent',
            'rock', 'tree', 'path', 'bird', 'insect'];
  }

  Future<Map<String, String>> classify(File imageFile) async {
    if (!_isReady || _interpreter == null) {
      return {'label': 'Unknown', 'hint': 'Model not ready', 'confidence': '0%'};
    }

    try {
      final raw = imageFile.readAsBytesSync();
      final decoded = img.decodeImage(raw);
      if (decoded == null) throw Exception('Cannot decode image');

      final resized = img.copyResize(decoded, width: 224, height: 224);

      final input = List.generate(1, (_) =>
        List.generate(224, (y) =>
          List.generate(224, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          })
        )
      );

      final output = List.generate(1, (_) => List.filled(1001, 0.0));
      _interpreter!.run(input, output);

      final scores = output[0];
      int maxIdx = 0;
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > scores[maxIdx]) maxIdx = i;
      }

      final label = maxIdx < _labels.length ? _labels[maxIdx] : 'Unknown';
      final confidence = (scores[maxIdx] * 100).toStringAsFixed(1);
      final hint = _getSafetyHint(label);

      return {
        'label': label.toUpperCase(),
        'confidence': '$confidence%',
        'hint': hint,
      };
    } catch (e) {
      return {'label': 'Error', 'hint': 'Could not classify image.', 'confidence': '0%'};
    }
  }

  String _getSafetyHint(String label) {
    for (final key in _safetyHints.keys) {
      if (label.toLowerCase().contains(key)) return _safetyHints[key]!;
    }
    return _safetyHints['default']!;
  }

  void dispose() => _interpreter?.close();
}
