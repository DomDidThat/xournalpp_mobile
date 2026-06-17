import 'dart:io';
import 'package:flutter/services.dart';

class PencilSupport {
  static const _channel = MethodChannel('xournalpp/pencil');

  static Future<void> enablePalmRejection() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod('enablePalmRejection');
  }

  static Future<double> getPressureSensitivity() async {
    if (!Platform.isIOS) return 1.0;
    return await _channel.invokeMethod('getPressureSensitivity') ?? 1.0;
  }
}
