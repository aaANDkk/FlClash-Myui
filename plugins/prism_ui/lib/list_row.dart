import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/common_button.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/measure.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/theme_data.dart';
import 'package:prism_ui/typography.dart';

enum ListRowAlignment { center, top }

/// A row laid out as an iOS 27 inset grouped cell, without ink, focus or
/// semantics: the card or row around it answers presses.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.minHeight,
    this.alignment = ListRowAlignment.center,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;

  /// Measured by its intrinsic width, so it cannot hold a LayoutBuilder: laid
  /// out to measure, an AnimatedSize under it would restart every frame.
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double? horizontalTitleGap;
  final double? minVerticalPadding;
  final double? minHeight;
  final ListRowAlignment alignment;

  static const _defaultTitleGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textDirection = Directionality.of(context);
    final safe = MediaQuery.paddingOf(context);
    final inset = padding.resolve(textDirection);
    final titleStyle = context.listTitleStyle;
    final subtitleStyle = context.listSubtitleStyle;
    final sideStyle = AppTextStyle.caption2
        .of(context, emphasized: true)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final iconColor = colorScheme.onSurfaceVariant;
    final buttonTheme = ButtonTheme.of(context);
    // As ListTile does: an icon theme a slot sets must not recolor a button.
    final iconButtonColor =
        buttonTheme.icon?.foregroundColor?.resolve(const {}) ?? iconColor;
    final leading = this.leading;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    // IconTheme.merge and ButtonTheme.merge, without the element each adds.
    final iconTheme =
        context.dependOnInheritedWidgetOfExactType<IconTheme>()?.data ??
        const IconThemeData.fallback();
    return IconTheme(
      data: iconTheme.merge(IconThemeData(color: iconColor)),
      child: ButtonTheme(
        data: ButtonThemeData(
          icon: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(iconButtonColor),
          ),
        ).merge(buttonTheme),
        child: _ListRowLayout(
          padding: EdgeInsets.fromLTRB(
            math.max(safe.left, inset.left),
            math.max(0, inset.top),
            math.max(safe.right, inset.right),
            math.max(0, inset.bottom),
          ),
          textDirection: textDirection,
          horizontalTitleGap: horizontalTitleGap ?? _defaultTitleGap,
          minVerticalPadding:
              minVerticalPadding ??
              (subtitle == null
                  ? listRowVerticalPadding
                  : listTwoLineRowVerticalPadding),
          minHeight: minHeight ?? context.listRowHeight,
          alignment: alignment,
          leading: leading == null
              ? null
              : DefaultTextStyle(style: sideStyle, child: leading),
          title: DefaultTextStyle(style: titleStyle, child: title),
          subtitle: subtitle == null
              ? null
              : DefaultTextStyle(style: subtitleStyle, child: subtitle),
          trailing: trailing == null
              ? null
              : DefaultTextStyle(
                  style: sideStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: trailing,
                ),
        ),
      ),
    );
  }
}

enum _Slot { leading, title, subtitle, trailing }

class _ListRowLayout
    extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _ListRowLayout({
    required this.padding,
    required this.textDirection,
    required this.horizontalTitleGap,
    required this.minVerticalPadding,
    required this.minHeight,
    required this.alignment,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final EdgeInsets padding;
  final TextDirection textDirection;
  final double horizontalTitleGap;
  final double minVerticalPadding;
  final double minHeight;
  final ListRowAlignment alignment;
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
    _Slot.leading => leading,
    _Slot.title => title,
    _Slot.subtitle => subtitle,
    _Slot.trailing => trailing,
  };

  @override
  _RenderListRow createRenderObject(BuildContext context) => _RenderListRow(
    padding: padding,
    textDirection: textDirection,
    horizontalTitleGap: horizontalTitleGap,
    minVerticalPadding: minVerticalPadding,
    minHeight: minHeight,
    alignment: alignment,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderListRow renderObject) {
    renderObject
      ..padding = padding
      ..textDirection = textDirection
      ..horizontalTitleGap = horizontalTitleGap
      ..minVerticalPadding = minVerticalPadding
      ..minHeight = minHeight
      ..alignment = alignment;
  }
}

typedef _Sizes = ({double titleY, BoxConstraints text, Size size});

