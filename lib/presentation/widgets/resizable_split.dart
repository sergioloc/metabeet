import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Divide la pantalla en dos paneles horizontales y redimensionables.
///
/// El panel izquierdo ocupa inicialmente [initialFraction] del ancho total y
/// puede arrastrarse entre [minFraction] y [maxFraction].
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

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onHorizontalDrag});

  final void Function(double delta) onHorizontalDrag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) =>
            onHorizontalDrag(details.delta.dx),
        child: Container(
          width: 8,
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}