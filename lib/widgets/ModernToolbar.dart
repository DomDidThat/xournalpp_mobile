import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:xournalpp/generated/l10n.dart';
import 'package:xournalpp/src/XppBackground.dart';
import 'package:xournalpp/widgets/ToolBoxBottomSheet.dart';

class ModernToolbar extends StatefulWidget {
  final Map<PointerDeviceKind?, EditingTool> deviceMap;
  final Color color;
  final double currentWidth;
  final Function(Map<PointerDeviceKind?, EditingTool>) onNewDeviceMap;
  final Function(Color) onColorChanged;
  final Function(EditingTool, double) onWidthChanged;
  final Function(XppBackground) onBackgroundChange;

  const ModernToolbar({
    Key? key,
    required this.deviceMap,
    required this.color,
    required this.currentWidth,
    required this.onNewDeviceMap,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onBackgroundChange,
  }) : super(key: key);

  @override
  ModernToolbarState createState() => ModernToolbarState();
}

class ModernToolbarState extends State<ModernToolbar> {
  PointerDeviceKind? currentDevice;
  bool _showSubPanel = false;

  static const _defaultColors = <Color>[
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.white,
  ];

  // Presets: (label, strokeWidth). Visual thickness is computed from value.
  static const _penPresets = [
    ('X-Fine', 0.5),
    ('Fine', 1.5),
    ('Medium', 3.0),
    ('Thick', 6.0),
    ('Bold', 12.0),
    ('Broad', 20.0),
  ];

  static const _highlightPresets = [
    ('Fine', 3.0),
    ('Medium', 8.0),
    ('Thick', 16.0),
    ('Bold', 28.0),
    ('Block', 40.0),
  ];

  static const _eraserPresets = [
    ('Tiny', 5.0),
    ('Small', 15.0),
    ('Medium', 30.0),
    ('Large', 50.0),
    ('X-Large', 70.0),
  ];

  void setCurrentDevice(PointerDeviceKind? kind) {
    setState(() => currentDevice = kind);
  }

  void closeSubPanel() {
    if (_showSubPanel) setState(() => _showSubPanel = false);
  }

  EditingTool get _activeTool =>
      widget.deviceMap[currentDevice] ?? EditingTool.MOVE;

  bool get _isDrawingTool =>
      _activeTool == EditingTool.STYLUS ||
      _activeTool == EditingTool.HIGHLIGHT ||
      _activeTool == EditingTool.ERASER;

  (double, double) get _widthRange {
    switch (_activeTool) {
      case EditingTool.ERASER:
      case EditingTool.WHITEOUT:
        return (5.0, 70.0);
      case EditingTool.HIGHLIGHT:
        return (2.0, 40.0);
      default:
        return (0.5, 20.0);
    }
  }

  List<(String, double)> get _activePresets {
    switch (_activeTool) {
      case EditingTool.ERASER:
      case EditingTool.WHITEOUT:
        return _eraserPresets;
      case EditingTool.HIGHLIGHT:
        return _highlightPresets;
      default:
        return _penPresets;
    }
  }

  double _displayThickness(double value) {
    final max = _widthRange.$2;
    return (value / max * 14.0).clamp(1.5, 14.0);
  }

  bool _isActivePreset(double presetValue) =>
      (widget.currentWidth - presetValue).abs() < 0.25;

