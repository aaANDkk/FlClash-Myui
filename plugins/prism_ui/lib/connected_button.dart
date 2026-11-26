import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/navigation_dock.dart';
import 'package:prism_ui/press_region.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/typography.dart';

const _selectDuration = Duration(milliseconds: 240);

/// A row of [ConnectedButton]s; the one pressed last paints on top.
class ConnectedButtonGroup extends StatelessWidget {
  const ConnectedButtonGroup({
    super.key,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    required this.children,
  });

  static const double spacing = 3;

  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _RaisedRow(
      crossAxisAlignment: crossAxisAlignment,
      spacing: spacing,
      children: children,
    );
  }
}

class _RaisedRow extends Flex {
  const _RaisedRow({
    super.crossAxisAlignment,
    super.spacing,
    required super.children,
  }) : super(direction: Axis.horizontal);

  @override
  RenderFlex createRenderObject(BuildContext context) {
    return _RenderRaisedRow(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: getEffectiveTextDirection(context),
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      clipBehavior: clipBehavior,
      spacing: spacing,
    );
  }
}

class _RenderRaisedRow extends RenderFlex {
  _RenderRaisedRow({
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
  });

  RenderBox? _raised;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) {
      return;
    }
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final offset = (child.parentData! as FlexParentData).offset;
      if ((offset & child.size).contains(entry.localPosition)) {
        if (child != _raised) {
          _raised = child;
          markNeedsPaint();
        }
        return;
      }
    }
  }

  @override
  void dropChild(RenderObject child) {
    if (child == _raised) {
      _raised = null;
    }
    super.dropChild(child);
  }

  @override
  void defaultPaint(PaintingContext context, Offset offset) {
    void paint(RenderBox child) => context.paintChild(
      child,
      (child.parentData! as FlexParentData).offset + offset,
    );
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child != _raised) {
        paint(child);
      }
    }
    if (_raised case final raised?) {
      paint(raised);
    }
  }
}

/// M3 Expressive connected buttons: the ends round off the group, the inner
/// corners stay tight, and the selected one turns into a full pill. Each one
/// swells under a press.
class ConnectedButton extends StatelessWidget {
  const ConnectedButton({
    super.key,
    required this.selected,
    required this.first,
    required this.last,
    required this.outer,
    required this.inner,
    required this.background,
    required this.onTap,
    required this.semanticLabel,
    required this.builder,
  });

  final bool selected;
  final bool first;
  final bool last;
  final double outer;
  final double inner;
  final Color background;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget Function(Color foreground) builder;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startRest = first ? outer : inner;
    final endRest = last ? outer : inner;
    final colorScheme = context.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: ElasticPress(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: selected ? 1 : 0),
          duration: context.motionDuration(_selectDuration),
          curve: Curves.easeOutCubic,
          builder: (context, amount, child) {
            final start = lerpDouble(startRest, outer, amount)!;
            final end = lerpDouble(endRest, outer, amount)!;
            final shape = AppShape.of(
              BorderRadius.horizontal(
                left: Radius.circular(rtl ? end : start),
                right: Radius.circular(rtl ? start : end),
              ),
            );
            return FocusRing(
              shape: shape,
              standsOff: selected,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: Color.lerp(background, colorScheme.primary, amount),
                  shape: shape,
                ),
                child: PressRegion(
                  shape: shape,
                  overlay: PressRegion.hoverOverlay,
                  onTap: onTap,
                  child: child!,
                ),
              ),
            );
          },
          child: builder(
            selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// [ConnectedButton]s that carry only a label each and share the width, to
/// switch a page between its views.
class ConnectedButtonBar<T> extends StatelessWidget {
  const ConnectedButtonBar({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  static const double _inner = 10;

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final background = context.raisedSurfaceLevel.colorOf(context.colorScheme);
    final style = AppTextStyle.subheadline.of(context, emphasized: true);
    return SizedBox(
      height: viewSwitcherHeight,
      child: ConnectedButtonGroup(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (option, label)) in segments.indexed)
            Expanded(
              child: ConnectedButton(
                selected: option == value,
                first: index == 0,
                last: index == segments.length - 1,
                outer: viewSwitcherHeight / 2,
                inner: _inner,
                background: background,
                semanticLabel: label,
                onTap: () {
                  if (option != value) {
                    onChanged(option);
                  }
                },
                builder: (foreground) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(color: foreground),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
