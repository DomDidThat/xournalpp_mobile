import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:xournalpp/pages/NotebookPagesPage.dart';
import 'package:xournalpp/src/Notebook.dart';
import 'package:xournalpp/src/NotebookDatabase.dart';
import 'package:xournalpp/src/XppFile.dart';
import 'package:xournalpp/widgets/CoverColorPicker.dart';
import 'package:xournalpp/widgets/NotebookCard.dart';

class NotebooksPage extends StatefulWidget {
  const NotebooksPage({Key? key}) : super(key: key);

  @override
  State<NotebooksPage> createState() => _NotebooksPageState();
}

class _NotebooksPageState extends State<NotebooksPage> {
  List<Notebook>? _notebooks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notebooks = await NotebookDatabase.instance.listNotebooks();
    if (mounted) setState(() => _notebooks = notebooks);
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 5;
    if (width >= 800) return 4;
    if (width >= 550) return 3;
    return 2;
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> _showCreateSheet() async {
    final result = await showModalBottomSheet<_NewNotebookResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NewNotebookSheet(),
    );
    if (result == null || !mounted) return;
    await _create(result.title, result.color);
  }

  Future<void> _create(String title, Color color) async {
    final xppFile = XppFile.empty(title: title, background: Colors.white);
    xppFile.previewImage = kTransparentImage;
    final encoded = xppFile.toUint8List();
    final bytes = encoded != null ? Uint8List.fromList(encoded) : Uint8List(0);

    final notebook = await NotebookDatabase.instance.createNotebook(
      title: title,
      coverColor: color,
      xoppData: bytes,
      pageCount: xppFile.pages?.length ?? 1,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotebookPagesPage(notebook: notebook)),
    );
    _load();
  }

  // ── Options (long-press) ───────────────────────────────────────────────────

  Future<void> _showOptions(Notebook notebook) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(notebook.title,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRenameDialog(notebook);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(notebook);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(Notebook notebook) async {
    final controller = TextEditingController(text: notebook.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Notebook'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed == true) {
      final newTitle = controller.text.trim();
      if (newTitle.isNotEmpty && newTitle != notebook.title) {
        await NotebookDatabase.instance.renameNotebook(notebook.id, newTitle);
        _load();
      }
    }
  }

  Future<void> _confirmDelete(Notebook notebook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notebook?'),
        content: Text(
            '"${notebook.title}" and all its pages will be permanently deleted.'),
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
    if (confirmed == true) {
      await NotebookDatabase.instance.deleteNotebook(notebook.id);
      _load();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notebooks'),
        centerTitle: false,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Notebook'),
      ),
    );
  }

  Widget _buildBody() {
    if (_notebooks == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notebooks!.isEmpty) {
      return _buildEmpty();
    }
    return _buildGrid();
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded,
              size: 96,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          Text(
            'No notebooks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "New Notebook" to get started.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _crossAxisCount(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: _load,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _notebooks!.length,
            itemBuilder: (context, index) {
              final notebook = _notebooks![index];
              return GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NotebookPagesPage(notebook: notebook),
                  ));
                  _load();
                },
                onLongPress: () => _showOptions(notebook),
                child: NotebookCard(notebook: notebook),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Sheet data ────────────────────────────────────────────────────────────────

class _NewNotebookResult {
  const _NewNotebookResult({required this.title, required this.color});
  final String title;
  final Color color;
}

// ── New Notebook bottom sheet — owns its own controller ───────────────────────

class _NewNotebookSheet extends StatefulWidget {
  const _NewNotebookSheet();

  @override
  State<_NewNotebookSheet> createState() => _NewNotebookSheetState();
}

class _NewNotebookSheetState extends State<_NewNotebookSheet> {
  final _titleController = TextEditingController();
  Color _selectedColor = CoverColorPicker.palette.first;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();
    Navigator.of(context)
        .pop(_NewNotebookResult(title: title, color: _selectedColor));
  }

  @override
  Widget build(BuildContext context) {
    // The modal sheet background is colorScheme.surface (dark in this theme).
    // Derive readable colours from the actual background luminance so text is
    // always visible regardless of light/dark mode.
    final bg = Theme.of(context).colorScheme.surface;
    final isDarkBg = bg.computeLuminance() < 0.5;
    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final hintColor = isDarkBg ? Colors.white60 : Colors.black45;
    final borderColor = isDarkBg ? Colors.white38 : Colors.black26;

    return Material(
      color: bg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New Notebook',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: textColor),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(color: textColor),
              cursorColor: textColor,
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: hintColor),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Text(
              'Cover colour',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: hintColor),
            ),
            const SizedBox(height: 10),
            CoverColorPicker(
              selected: _selectedColor,
              onChanged: (c) => setState(() => _selectedColor = c),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submit,
              child: const Text('Create'),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
