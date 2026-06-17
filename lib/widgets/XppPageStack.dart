import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:xournalpp/src/XppBackground.dart';
import 'package:xournalpp/src/XppLayer.dart';
import 'package:xournalpp/src/XppPage.dart';

class XppPageStack extends StatefulWidget {
  final XppPage? page;
  final XppContent? selectedContent;

  const XppPageStack({Key? key, this.page, this.selectedContent})
      : super(key: key);

  @override
  XppPageStackState createState() => XppPageStackState();
}

class XppPageStackState extends State<XppPageStack>
    with AutomaticKeepAliveClientMixin {
  GlobalKey pngKey = GlobalKey();
  XppPage? page;

  XppBackground? _lastKnownBackground;
  Widget background = Container();

  @override
  void initState() {
    page = widget.page;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    List<Widget> children = [];

    if (page!.background != null && _lastKnownBackground != page!.background) {
      _lastKnownBackground = page!.background;
      background = page!.background!.render();
    }
    children.add(background);

    children.addAll(page!.layers!.map((e) => XppLayerStack(
          layer: e,
        )));
    if (widget.selectedContent != null) {
      final offset = widget.selectedContent!.getOffset();
      if (offset != null) {
        children.add(Positioned(
          left: offset.dx,
          top: offset.dy,
          child: IgnorePointer(
            child: SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _SelectionPainter(),
              ),
            ),
          ),
        ));
      }
    }
    return RepaintBoundary(
        key: pngKey,
        child: SizedBox(
            width: page!.pageSize!.width,
            height: page!.pageSize!.height,
            child: (Stack(children: children))));
  }

  void setPageData(XppPage pageData) {
    setState(() => page = pageData);
  }

  Future<Uint8List> toPng() async {
    RenderRepaintBoundary boundary =
        pngKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage();
    ByteData byteData = await (image.toByteData(format: ui.ImageByteFormat.png)
        as FutureOr<ByteData>);
    Uint8List pngBytes = byteData.buffer.asUint8List();
    return pngBytes;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant XppPageStack oldWidget) {
    setState(() {});
    super.didUpdateWidget(oldWidget);
  }
}

class _SelectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    const handleSize = 8.0;
    for (final pos in [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: handleSize, height: handleSize),
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class XppLayerStack extends StatefulWidget {
  final XppLayer? layer;

  const XppLayerStack({Key? key, this.layer}) : super(key: key);
  @override
  _XppLayerStackState createState() => _XppLayerStackState();
}

class _XppLayerStackState extends State<XppLayerStack> {
  Map<XppContent, Widget> renderedContent = {};
  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    for (final element in widget.layer!.content!) {
      if (element == null) continue;
      if (!renderedContent.containsKey(element)) {
        renderedContent[element] = Positioned(
          child: element.render(),
          top: element.getOffset()?.dy ?? 0,
          left: element.getOffset()?.dx ?? 0,
        );
      }
      children.add(renderedContent[element]!);
    }
    return Stack(
      children: children,
    );
  }
}
