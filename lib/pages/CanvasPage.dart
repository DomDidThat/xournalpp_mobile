import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:xournalpp/src/PickedFile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;
import 'package:xournalpp/generated/l10n.dart';
import 'package:xournalpp/src/XppFile.dart';
import 'package:xournalpp/src/XppLayer.dart';
import 'package:xournalpp/src/XppPage.dart';
import 'package:xournalpp/src/globals.dart';
import 'package:xournalpp/src/PencilSupport.dart';
import 'package:xournalpp/src/NotebookDatabase.dart';
import 'package:xournalpp/src/UndoStack.dart';
import 'package:xournalpp/widgets/EditingToolbar.dart';
import 'package:xournalpp/widgets/ModernToolbar.dart';
import 'package:xournalpp/widgets/LayerSheet.dart';
import 'package:xournalpp/widgets/MainDrawer.dart';
import 'package:xournalpp/widgets/PointerListener.dart';
import 'package:xournalpp/widgets/ToolBoxBottomSheet.dart';
import 'package:xournalpp/widgets/XppPageStack.dart';
import 'package:xournalpp/widgets/XppPagesListView.dart';
import 'package:xournalpp/widgets/ZoomableWidget.dart';

class SaveIntent extends Intent {}
class NewPageIntent extends Intent {}
class UndoIntent extends Intent {}
class RedoIntent extends Intent {}
class ZoomInIntent extends Intent {}
class ZoomOutIntent extends Intent {}
class ResetZoomIntent extends Intent {}

class CanvasPage extends StatefulWidget {
  CanvasPage({Key? key, this.file, this.filePath, this.notebookId, this.initialPageIndex = 0}) : super(key: key);

  final XppFile? file;
  final String? filePath;
  final String? notebookId;
  final int initialPageIndex;

