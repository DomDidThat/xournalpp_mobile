# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Xournal++ Mobile is a Flutter port of the Xournal++ desktop note-taking app. It reads and writes the `.xopp` file format (gzipped XML) across Android, iOS, Web, Linux, Windows, and macOS.

## Commands

```bash
# Run on connected device (mobile/desktop)
flutter run

# Run on web — must use --release; debug mode renders a blank screen
flutter run -d web --release

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Regenerate localization files after editing lib/l10n/*.arb
flutter gen-l10n

# Check for issues
flutter analyze
```

## Architecture

### Data model (`lib/src/`)

The `.xopp` format maps directly to a class hierarchy:

```
XppFile
  └── List<XppPage>
        ├── XppBackground  (solid/lined/ruled/graph/plain, PDF, image)
        └── List<XppLayer>
              └── List<XppContent>  (XppStroke, XppText, XppImage, XppTexImage)
```

- **`XppFile`** owns parsing (`fromPickedFile`) and serialization (`toUint8List`). The file on disk is GZip-compressed UTF-8 XML. Parsing is synchronous and processes images → texts → latexImages → strokes in that order to preserve z-ordering (using a `counter` attribute injected at parse time).
- **`XppContent`** (`lib/src/XppLayer.dart`) is the abstract base for all canvas elements. Every subclass must implement `render()`, `toXmlElement()`, `getOffset()`, `moveBy()`, `shouldSelectAt()`, `inRegion()`, and `eraseWhere()`.
- **`XppBackground`** (`lib/src/XppBackground.dart`) is abstract; solid variants use `CustomPainter`, PDF background is rendered asynchronously via `PDfBackgroundWidget`.

### Pages (`lib/pages/`)

- **`OpenPage`** — home screen. Handles file open, PDF import, recent files list (stored in `SharedPreferences` as JSON under `PreferencesKeys.kRecentFiles`), drag-and-drop on web (`DropFile`), and incoming share intents.
- **`CanvasPage`** — editor. Holds the editing state (current page/layer, tool map, undo stack, zoom). Adapts layout at `width >= 768` (wide: sidebar toolbar; narrow: appbar bottom toolbar). Keyboard shortcuts are defined here via Flutter's `Shortcuts`/`Actions` system (Cmd+S, Cmd+Z, etc.).

### Widgets (`lib/widgets/`)

- **`XppPageStack`** — renders a single page as a Flutter `Stack` of background + `XppLayerStack` widgets. Uses `RepaintBoundary` to support PNG export for thumbnails and sharing.
- **`PointerListener`** — the input layer. Routes `PointerEvent`s to tools based on a `Map<PointerDeviceKind, EditingTool>`. Default assignments: touch → MOVE, stylus → STYLUS, invertedStylus → ERASER, mouse → SELECT. Accumulates stroke points during a drag; on pointer-up, calls `onNewContent` with a completed `XppStroke`.
- **`EditingToolBar`** — per-device-kind tool selector; reads/updates the same device map.
- **`ZoomableWidget`** — wraps Flutter's `InteractiveViewer`; disabled when the active tool is not MOVE.

### Layer contents (`lib/layer_contents/`)

Each content type is self-contained — it knows how to parse from XML, render to a Flutter widget, serialize back to XML, and handle erasing. `XppStroke` is abstract; concrete subclasses are `XppStrokePen`, `XppStrokeHighlight`, and `XppStrokeWhiteout`. `XppStrokePainter` renders with per-point variable width (pressure sensitivity) for pens; highlighters use a flat average width.

### Undo system (`lib/src/UndoStack.dart`)

Command pattern: `UndoStack` holds a list of `Command` objects with a pointer. `CanvasPage` wraps content additions, page additions/removals, etc. in the appropriate `Command` subclass before calling `_undoStack.execute(...)`.

### Platform-conditional file I/O (`lib/src/conditional/`)

`open_file_io.dart` / `open_file_web.dart` / `open_file_generic.dart` are selected at compile time using conditional imports in `OpenPage`:

```dart
import 'package:xournalpp/src/conditional/open_file/open_file_generic.dart'
    if (dart.library.html) '...open_file_web.dart'
    if (dart.library.io) '...open_file_io.dart';
```

`PickedFile` (`lib/src/PickedFile.dart`) abstracts over `file_picker` and platform-specific read/write/delete/export operations.

### Localization

ARB source files live in `lib/l10n/` (en, de, pt). Generated code is in `lib/generated/` — do not edit those files directly. After editing an ARB file, run `flutter gen-l10n`. All user-visible strings must go through `S.of(context)`.

## Key constants

Global theme constants (colors, font sizes, text styles) are defined in `lib/main.dart` and prefixed with `k` (e.g., `kPrimaryColor`, `kBodyFont`). The `.xopp` coordinate system uses points; `XppPageSize.pt2mm()` converts to the Flutter pixel scale used for rendering.