class _RenderListRow extends RenderBox
    with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderListRow({
    required EdgeInsets padding,
    required TextDirection textDirection,
    required double horizontalTitleGap,
    required double minVerticalPadding,
    required double minHeight,
    required ListRowAlignment alignment,
  }) : _padding = padding,
       _textDirection = textDirection,
       _horizontalTitleGap = horizontalTitleGap,
       _minVerticalPadding = minVerticalPadding,
       _minHeight = minHeight,
       _alignment = alignment;

  static const _minTrailingWidth = 32.0;
  static const _maxSideHeight = 56.0;
  static const _titleMaxWidthFactor = 0.5;

  RenderBox? get _leading => childForSlot(_Slot.leading);
  RenderBox get _title => childForSlot(_Slot.title)!;
  RenderBox? get _subtitle => childForSlot(_Slot.subtitle);
  RenderBox? get _trailing => childForSlot(_Slot.trailing);

  @override
  Iterable<RenderBox> get children => [
    ?_leading,
    ?childForSlot(_Slot.title),
    ?_subtitle,
    ?_trailing,
  ];

  EdgeInsets _padding;

  set padding(EdgeInsets value) {
    if (_padding == value) {
      return;
    }
    _padding = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  double _horizontalTitleGap;

  set horizontalTitleGap(double value) {
    if (_horizontalTitleGap == value) {
      return;
    }
    _horizontalTitleGap = value;
    markNeedsLayout();
  }

  double _minVerticalPadding;

  set minVerticalPadding(double value) {
    if (_minVerticalPadding == value) {
      return;
    }
    _minVerticalPadding = value;
    markNeedsLayout();
  }

  double _minHeight;

  set minHeight(double value) {
    if (_minHeight == value) {
      return;
    }
    _minHeight = value;
    markNeedsLayout();
  }

  ListRowAlignment _alignment;

  set alignment(ListRowAlignment value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    markNeedsLayout();
  }

  Rect _content = Rect.zero;

  double _height(double titleHeight, double? subtitleHeight) => listRowExtent(
    titleHeight: titleHeight,
    subtitleHeight: subtitleHeight,
    minHeight: _minHeight,
    verticalPadding: _minVerticalPadding,
  );

  double _leadingSlot(double width) => math.max(listLeadingSlotWidth, width);

  double _sideExtent(double? height) => switch ((height, _alignment)) {
    (null, _) => 0,
    (final height?, ListRowAlignment.center) => height,
    (final height?, ListRowAlignment.top) => height + 2 * _minVerticalPadding,
  };

  double _rowHeight(
    double titleHeight,
    double? subtitleHeight,
    double? leadingHeight,
    double? trailingHeight,
  ) => math.max(
    _height(titleHeight, subtitleHeight),
    math.max(_sideExtent(leadingHeight), _sideExtent(trailingHeight)),
  );

  double _sideY(double height, double rowHeight) => switch (_alignment) {
    ListRowAlignment.center => (rowHeight - height) / 2,
    ListRowAlignment.top => _minVerticalPadding,
  };

  double _intrinsicWidth(
    double height,
    double Function(RenderBox box, double height) measure,
  ) {
    final inner = math.max(0.0, height - _padding.vertical);
    final leading = _leading;
    final subtitle = _subtitle;
    final trailing = _trailing;
    final leadingWidth = leading == null
        ? 0.0
        : _leadingSlot(measure(leading, inner)) + _horizontalTitleGap;
    return leadingWidth +
        math.max(
          measure(_title, inner),
          subtitle == null ? 0.0 : measure(subtitle, inner),
        ) +
        (trailing == null ? 0.0 : trailing.getMaxIntrinsicWidth(inner)) +
        _padding.horizontal;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth(
    height,
    (box, height) => box.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth(
    height,
    (box, height) => box.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _computeSizes(
    ChildLayoutHelper.dryLayoutChild,
    BoxConstraints(maxWidth: width),
  ).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final parentData = _title.parentData! as BoxParentData;
    return (BaselineOffset(_title.getDistanceToActualBaseline(baseline)) +
            parentData.offset.dy)
        .offset;
  }

  // The title is laid out, not measured: a LayoutBuilder has no intrinsics.
  Size _layoutTrailing(
    RenderBox trailing,
    ChildLayouter layoutChild,
    BoxConstraints loose,
    BoxConstraints sideConstraints,
    double available,
  ) {
    final share = math.max(0.0, available - _horizontalTitleGap);
    final half = share * _titleMaxWidthFactor;
    if (trailing.getMaxIntrinsicWidth(sideConstraints.maxHeight) <= half) {
      return layoutChild(trailing, sideConstraints);
    }
    final title = layoutChild(_title, loose.copyWith(maxWidth: share));
    return layoutChild(
      trailing,
      sideConstraints.copyWith(maxWidth: math.max(share - title.width, half)),
    );
  }

  _Sizes _computeSizes(
    ChildLayouter layoutChild,
    BoxConstraints constraints, {
    void Function(RenderBox child, Offset offset)? position,
  }) {
    final loose = constraints.deflate(_padding).loosen();
    final width = loose.maxWidth;
    final sideConstraints = loose.enforce(
      const BoxConstraints(maxHeight: _maxSideHeight),
    );
    final leading = _leading;
    final subtitle = _subtitle;
    final trailing = _trailing;
    final leadingSize = leading == null
        ? null
        : layoutChild(leading, sideConstraints);
    final titleStart = leadingSize == null
        ? 0.0
        : _leadingSlot(leadingSize.width) + _horizontalTitleGap;
    final trailingSize = trailing == null
        ? null
        : _layoutTrailing(
            trailing,
            layoutChild,
            loose,
            sideConstraints,
            width - titleStart,
          );
    final trailingWidth = trailingSize == null
        ? 0.0
        : math.max(trailingSize.width + _horizontalTitleGap, _minTrailingWidth);
    final text = loose.tighten(width: width - titleStart - trailingWidth);
    final titleHeight = layoutChild(_title, text).height;
    final ltr = _textDirection == TextDirection.ltr;
    final textX = ltr ? titleStart : trailingWidth;
    final subtitleHeight = subtitle == null
        ? null
        : layoutChild(subtitle, text).height;
    final height = constraints
        .deflate(_padding)
        .constrainHeight(
          _rowHeight(
            titleHeight,
            subtitleHeight,
            leadingSize?.height,
            trailingSize?.height,
          ),
        );
    final blockHeight = subtitleHeight == null
        ? titleHeight
        : titleHeight + subtitleHeight;
    final titleY = (height - blockHeight) / 2;
    if (subtitle != null) {
      position?.call(subtitle, Offset(textX, titleY + titleHeight));
    }
    if (position != null) {
      position(_title, Offset(textX, titleY));
      if (leading != null && leadingSize != null) {
        final inset = (_leadingSlot(leadingSize.width) - leadingSize.width) / 2;
        position(
          leading,
          Offset(
            ltr ? inset : width - leadingSize.width - inset,
            _sideY(leadingSize.height, height),
          ),
        );
      }
      if (trailing != null && trailingSize != null) {
        position(
          trailing,
          Offset(
            ltr ? width - trailingSize.width : 0,
            _sideY(trailingSize.height, height),
          ),
        );
      }
    }
    final inner = constraints.deflate(_padding).constrain(Size(width, height));
    return (
      titleY: titleY,
      text: text,
      size: constraints.constrain(
        Size(
          inner.width + _padding.horizontal,
          inner.height + _padding.vertical,
        ),
      ),
    );
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final sizes = _computeSizes(ChildLayoutHelper.dryLayoutChild, constraints);
    return (BaselineOffset(_title.getDryBaseline(sizes.text, baseline)) +
            sizes.titleY +
            _padding.top)
        .offset;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _computeSizes(ChildLayoutHelper.dryLayoutChild, constraints).size;

  @override
  void performLayout() {
    final origin = Offset(_padding.left, _padding.top);
    size = _computeSizes(
      ChildLayoutHelper.layoutChild,
      constraints,
      position: (child, offset) =>
          (child.parentData! as BoxParentData).offset = origin + offset,
    ).size;
    _content = _padding.deflateRect(Offset.zero & size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestSelf(Offset position) => _content.contains(position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) {
        return true;
      }
    }
    return false;
  }
}
