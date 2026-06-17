import 'dart:typed_data';

import 'package:xournalpp/src/PickedFile.dart';

PickedFile openFileByUri(String url, String extension) {
  throw (UnsupportedError('Opening local files is not supported on the web.'));
}

Future<void> saveFileToPath(Uint8List bytes, String path) async {
  throw (UnsupportedError('Saving to local path is not supported on the web.'));
}

Future<void> deleteFileAtPath(String path) async {
  throw (UnsupportedError('Deleting local files is not supported on the web.'));
}

Future<PickedFile> readFileFromPath(String path) async {
  throw (UnsupportedError('Reading local files is not supported on the web.'));
}
