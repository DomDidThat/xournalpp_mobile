import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xournalpp/layer_contents/XppStroke.dart';
import 'package:xournalpp/layer_contents/XppTexImage.dart';
import 'package:xournalpp/layer_contents/XppText.dart';
import 'package:xournalpp/src/XppLayer.dart';
import 'package:xournalpp/widgets/ToolBoxBottomSheet.dart';

class PointerListener extends StatefulWidget {
  final Function(XppContent?)? onNewContent;
  final Function({int? device, PointerDeviceKind? kind})? onDeviceChange;
  final Widget? child;
  final Map<PointerDeviceKind?, EditingTool> toolData;
  final Matrix4? translationMatrix;
  final double? strokeWidth;
  final Color? color;
  final Function({Offset? coordinates, double? radius})? filterEraser;
  final Function()? removeLastContent;
  final Function(Offset position)? onSelectionTap;
  final Function(Offset delta)? onSelectionMove;

  const PointerListener(
      {Key? key,
      this.onNewContent,
      this.child,
      this.toolData = const {},
      this.translationMatrix,
      this.onDeviceChange,
      this.strokeWidth,
      this.color,
      this.filterEraser,
      this.removeLastContent,
      this.onSelectionTap,
      this.onSelectionMove})
      : super(key: key);

  @override
  PointerListenerState createState() => PointerListenerState();
}

class PointerListenerState extends State<PointerListener> {
  late bool drawingEnabled;
  Offset? _lastSelectPosition;

  List<XppStrokePoint> points = [];

  late XppStrokeTool tool;

  Map<int, DateTime> pointerTimestamps = Map();

  bool poppedContentForCurrentPointer = false;

