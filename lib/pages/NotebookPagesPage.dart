import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xournalpp/pages/CanvasPage.dart';
import 'package:xournalpp/src/Notebook.dart';
import 'package:xournalpp/src/NotebookDatabase.dart';
import 'package:xournalpp/src/PickedFile.dart';
import 'package:xournalpp/src/XppFile.dart';
import 'package:xournalpp/src/XppPage.dart';
import 'package:xournalpp/widgets/XppPageStack.dart';

class NotebookPagesPage extends StatefulWidget {
  const NotebookPagesPage({Key? key, required this.notebook}) : super(key: key);

  final Notebook notebook;

  @override
  State<NotebookPagesPage> createState() => _NotebookPagesPageState();
}

class _NotebookPagesPageState extends State<NotebookPagesPage> {
  Notebook? _notebook;
  XppFile? _xppFile;
  Map<int, Uint8List?> _thumbnails = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final nb = await NotebookDatabase.instance.loadNotebook(widget.notebook.id);
      if (nb == null || nb.xoppData == null || nb.xoppData!.isEmpty) {
        throw Exception('Notebook data is missing');
      }

      final pickedFile = PickedFile(
        bytes: nb.xoppData!,
        name: '${nb.title}.xopp',
      );
      final xppFile = await XppFile.fromPickedFile(
        pickedFile,
        null,
        _unavailableCallback,
      );

      final thumbEntries = await NotebookDatabase.instance.listThumbnails(nb.id);
      final thumbMap = Map.fromEntries(thumbEntries);

      if (mounted) {
        setState(() {
          _notebook = nb;
          _xppFile = xppFile;
          _thumbnails = thumbMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  static Future<PickedFile> _unavailableCallback(String? path) async {
    throw Exception('Referenced file not available: $path');
  }

  // ── Serialise & persist ────────────────────────────────────────────────────

  Future<void> _persist() async {
    if (_xppFile == null || _notebook == null) return;
    final encoded = _xppFile!.toUint8List();
    if (encoded == null) return;
    await NotebookDatabase.instance.saveNotebook(
      id: _notebook!.id,
      xoppData: Uint8List.fromList(encoded),
      pageCount: _xppFile!.pages?.length ?? 0,
    );
  }

  // ── Add page ───────────────────────────────────────────────────────────────

  Future<void> _addPage() async {
    if (_xppFile == null) return;
    final newPage = XppPage.empty(background: Colors.white);
    _xppFile!.pages!.add(newPage);
    await _persist();
    final newIndex = _xppFile!.pages!.length - 1;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CanvasPage(
        file: _xppFile,
        notebookId: _notebook!.id,
        initialPageIndex: newIndex,
      ),
    ));
    _loadAll();
  }

  // ── Open page ──────────────────────────────────────────────────────────────

  Future<void> _openPage(int pageIndex) async {
    if (_xppFile == null || _notebook == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CanvasPage(
        file: _xppFile,
        notebookId: _notebook!.id,
        initialPageIndex: pageIndex,
      ),
    ));
    _loadAll();
  }

  // ── Delete page ────────────────────────────────────────────────────────────

  Future<void> _confirmDeletePage(int pageIndex) async {
    if (_xppFile == null || (_xppFile!.pages?.length ?? 0) <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the only page.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text('Page ${pageIndex + 1} will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _xppFile!.pages!.removeAt(pageIndex);
    await _persist();
    await NotebookDatabase.instance.trimThumbnails(
      notebookId: _notebook!.id,
      newPageCount: _xppFile!.pages!.length,
    );
    _loadAll();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_notebook?.title ?? widget.notebook.title),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add page',
            onPressed: _loading ? null : _addPage,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Could not open notebook', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }
    return _buildGrid();
  }

  Widget _buildGrid() {
    final pageCount = _xppFile?.pages?.length ?? 0;
    final itemCount = pageCount + 1; // +1 for the "Add Page" card

    return LayoutBuilder(builder: (context, constraints) {
      final cols = _crossAxisCount(constraints.maxWidth);
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.75,
          ),
          itemCount: itemCount,
          itemBuilder: (ctx, i) {
            if (i == pageCount) return _buildAddCard();
            return _buildPageCard(i);
          },
        ),
      );
    });
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 5;
    if (width >= 800) return 4;
    if (width >= 550) return 3;
    return 2;
  }

  Widget _buildPageCard(int pageIndex) {
    final thumbnail = _thumbnails[pageIndex];
    final page = _xppFile!.pages![pageIndex];

    return GestureDetector(
      onTap: () => _openPage(pageIndex),
      onLongPress: () => _confirmDeletePage(pageIndex),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: thumbnail != null
                  ? Image.memory(thumbnail, fit: BoxFit.cover)
                  : _LivePagePreview(page: page),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Page ${pageIndex + 1}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: _addPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                  width: 2,
                  // ignore: deprecated_member_use
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline,
                        size: 40,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7)),
                    const SizedBox(height: 6),
                    Text('Add Page',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(' ', textAlign: TextAlign.center), // alignment spacer
        ],
      ),
    );
  }
}

// ── Live page preview widget ──────────────────────────────────────────────────

class _LivePagePreview extends StatelessWidget {
  const _LivePagePreview({required this.page});
  final XppPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: page.pageSize!.width,
          height: page.pageSize!.height,
          child: XppPageStack(page: page),
        ),
      );
    });
  }
}
