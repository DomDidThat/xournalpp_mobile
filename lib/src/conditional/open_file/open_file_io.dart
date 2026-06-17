import 'dart:io';
import 'dart:typed_data';

import 'package:xournalpp/src/PickedFile.dart';

PickedFile openFileByUri(String url, String extension) {
  Uint8List bytes = File(url).readAsBytesSync();
  String name = url.substring(url.lastIndexOf('/') + 1);
  return PickedFile(bytes: bytes, path: url, name: name);
}

Future<void> saveFileToPath(Uint8List bytes, String path) async {
  await File(path).writeAsBytes(bytes);
}

Future<void> deleteFileAtPath(String path) async {
  await File(path).delete();
}

Future<PickedFile> readFileFromPath(String path) async {
  final bytes = await File(path).readAsBytes();
  final name = path.substring(path.lastIndexOf('/') + 1);
  return PickedFile(bytes: bytes, path: path, name: name);
}