  void _selectTool(EditingTool tool) {
    HapticFeedback.selectionClick();
    if (_activeTool == tool && _isDrawingTool) {
      setState(() => _showSubPanel = !_showSubPanel);
    } else {
      setState(() {
        widget.deviceMap[currentDevice] = tool;
        _showSubPanel = false;
      });
      widget.onNewDeviceMap(widget.deviceMap);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => currentDevice = event.kind,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPill(context),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showSubPanel
                ? _buildSubPanel(context)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.tab_unselected,
            active: _activeTool == EditingTool.SELECT,
            onTap: () => _selectTool(EditingTool.SELECT),
          ),
          _ToolButton(
            icon: Icons.edit,
            active: _activeTool == EditingTool.STYLUS,
            onTap: () => _selectTool(EditingTool.STYLUS),
          ),
          _ToolButton(
            icon: Icons.brush,
            active: _activeTool == EditingTool.HIGHLIGHT,
            onTap: () => _selectTool(EditingTool.HIGHLIGHT),
          ),
          _ToolButton(
            icon: Icons.backspace,
            active: _activeTool == EditingTool.ERASER,
            onTap: () => _selectTool(EditingTool.ERASER),
          ),
          _ToolButton(
            icon: Icons.pan_tool,
            active: _activeTool == EditingTool.MOVE,
            onTap: () => _selectTool(EditingTool.MOVE),
          ),
          _ToolButton(
            icon: Icons.keyboard,
            active: _activeTool == EditingTool.TEXT,
            onTap: () => _selectTool(EditingTool.TEXT),
          ),
          _ToolButton(
            icon: Icons.science,
            active: _activeTool == EditingTool.LATEX,
            onTap: () => _selectTool(EditingTool.LATEX),
          ),
          const VerticalDivider(
              width: 16, thickness: 1, indent: 10, endIndent: 10),
          ..._buildColorSwatches(context),
          const VerticalDivider(
              width: 16, thickness: 1, indent: 10, endIndent: 10),
          _buildMoreButton(context),
        ],
      ),
    );
  }

  List<Widget> _buildColorSwatches(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceDark = theme.colorScheme.surface.computeLuminance() < 0.5;
    final iconColor = surfaceDark ? Colors.white70 : Colors.black54;
    return [
      for (final color in _defaultColors)
        GestureDetector(
          onTap: () => widget.onColorChanged(color),
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.toARGB32() == color.toARGB32()
                    ? theme.colorScheme.primary
                    : Colors.grey.withValues(alpha: 0.4),
                width:
                    widget.color.toARGB32() == color.toARGB32() ? 2.5 : 1.0,
              ),
            ),
          ),
        ),
      GestureDetector(
        onTap: () => _openColorPicker(context),
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
          ),
          child: Icon(Icons.add, size: 16, color: iconColor),
        ),
      ),
    ];
  }

  Widget _buildMoreButton(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceDark = theme.colorScheme.surface.computeLuminance() < 0.5;
    final iconColor = surfaceDark ? Colors.white70 : Colors.black54;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showModalBottomSheet(
        elevation: 16,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        context: context,
        builder: (_) => ToolBoxBottomSheet(
          onBackgroundChange: widget.onBackgroundChange,
        ),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.more_horiz, color: iconColor),
      ),
    );
  }

  Widget _buildSubPanel(BuildContext context) {
    final theme = Theme.of(context);
    final cardDark = theme.cardColor.computeLuminance() < 0.5;
    final lineColor = cardDark ? Colors.white70 : Colors.black87;
    final presets = _activePresets;
    final (minW, maxW) = _widthRange;
    final clampedWidth = widget.currentWidth.clamp(minW, maxW);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (label, value) in presets)
                    _PresetButton(
                      label: label,
                      value: value,
                      displayThickness: _displayThickness(value),
                      lineColor: lineColor,
                      isActive: _isActivePreset(value),
                      primaryColor: theme.colorScheme.primary,
                      onTap: () {
                        widget.onWidthChanged(_activeTool, value);
                        setState(() => _showSubPanel = false);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Custom slider row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16),
                      ),
                      child: Slider(
                        min: minW,
                        max: maxW,
                        value: clampedWidth,
                        onChanged: (v) {
                          widget.onWidthChanged(_activeTool, v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      clampedWidth.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(S.of(context).selectColor),
        content: SingleChildScrollView(
          child: MaterialPicker(
            pickerColor: widget.color,
            onColorChanged: (color) {
              widget.onColorChanged(color);
              Navigator.of(c).pop();
            },
            enableLabel: true,
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceDark = theme.colorScheme.surface.computeLuminance() < 0.5;
    final inactiveColor = surfaceDark ? Colors.white70 : Colors.black54;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? theme.colorScheme.primary : inactiveColor,
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final double value;
  final double displayThickness;
  final Color lineColor;
  final bool isActive;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.value,
    required this.displayThickness,
    required this.lineColor,
    required this.isActive,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 20,
              child: CustomPaint(
                painter: _LinePainter(
                  thickness: displayThickness,
                  color: isActive ? primaryColor : lineColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive ? primaryColor : null,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final double thickness;
  final Color color;

  const _LinePainter({required this.thickness, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.thickness != thickness || old.color != color;
}
