import 'dart:typed_data';

import 'package:xournalpp/src/PickedFile.dart';

PickedFile openFileByUri(String url, String extension) {
  throw (UnimplementedError(
      'Could not find any file open implementation for your platform.'));
}

Future<void> saveFileToPath(Uint8List bytes, String path) async {
  throw (UnimplementedError(
      'Could not find any file save implementation for your platform.'));
}

Future<void> deleteFileAtPath(String path) async {
  throw (UnimplementedError(
      'Could not find any file delete implementation for your platform.'));
}

Future<PickedFile> readFileFromPath(String path) async {
  throw (UnimplementedError(
      'Could not find any file read implementation for your platform.'));
}
