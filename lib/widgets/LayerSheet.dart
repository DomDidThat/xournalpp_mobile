import 'package:flutter/material.dart';
import 'package:xournalpp/generated/l10n.dart';
import 'package:xournalpp/src/XppLayer.dart';
import 'package:xournalpp/src/XppPage.dart';

class LayerSheet extends StatefulWidget {
  final XppPage page;
  final int currentLayer;
  final ValueChanged<int> onLayerChanged;
  final VoidCallback onLayerAdded;
  final ValueChanged<int> onLayerDeleted;

  const LayerSheet({
    Key? key,
    required this.page,
    required this.currentLayer,
    required this.onLayerChanged,
    required this.onLayerAdded,
    required this.onLayerDeleted,
  }) : super(key: key);

  @override
  _LayerSheetState createState() => _LayerSheetState();
}

class _LayerSheetState extends State<LayerSheet> {
  @override
  Widget build(BuildContext context) {
    final layers = widget.page.layers!;
    return Container(
      height: 320,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Layers',
                    style: Theme.of(context).textTheme.headlineSmall),
                IconButton(
                  icon: Icon(Icons.add),
                  tooltip: 'Add layer',
                  onPressed: widget.onLayerAdded,
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              children: List.generate(layers.length, (i) {
                return ListTile(
                  key: ValueKey('layer_$i'),
                  leading: Icon(
                    i == widget.currentLayer
                        ? Icons.layers
                        : Icons.layers_outlined,
                    color: i == widget.currentLayer
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                  title: Text('Layer ${i + 1}'),
                  selected: i == widget.currentLayer,
                  trailing: layers.length > 1
                      ? IconButton(
                          icon: Icon(Icons.delete_outline),
                          onPressed: () => widget.onLayerDeleted(i),
                        )
                      : null,
                  onTap: () {
                    widget.onLayerChanged(i);
                    Navigator.of(context).pop();
                  },
                );
              }),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final layer = layers.removeAt(oldIndex);
                  layers.insert(newIndex, layer);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
