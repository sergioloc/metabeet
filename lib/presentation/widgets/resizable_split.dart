import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two horizontally resizable panels; the left one starts at
/// [initialFraction] and can be dragged within [minFraction]..[maxFraction].
class ResizableSplit extends StatefulWidget {
  const ResizableSplit({
    super.key,
    required this.left,
    required this.right,
    this.initialFraction = 0.25,
    this.minFraction = 0.12,
    this.maxFraction = 0.6,
  });

  final Widget left;
  final Widget right;
  final double initialFraction;
  final double minFraction;
  final double maxFraction;

  @override
  State<ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<ResizableSplit> {
  double _leftFraction = 0.25;

  @override
  void initState() {
    super.initState();
    _leftFraction = widget.initialFraction;
  }

  @override
  void didUpdateWidget(ResizableSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When configuring the split for a different layout (e.g. revealing or
    // hiding the right panel), snap back to the requested initial fraction.
    if (oldWidget.initialFraction != widget.initialFraction) {
      _leftFraction = widget.initialFraction;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final minWidth = math.max(160.0, totalWidth * widget.minFraction);
        final maxWidth = math.max(minWidth, totalWidth * widget.maxFraction);
        var leftWidth =
            (totalWidth * _leftFraction).clamp(minWidth, maxWidth).toDouble();

        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            _ResizeHandle(
              onHorizontalDrag: (delta) {
                setState(() {
                  leftWidth = (leftWidth + delta).clamp(minWidth, maxWidth);
                  if (totalWidth > 0) {
                    _leftFraction = leftWidth / totalWidth;
                  }
                });
              },
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({required this.onHorizontalDrag});

  final void Function(double delta) onHorizontalDrag;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _hovered ? colorScheme.primary : colorScheme.outline;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) =>
            widget.onHorizontalDrag(details.delta.dx),
        child: Container(
          width: 8,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _hovered ? 4 : 2,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: _hovered ? 0.9 : 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
