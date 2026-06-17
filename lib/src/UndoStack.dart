import 'package:xournalpp/src/XppFile.dart';
import 'package:xournalpp/src/XppLayer.dart';
import 'package:xournalpp/src/XppPage.dart';

abstract class Command {
  void execute();
  void undo();
  String get description;
}

class UndoStack {
  final List<Command> _commands = [];
  int _pointer = -1;

  void execute(Command command) {
    _commands.removeRange(_pointer + 1, _commands.length);
    command.execute();
    _commands.add(command);
    _pointer = _commands.length - 1;
  }

  bool undo() {
    if (_pointer < 0) return false;
    _commands[_pointer].undo();
    _pointer--;
    return true;
  }

  bool redo() {
    if (_pointer >= _commands.length - 1) return false;
    _pointer++;
    _commands[_pointer].execute();
    return true;
  }

  bool get canUndo => _pointer >= 0;
  bool get canRedo => _pointer < _commands.length - 1;

  void clear() {
    _commands.clear();
    _pointer = -1;
  }
}

class AddContentCommand extends Command {
  final XppLayer layer;
  final XppContent content;
  final int index;

  AddContentCommand({required this.layer, required this.content, this.index = -1});

  @override
  void execute() {
    if (index >= 0 && index <= layer.content!.length) {
      layer.content!.insert(index, content);
    } else {
      layer.content!.add(content);
    }
  }

  @override
  void undo() {
    layer.content!.remove(content);
  }

  @override
  String get description => 'Add content';
}

class RemoveContentCommand extends Command {
  final XppLayer layer;
  final XppContent content;
  final int index;

  RemoveContentCommand({required this.layer, required this.content, required this.index});

  @override
  void execute() {
    layer.content!.remove(content);
  }

  @override
  void undo() {
    layer.content!.insert(index, content);
  }

  @override
  String get description => 'Remove content';
}

class ReplaceContentCommand extends Command {
  final XppLayer layer;
  final XppContent oldContent;
  final XppContent newContent;
  final int index;

  ReplaceContentCommand({
    required this.layer,
    required this.oldContent,
    required this.newContent,
    required this.index,
  });

  @override
  void execute() {
    layer.content![index] = newContent;
  }

  @override
  void undo() {
    layer.content![index] = oldContent;
  }

  @override
  String get description => 'Modify content';
}

class AddPageCommand extends Command {
  final XppFile file;
  final XppPage page;
  final int index;

  AddPageCommand({required this.file, required this.page, required this.index});

  @override
  void execute() {
    file.pages!.insert(index, page);
  }

  @override
  void undo() {
    file.pages!.removeAt(index);
  }

  @override
  String get description => 'Add page';
}

class RemovePageCommand extends Command {
  final XppFile file;
  final XppPage page;
  final int index;

  RemovePageCommand({required this.file, required this.page, required this.index});

  @override
  void execute() {
    file.pages!.removeAt(index);
  }

  @override
  void undo() {
    file.pages!.insert(index, page);
  }

  @override
  String get description => 'Remove page';
}
