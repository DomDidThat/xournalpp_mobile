import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xournalpp/src/conditional/open_file/open_file_generic.dart'
    if (dart.library.html) 'package:xournalpp/src/conditional/open_file/open_file_web.dart'
    if (dart.library.io) 'package:xournalpp/src/conditional/open_file/open_file_io.dart';

class PickedFile {
  final Uint8List bytes;
  final String? path;
  final String name;

  PickedFile({required this.bytes, this.path, required this.name});

  String get extension => name.contains('.')
      ? name.substring(name.lastIndexOf('.') + 1)
      : '';

  static Future<PickedFile?> importFromStorage({
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return PickedFile(
      bytes: file.bytes ?? Uint8List(0),
      path: file.path,
      name: file.name,
    );
  }

  static Future<PickedFile> fromInternalPath({required String path}) async {
    return readFileFromPath(path);
  }

  static Future<void> saveToPath({
    required Uint8List bytes,
    required String path,
  }) async {
    await saveFileToPath(bytes, path);
  }

  static Future<String?> exportToStorage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!kIsWeb) {
      final path = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
      );
      if (path != null) return path;
    }
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName)],
    );
    return fileName;
  }

  static Future<void> delete({required String path}) async {
    await deleteFileAtPath(path);
  }
}
