import 'dart:typed_data';

import 'package:flutter/widgets.dart';

enum DragOperation { all, copy, link, move }

enum CursorType { defaultCursor, grabbing, moving }

class DropzoneViewController {
  Future<String> getFilename(dynamic file) =>
      throw UnsupportedError('Dropzone not supported on this platform');

  Future<Uint8List> getFileData(dynamic file) =>
      throw UnsupportedError('Dropzone not supported on this platform');
}

class DropzoneView extends StatefulWidget {
  final Future<void> Function(dynamic file)? onDrop;
  final void Function()? onHover;
  final void Function()? onLeave;
  final void Function()? onLoaded;
  final void Function(String message)? onError;
  final void Function(DropzoneViewController controller)? onCreated;
  final DragOperation operation;

  const DropzoneView({
    Key? key,
    this.onDrop,
    this.onHover,
    this.onLeave,
    this.onLoaded,
    this.onError,
    this.onCreated,
    this.operation = DragOperation.all,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _DropzoneViewState();
}

class _DropzoneViewState extends State<DropzoneView> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