  @override
  _CanvasPageState createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> with TickerProviderStateMixin {
  XppFile? _file;

  int currentPage = 0;
  int currentLayer = 0;

  final UndoStack _undoStack = UndoStack();

  XppContent? _selectedContent;
  Offset? _selectedContentOriginalOffset;

  Color toolColor = Colors.blueGrey;

  final Map<EditingTool, double> _toolWidths = {
    EditingTool.STYLUS: 3.0,
    EditingTool.HIGHLIGHT: 10.0,
    EditingTool.ERASER: 20.0,
    EditingTool.WHITEOUT: 20.0,
  };

  double get _currentToolWidth =>
      _toolWidths[_toolData[_currentDevice]] ?? 3.0;

  TransformationController _zoomController = TransformationController();

  Map<PointerDeviceKind?, EditingTool> _toolData = {};
  PointerDeviceKind? _currentDevice = PointerDeviceKind.touch;

  /// used fro parent-child communication
  final GlobalKey<XppPageStackState> _pageStackKey = GlobalKey();
  final GlobalKey<EditingToolBarState> _editingToolbarKey = GlobalKey();
  final GlobalKey<ModernToolbarState> _modernToolbarKey = GlobalKey();
  final GlobalKey<PointerListenerState> _pointerListenerKey = GlobalKey();
  final GlobalKey<ZoomableWidgetState> _zoomableKey = GlobalKey();
  final GlobalKey<XppPagesListViewState> pageListViewKey = GlobalKey();

  double pageScale = 1;

  bool savingFile = false;

  Animation<Matrix4>? _animationReset;
  late AnimationController _controllerReset;

  @override
  void initState() {
    _setMetadata();
    super.initState();
    PencilSupport.enablePalmRejection();
    _controllerReset = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
            SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
            NewPageIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
            UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ): RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyY):
            RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.equal): ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.minus): ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.digit0): ResetZoomIntent(),
      },
      child: Actions(
        actions: {
          SaveIntent: CallbackAction<SaveIntent>(onInvoke: (_) => saveFile()),
          UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) {
            _undoStack.undo();
            _pageStackKey.currentState!
                .setPageData(_file!.pages![currentPage]);
          }),
          RedoIntent: CallbackAction<RedoIntent>(onInvoke: (_) {
            _undoStack.redo();
            _pageStackKey.currentState!
                .setPageData(_file!.pages![currentPage]);
          }),
          NewPageIntent: CallbackAction<NewPageIntent>(onInvoke: (_) {
            setState(() {
              currentPage++;
              _file!.pages!.insert(currentPage,
                  XppPage.empty(background: Theme.of(context).cardColor));
              _pageStackKey.currentState!
                  .setPageData(_file!.pages![currentPage]);
            });
          }),
          ZoomInIntent: CallbackAction<ZoomInIntent>(
              onInvoke: (_) => _setScale(pageScale + 0.1)),
          ZoomOutIntent: CallbackAction<ZoomOutIntent>(
              onInvoke: (_) => _setScale(pageScale - 0.1)),
          ResetZoomIntent: CallbackAction<ResetZoomIntent>(
              onInvoke: (_) => _setScale(1.0)),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;
            return _buildPage(isWide);
          },
        ),
      ),
    );
    if (widget.notebookId == null) return inner;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: inner,
    );
  }

  Widget _buildPage(bool isWide) {
    if (isWide) {
      return Scaffold(
        drawer: MainDrawer(),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: BackButton(onPressed: _onBack),
          title: Tooltip(
            message: S.of(context).doubleTapToChange,
            child: GestureDetector(
                onDoubleTap: _showTitleDialog,
                child:
                    Text(widget.file?.title ?? S.of(context).newDocument)),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.undo),
              onPressed: _undoStack.canUndo
                  ? () {
                      setState(() => _undoStack.undo());
                      _pageStackKey.currentState!
                          .setPageData(_file!.pages![currentPage]);
                    }
                  : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: Icon(Icons.redo),
              onPressed: _undoStack.canRedo
                  ? () {
                      setState(() => _undoStack.redo());
                      _pageStackKey.currentState!
                          .setPageData(_file!.pages![currentPage]);
                    }
                  : null,
              tooltip: 'Redo',
            ),
            IconButton(
              icon: Icon(Icons.layers),
              onPressed: () => _showLayerSheet(),
              tooltip: 'Layer ${currentLayer + 1}',
            ),
            savingFile
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.save),
                    onPressed: saveFile,
                    tooltip: S.of(context).save,
                  ),
            PopupMenuButton<String>(
              onSelected: (item) async {
                if (item == S.of(context).saveAs) saveFile(export: true);
                if (item == S.of(context).sharePage) shareScreenshot();
              },
              itemBuilder: (BuildContext context) {
                return {
                  S.of(context).saveAs,
                  if (!kIsWeb) S.of(context).sharePage
                }.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Center(
              child: ModernToolbar(
                key: _modernToolbarKey,
                deviceMap: _toolData,
                color: toolColor,
                currentWidth: _currentToolWidth,
                onNewDeviceMap: (map) => setState(() {
                  _toolData = map;
                  _setZoomableState();
                }),
                onColorChanged: (c) => setState(() => toolColor = c),
                onWidthChanged: (tool, w) =>
                    setState(() => _toolWidths[tool] = w),
                onBackgroundChange: (newBackground) {
                  newBackground.size = _file!.pages![currentPage].pageSize;
                  setState(() =>
                      _file!.pages![currentPage].background = newBackground);
                },
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    _modernToolbarKey.currentState?.closeSubPanel(),
                behavior: HitTestBehavior.translucent,
                child: _buildCanvas(),
              ),
            ),
            Container(
              height: 100,
              color: Theme.of(context).colorScheme.surface,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  XppPagesListView(
                      key: pageListViewKey,
                      pages: _file!.pages,
                      onPageChange: (newPage) {
                        setState(() => currentPage = newPage);
                        _pageStackKey.currentState!
                            .setPageData(_file!.pages![currentPage]);
                      },
                      onPageDelete: (deletedIndex) => setState(() {
                            _file!.pages!.removeAt(deletedIndex);
                            if (_file!.pages!.length >= currentPage)
                              currentPage = _file!.pages!.length - 1;
                            if (_file!.pages!.isEmpty) {
                              _file!.pages!.add(XppPage.empty(
                                  background: Theme.of(context).cardColor));
                              currentPage = 0;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(S
                                          .of(context)
                                          .thereWereNoMorePagesWeAddedOne)));
                            }
                          }),
                      onPageMove: (initialIndex, movedTo) => setState(() {
                            final page = _file!.pages![initialIndex];
                            _file!.pages!.removeAt(initialIndex);
                            _file!.pages!.insert(movedTo - 1, page);
                          }),
                      currentPage: currentPage),
                  FloatingActionButton(
                    heroTag: 'AddXppPage',
                    onPressed: () {
                      final newPage = XppPage.empty(
                          background: Theme.of(context).cardColor);
                      _undoStack.execute(AddPageCommand(
                          file: _file!,
                          page: newPage,
                          index: currentPage + 1));
                      setState(() => currentPage++);
                      _pageStackKey.currentState!
                          .setPageData(_file!.pages![currentPage]);
                    },
                    child: Icon(Icons.add),
                    tooltip: S.of(context).addPage,
                  )
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
                elevation: 16,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                ),
                context: context,
                builder: (context) => ToolBoxBottomSheet(
                      onBackgroundChange: (newBackground) {
                        newBackground.size =
                            _file!.pages![currentPage].pageSize;
                        setState(() =>
                            _file!.pages![currentPage].background =
                                newBackground);
                      },
                    ));
          },
          tooltip: S.of(context).tools,
          child: Icon(Icons.format_paint),
        ),
      );
    }

    // Compact layout (phone / iPad portrait)
    return Scaffold(
      drawer: MainDrawer(),
      body: Stack(fit: StackFit.expand, children: [
        _buildCanvas(),
        _buildZoomControls(),
      ]),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(onPressed: _onBack),
        title: Tooltip(
          message: S.of(context).doubleTapToChange,
          child: GestureDetector(
              onDoubleTap: _showTitleDialog,
              child: Text(widget.file?.title ?? S.of(context).newDocument)),
        ),
        actions: [
          savingFile
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.save),
                  onPressed: saveFile,
                  tooltip: S.of(context).save,
                ),
          IconButton(
            icon: Icon(Icons.undo),
            onPressed: _undoStack.canUndo
                ? () {
                    setState(() => _undoStack.undo());
                    _pageStackKey.currentState!
                        .setPageData(_file!.pages![currentPage]);
                  }
                : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: Icon(Icons.redo),
            onPressed: _undoStack.canRedo
                ? () {
                    setState(() => _undoStack.redo());
                    _pageStackKey.currentState!
                        .setPageData(_file!.pages![currentPage]);
                  }
                : null,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: Icon(Icons.layers),
            onPressed: () => _showLayerSheet(),
            tooltip: 'Layer ${currentLayer + 1}',
          ),
          PopupMenuButton<String>(
            onSelected: (item) async {
              if (item == S.of(context).saveAs) saveFile(export: true);
              if (item == S.of(context).sharePage) shareScreenshot();
            },
            itemBuilder: (BuildContext context) {
              return {
                S.of(context).saveAs,
                if (!kIsWeb) S.of(context).sharePage
              }.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
        bottom: PreferredSize(
            preferredSize: Size.fromHeight(64),
            child: EditingToolBar(
                key: _editingToolbarKey,
                deviceMap: _toolData,
                color: toolColor,
                onWidthChange: (newWidth) {
                  setState(() {
                    final tool =
                        _toolData[_currentDevice] ?? EditingTool.STYLUS;
                    _toolWidths[tool] = newWidth * 2;
                  });
                },
                onColorChange: (newColor) {
                  setState(() {
                    toolColor = newColor;
                  });
                },
                onNewDeviceMap: (newDeviceMap) => setState(
                      () {
                        _toolData = newDeviceMap!;
                        _setZoomableState();
                      },
                    ))),
        ),
        bottomNavigationBar: _buildPageStrip(),
        floatingActionButtonLocation: kIsWeb
            ? FloatingActionButtonLocation.centerFloat
            : FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
                elevation: 16,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16)),
                ),
                context: context,
                builder: (context) => ToolBoxBottomSheet(
                      onBackgroundChange: (newBackground) {
                        newBackground.size =
                            _file!.pages![currentPage].pageSize;
                        setState(() =>
                            _file!.pages![currentPage].background =
                                newBackground);
                      },
                    ));
          },
          tooltip: S.of(context).tools,
          child: Icon(Icons.format_paint),
        ),
    );
  }

  Widget _buildCanvas() {
    return Hero(
      tag: 'ZoomArea',
      child: ZoomableWidget(
          key: _zoomableKey,
          controller: _zoomController,
          onInteractionStart: _onInteractionStart,
          onInteractionUpdate: (details) {
            setState(() => pageScale = _zoomController.value.entry(0, 0));
          },
          child: Center(
            child: Card(
              elevation: 12,
              color: Colors.white,
              child: AspectRatio(
                aspectRatio: _file!.pages![currentPage].pageSize!.ratio,
                child: FittedBox(
                  child: PointerListener(
                    key: _pointerListenerKey,
                    translationMatrix: _zoomController.value,
                    toolData: _toolData,
                    strokeWidth: _currentToolWidth,
                    color: toolColor,
                    onDeviceChange: ({int? device, PointerDeviceKind? kind}) {
                      setDefaultDeviceIfNotSet(kind: kind);
                      _currentDevice = kind;
                      _editingToolbarKey.currentState?.setState(() {
                        _editingToolbarKey.currentState?.currentDevice = kind;
                        _setZoomableState();
                      });
                      _modernToolbarKey.currentState?.setCurrentDevice(kind);
                    },
                    removeLastContent: () {
                      _file!.pages![currentPage].layers![currentLayer].content!
                          .removeLast();
                    },
                    filterEraser: ({Offset? coordinates, double? radius}) {
                      List<Function> removalFunctions = [];
                      final layer =
                          _file!.pages![currentPage].layers![currentLayer];
                      layer.content!.forEach((stroke) {
                        final delta = stroke!.eraseWhere(
                            coordinates: coordinates, radius: radius);
                        if (!delta.affected) return;
                        removalFunctions.add(() {
                          final int index = layer.content!.indexOf(stroke);
                          layer.content!.removeAt(index);
                          layer.content!.insertAll(index, delta.newContent);
                        });
                      });
                      if (removalFunctions.isNotEmpty) {
                        removalFunctions.forEach((element) => element());
                        setState(() {});
                      }
                    },
                    onNewContent: (newContent) {
                      final layer =
                          _file!.pages![currentPage].layers![currentLayer];
                      _undoStack.execute(
                          AddContentCommand(layer: layer, content: newContent!));
                      _pageStackKey.currentState!
                          .setPageData(_file!.pages![currentPage]);
                    },
                    onSelectionTap: (position) {
                      final layer =
                          _file!.pages![currentPage].layers![currentLayer];
                      XppContent? hit;
                      for (final content in layer.content!.reversed) {
                        if (content!.shouldSelectAt(
                            coordinates: position,
                            tool: EditingTool.SELECT)) {
                          hit = content;
                          break;
                        }
                      }
                      if (hit == _selectedContent) {
                        setState(() => _selectedContent = null);
                        return;
                      }
                      setState(() {
                        _selectedContent = hit;
                        _selectedContentOriginalOffset = hit?.getOffset();
                      });
                    },
                    onSelectionMove: (delta) {
                      if (_selectedContent == null) return;
                      setState(() {
                        _selectedContent!.moveBy(delta);
                        _selectedContentOriginalOffset =
                            _selectedContent!.getOffset();
                      });
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: XppPageStack(
                        key: _pageStackKey,
                        page: _file!.pages![currentPage],
                        selectedContent: _selectedContent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Tooltip(
        message: '${(pageScale * 100).round()} %',
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              IconButton(
                  icon: Icon(Icons.add),
                  color: Theme.of(context).primaryColor,
                  onPressed: () => _setScale(pageScale + 0.1)),
              SizedBox(
                height: 128,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    min: 0.1,
                    max: 5,
                    label: '${(pageScale * 100).round()} %',
                    value: pageScale,
                    onChanged: (newZoom) => _setScale(newZoom, animate: false),
                  ),
                ),
              ),
              IconButton(
                  icon: Icon(Icons.remove),
                  color: Theme.of(context).primaryColor,
                  onPressed: () => _setScale(pageScale - 0.1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageStrip() {
    return BottomAppBar(
      shape: kIsWeb ? null : CircularNotchedRectangle(),
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        constraints: BoxConstraints(maxHeight: 100),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            XppPagesListView(
                key: pageListViewKey,
                pages: _file!.pages,
                onPageChange: (newPage) {
                  setState(() => currentPage = newPage);
                  _pageStackKey.currentState!
                      .setPageData(_file!.pages![currentPage]);
                },
                onPageDelete: (deletedIndex) => setState(() {
                      _file!.pages!.removeAt(deletedIndex);
                      if (_file!.pages!.length >= currentPage)
                        currentPage = _file!.pages!.length - 1;
                      if (_file!.pages!.isEmpty) {
                        _file!.pages!.add(
                            XppPage.empty(background: Theme.of(context).cardColor));
                        currentPage = 0;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                S.of(context).thereWereNoMorePagesWeAddedOne)));
                      }
                    }),
                onPageMove: (initialIndex, movedTo) => setState(() {
                      final page = _file!.pages![initialIndex];
                      _file!.pages!.removeAt(initialIndex);
                      _file!.pages!.insert(movedTo - 1, page);
                    }),
                currentPage: currentPage),
            FloatingActionButton(
              heroTag: 'AddXppPage',
              onPressed: () {
                final newPage =
                    XppPage.empty(background: Theme.of(context).cardColor);
                _undoStack.execute(
                    AddPageCommand(file: _file!, page: newPage, index: currentPage + 1));
                setState(() => currentPage++);
                _pageStackKey.currentState!
                    .setPageData(_file!.pages![currentPage]);
              },
              child: Icon(Icons.add),
              tooltip: S.of(context).addPage,
            )
          ],
        ),
      ),
    );
  }



  bool _isMacOS(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.macOS;
  }

  void _setMetadata() {
    _file = widget.file;
    currentPage = widget.initialPageIndex
        .clamp(0, (_file?.pages?.length ?? 1) - 1);
  }

  Future<void> _showTitleDialog() async {
    await showDialog(
        context: context,
        builder: (context) {
          TextEditingController titleController =
              TextEditingController(text: _file!.title);
          return AlertDialog(
            title: Text(S.of(context).setDocumentTitle),
            content: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: TextField(
                  autofocus: true,
                  controller: titleController,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: S.of(context).newTitle)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _file!.title = titleController.text;
                  });
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).apply),
              ),
            ],
          );
        });
  }

  void _showLayerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      builder: (context) => LayerSheet(
        page: _file!.pages![currentPage],
        currentLayer: currentLayer,
        onLayerChanged: (newLayer) {
          setState(() => currentLayer = newLayer);
        },
        onLayerAdded: () {
          setState(() {
            _file!.pages![currentPage].layers!.add(XppLayer.empty());
            currentLayer = _file!.pages![currentPage].layers!.length - 1;
          });
          Navigator.of(context).pop();
        },
        onLayerDeleted: (i) {
          setState(() {
            _file!.pages![currentPage].layers!.removeAt(i);
            if (currentLayer >= _file!.pages![currentPage].layers!.length) {
              currentLayer = _file!.pages![currentPage].layers!.length - 1;
            }
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void setDefaultDeviceIfNotSet({PointerDeviceKind? kind}) {
    if (!_toolData.keys.contains(kind)) {
      EditingTool tool;
      switch (kind) {
        case PointerDeviceKind.touch:
          tool = EditingTool.MOVE;
          break;
        case PointerDeviceKind.invertedStylus:
          tool = EditingTool.ERASER;
          break;
        case PointerDeviceKind.stylus:
          tool = EditingTool.STYLUS;
          break;
        case PointerDeviceKind.mouse:
          tool = EditingTool.SELECT;
          break;
        default:
          tool = EditingTool.MOVE;
          break;
      }
      _toolData[kind] = tool;
    }
  }

  void _setZoomableState() {
    // On touch/iPad the toolbar never receives hover events, so it writes to
    // deviceMap[null] rather than deviceMap[touch]. Fall back to the null-key
    // entry so toolbar taps take effect immediately without requiring a prior
    // pointer event to set _currentDevice.
    final tool = _toolData.containsKey(_currentDevice)
        ? _toolData[_currentDevice]
        : _toolData[null];
    final zoomEnabled = tool == null || tool == EditingTool.MOVE;
    _zoomableKey.currentState!
        .setState(() => _zoomableKey.currentState!.enabled = zoomEnabled);
    _pointerListenerKey.currentState!.setState(() {
      _pointerListenerKey.currentState!.drawingEnabled = !zoomEnabled;
    });
  }

  void _setScale(double newZoom, {animate = true}) {
    newZoom = max(.1, min(5, newZoom));
    if (newZoom != pageScale) {
      // final translation =
      //     _zoomController.value.getTranslation() * newZoom / pageScale;
      pageScale = newZoom;
      if (animate) {
        _animateTransformation(_zoomController.value.clone()
          ..setDiagonal(Vector4(newZoom, newZoom, 1, 1)));
        // ..setTranslation(translation));
      } else {
        _zoomController.value.setDiagonal(Vector4(newZoom, newZoom, 1, 1));
        // _zoomController.value.setTranslation(translation);
      }
      setState(() {});
    }
  }

  void shareScreenshot() async {
    Uint8List imageBytes =
        await pageListViewKey.currentState!.getPng(currentPage);
    String fileName = (_file?.title ?? S.of(context).newFile) +
        ' ${currentPage + 1}.png';
    await PickedFile.exportToStorage(bytes: imageBytes, fileName: fileName);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.of(context).successfullyShared + ' ' + fileName)));
  }

  Future<void> _onBack() async {
    if (widget.notebookId != null) {
      await _saveToNotebook();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void saveFile({bool export = false}) async {
    if (widget.notebookId != null && !export) {
      await _saveToNotebook();
      return;
    }

    setState(() {
      savingFile = true;
    });
    ScaffoldFeatureController snackBarController =
        ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).savingFile),
        duration: Duration(days: 999),
      ),
    );
    if (_file!.title == null) await _showTitleDialog();
    if (_file!.title == null) {
      snackBarController.close();
      setState(() => savingFile = false);
      return;
    }
    String path = _file!.title! + '.xopp';
    _file!.previewImage = kIsWeb
        ? kTransparentImage
        : await pageListViewKey.currentState!.getPng(0);
    final file = _file!.toPickedFile(filePath: path);
    if (export) {
      await PickedFile.exportToStorage(bytes: file.bytes, fileName: file.name);
    } else {
      await PickedFile.saveToPath(bytes: file.bytes, path: path);
    }

    /// starting async task to save recent files list
    SharedPreferences.getInstance().then((prefs) {
      String jsonData = prefs.getString(PreferencesKeys.kRecentFiles) ?? '[]';
      Set files = (jsonDecode(jsonData) as Iterable).toSet();
      files.removeWhere((element) => element['path'] == path);
      files.add({
        'preview': base64Encode(_file!.previewImage!),
        'name': _file!.title,
        'path': path
      });
      jsonData = jsonEncode(files.toList());
      prefs.setString(PreferencesKeys.kRecentFiles, jsonData);
    });
    snackBarController.close();
    setState(() {
      savingFile = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).successfullySaved),
      ),
    );
    /*} catch (e) {
      snackBarController.close();
      setState(() {
        savingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(S.of(context).unfortunatelyThereWasAnErrorSavingThisFile),
        ),
      );
    }*/
  }

  Future<void> _saveToNotebook() async {
    setState(() => savingFile = true);
    final snack = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).savingFile),
        duration: const Duration(days: 999),
      ),
    );

    final encoded = _file!.toUint8List();
    if (encoded != null) {
      await NotebookDatabase.instance.saveNotebook(
        id: widget.notebookId!,
        xoppData: Uint8List.fromList(encoded),
        pageCount: _file!.pages!.length,
      );
    }

    // Render thumbnail for the current page and any pages rendered in the strip.
    final listState = pageListViewKey.currentState;
    if (listState != null) {
      for (int i = 0; i < (_file!.pages?.length ?? 0); i++) {
        try {
          final png = await listState.getPng(i);
          await NotebookDatabase.instance.upsertThumbnail(
            notebookId: widget.notebookId!,
            pageIndex: i,
            pngBytes: png,
          );
        } catch (_) {
          // Page widget not ready to render — skip, it will be captured on next save.
        }
      }
    }

    // Prune thumbnails for pages that were deleted.
    await NotebookDatabase.instance.trimThumbnails(
      notebookId: widget.notebookId!,
      newPageCount: _file!.pages!.length,
    );

    snack.close();
    if (mounted) {
      setState(() => savingFile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).successfullySaved)),
      );
    }
  }

  void _onAnimationReset() {
    _zoomController.value = _animationReset!.value;
    if (!_controllerReset.isAnimating) {
      _animationReset?.removeListener(_onAnimationReset);
      _animationReset = null;
      _controllerReset.reset();
    }
  }

  void _animateTransformation(Matrix4 animateTo) {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _zoomController.value,
      end: animateTo,
    ).animate(_controllerReset);
    _animationReset!.addListener(_onAnimationReset);
    _controllerReset.forward();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    // If the user tries to cause a transformation while the reset animation is
    // running, cancel the reset animation.
    if (_controllerReset.status == AnimationStatus.forward) {
      _controllerReset.stop();
      _animationReset?.removeListener(_onAnimationReset);
      _animationReset = null;
      // assign animateTo value to skip to end
      // _zoomController.value = _animateTo;
    }
  }

  @override
  void dispose() {
    _controllerReset.dispose();
    super.dispose();
  }
}