  // Track active pointer IDs (data.pointer is unique per touch contact).
  final Set<int> _activePointers = {};
  // True once a second pointer arrived during a stroke — stays true until
  // all pointers are lifted so we don't accidentally commit the stroke.
  bool _multiTouchCancelled = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        widget.onDeviceChange!(device: event.device, kind: event.kind);
      },
      opaque: false,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (data) {
          widget.onDeviceChange!(device: data.device, kind: data.kind);
          if (!drawingEnabled) return;
          if (_multiTouchCancelled || _activePointers.length > 1) return;

          if (isSelect(data)) {
            final delta = _lastSelectPosition != null
                ? data.localPosition - _lastSelectPosition!
                : Offset.zero;
            _lastSelectPosition = data.localPosition;
            widget.onSelectionMove?.call(delta);
            return;
          }

          if (isPen(data) || isHighlighter(data)) {
            double? width = (data.pressure == 0
                ? widget.strokeWidth
                : data.pressure * widget.strokeWidth!);
            if (isHighlighter(data)) width = width! * 5;
            points.add(XppStrokePoint(
                x: data.localPosition.dx,
                y: data.localPosition.dy,
                width: width));
            setState(() {});
          }

          if (isEraser(data))
            widget.filterEraser!(
                coordinates:
                    Offset(data.localPosition.dx, data.localPosition.dy),
                radius: widget.strokeWidth);
        },
        onPointerDown: (data) {
          _activePointers.add(data.pointer);
          if (_activePointers.length > 1) {
            // Second finger arrived — cancel any in-progress stroke immediately
            // so it isn't committed when the first finger lifts.
            _multiTouchCancelled = true;
            if (points.isNotEmpty) setState(() => points.clear());
            return;
          }
          _multiTouchCancelled = false;

          setState(() {
            tool = getToolFromPointer(data);
          });
          if (_detectTwoFingerGesture(data, shouldPop: true)) return;

          widget.onDeviceChange!(device: data.device, kind: data.kind);

          if (isSelect(data)) {
            _lastSelectPosition = data.localPosition;
            widget.onSelectionTap?.call(data.localPosition);
            return;
          }

          if (isLaTeX(data)) {
            XppTexImage.edit(
                    context: context,
                    topLeft: data.localPosition,
                    color: widget.color)
                .then((value) {
              widget.onNewContent!(value);
            });
          }
          if (isText(data)) {
            XppText(
                offset: data.localPosition,
                color: widget.color,
                size: widget.strokeWidth! * 3);
          }
        },
        onPointerUp: (data) {
          _activePointers.remove(data.pointer);
          if (_activePointers.isEmpty) _multiTouchCancelled = false;
          _lastSelectPosition = null;
          if (!_multiTouchCancelled && points.isNotEmpty) saveStroke(tool);
          poppedContentForCurrentPointer = false;
          points.clear();
        },
        onPointerCancel: (data) {
          _activePointers.remove(data.pointer);
          if (_activePointers.isEmpty) _multiTouchCancelled = false;
          _lastSelectPosition = null;
          points.clear();
          poppedContentForCurrentPointer = false;
        },
        onPointerSignal: (data) {
          setState(() {
            tool = getToolFromPointer(data);
          });
          widget.onDeviceChange!(device: data.device, kind: data.kind);
        },
        child: Stack(
          children: [
            widget.child!,
            if (points.length > 0)
              CustomPaint(
                /*size: Size(
        bottomRight.dx - getOffset().dx, bottomRight.dy - getOffset().dy),*/
                foregroundPainter: XppStrokePainter(
                    points: points,
                    color: widget.color,
                    topLeft: Offset(0, 0),
                    smoothPressure: tool == XppStrokeTool.PEN),
              ),
          ],
        ),
      ),
    );
  }

  // clearPoints method used to reset the canvas
  // method can be called using
  //   key.currentState.clearPoints();

  void clearPoints() {
    setState(() {
      points.clear();
    });
  }

  void saveStroke(XppStrokeTool tool) {
    if (points.isNotEmpty) {
      XppStroke stroke = XppStroke.byTool(
          tool: tool, points: List.from(points), color: widget.color);
      widget.onNewContent!(stroke);
    }
  }

  // Returns the tool for a pointer's device kind, falling back to the null-key
  // entry that toolbars write when no hover event has set their currentDevice
  // (the common case on iPad / touch-only devices).
  EditingTool? _effectiveTool(PointerEvent data) =>
      widget.toolData[data.kind] ?? widget.toolData[null];

  bool isSelect(PointerEvent data) =>
      _effectiveTool(data) == EditingTool.SELECT;

  bool isPen(PointerEvent data) {
    final tool = _effectiveTool(data);
    return tool == EditingTool.STYLUS ||
        (tool == null && data.kind == PointerDeviceKind.stylus);
  }

  bool isHighlighter(PointerEvent data) =>
      _effectiveTool(data) == EditingTool.HIGHLIGHT;

  bool isEraser(PointerEvent data) {
    final tool = _effectiveTool(data);
    return tool == EditingTool.ERASER ||
        (tool == null && data.kind == PointerDeviceKind.invertedStylus);
  }

  bool isText(PointerEvent data) => _effectiveTool(data) == EditingTool.TEXT;

  bool isLaTeX(PointerEvent data) => _effectiveTool(data) == EditingTool.LATEX;

  XppStrokeTool getToolFromPointer(PointerEvent data) {
    XppStrokeTool tool = XppStrokeTool.PEN;
    if (isHighlighter(data))
      tool = XppStrokeTool.HIGHLIGHTER;
    else if (isEraser(data)) tool = XppStrokeTool.ERASER;
    return tool;
  }

  bool _detectTwoFingerGesture(PointerEvent data, {bool shouldPop = false}) {
    // detecting two-finger gestures
    final timestamp = DateTime.now();
    bool foundCloseOffset = false;
    pointerTimestamps.remove(data.device);
    pointerTimestamps.forEach((key, value) {
      if (value.difference(timestamp).inMilliseconds.abs() < 100) {
        foundCloseOffset = true;
      }
    });
    if (shouldPop && foundCloseOffset && !poppedContentForCurrentPointer) {
      poppedContentForCurrentPointer = true;
    }
    pointerTimestamps[data.device] = timestamp;
    return foundCloseOffset;
  }
}
