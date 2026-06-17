import 'package:flutter/material.dart';
import 'package:xournalpp/src/Notebook.dart';

class NotebookCard extends StatelessWidget {
  const NotebookCard({Key? key, required this.notebook}) : super(key: key);

  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final coverIsDark = notebook.coverColor.computeLuminance() < 0.4;
    final iconColor =
        coverIsDark ? Colors.white.withValues(alpha: 0.9) : Colors.black54;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: notebook.coverColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    notebook.coverColor,
                    Color.lerp(notebook.coverColor, Colors.black, 0.15)!,
                  ],
                ),
              ),
              child: Center(
                child: Icon(Icons.menu_book_rounded, size: 52, color: iconColor),
              ),
            ),
          ),
          // White footer — always readable, GoodNotes-style
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notebook.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  notebook.pageCount == 1
                      ? '1 page'
                      : '${notebook.pageCount} pages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
