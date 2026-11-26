import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/builder.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/item_position.dart';
import 'package:prism_ui/prism_list.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/text_style.dart';
import 'package:prism_ui/theme_data.dart';
import 'package:prism_ui/typography.dart';

import 'inherited.dart';

/// A titled section whose header folds its entries away. The entries unfold
/// with the section as [UnfoldMotion] moves them.
class SliverCollapsibleSection extends StatelessWidget {
  final String label;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool collapsible;
  final bool initiallyExpanded;

  const SliverCollapsibleSection({
    super.key,
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
    this.collapsible = true,
    this.initiallyExpanded = true,
  });

  static const _groupKey = Object();

  @override
  Widget build(BuildContext context) {
    return SliverCollapsibleGroups(
      groups: [
        CollapsibleGroup(key: _groupKey, label: label, itemCount: itemCount),
      ],
      itemBuilder: (context, _, index) => itemBuilder(context, index),
      collapsible: collapsible,
      initiallyExpanded: initiallyExpanded,
    );
  }
}

class CollapsibleGroup {
  /// Keeps whether the group is open while the groups around it change.
  final Object key;
  final String label;
  final int itemCount;

  /// Takes the gap before the label only while it lays out wider than
  /// nothing, so it can load what it shows on its own.
  final Widget? leading;
  final Widget? trailing;

  const CollapsibleGroup({
    required this.key,
    required this.label,
    required this.itemCount,
    this.leading,
    this.trailing,
  });
}

/// Folds each of [groups] under its header as [SliverCollapsibleSection]
/// does, building only the headers and entries in view.
class SliverCollapsibleGroups extends StatefulWidget {
  final List<CollapsibleGroup> groups;
  final Widget Function(BuildContext context, int group, int index) itemBuilder;
  final bool collapsible;
  final bool initiallyExpanded;

  final double estimatedItemExtent;

  const SliverCollapsibleGroups({
    super.key,
    required this.groups,
    required this.itemBuilder,
    this.collapsible = true,
    this.initiallyExpanded = false,
    this.estimatedItemExtent = SliverPrismList.defaultEstimatedItemExtent,
  });

  @override
  State<SliverCollapsibleGroups> createState() =>
      _SliverCollapsibleGroupsState();
}

class _SliverCollapsibleGroupsState extends State<SliverCollapsibleGroups>
    with TickerProviderStateMixin {
  static const _header = -1;
  static const _unfolding = -2;

  final _toggled = <Object>{};
  final _controllers = <Object, AnimationController>{};

  /// Keys the entries the unfolding shows, so they move between it and the
  /// settled list without being built again at either end of the motion.
  final _entryKeys = <Object, List<GlobalKey>>{};

  bool _isOpen(Object key, {required bool collapsible}) =>
      !collapsible || widget.initiallyExpanded != _toggled.contains(key);

  void _move(Object key, {required bool open}) {
    final controller = _controllers[key] ??= AnimationController(
      vsync: this,
      value: open ? 0 : 1,
    )..addStatusListener((status) => _settle(key, status));
    UnfoldMotion.run(
      controller,
      open: open,
      animate: !context.disableAnimations,
    );
  }

  void _settle(Object key, AnimationStatus status) {
    if (status.isAnimating) {
      return;
    }
    final controller = _controllers.remove(key);
    if (controller == null) {
      return;
    }
    if (status.isDismissed) {
      _entryKeys.remove(key);
    }
    setState(() {});
    controller.dispose();
  }

  void _toggle(Object key) {
    setState(() {
      if (!_toggled.remove(key)) {
        _toggled.add(key);
      }
    });
    _move(key, open: _isOpen(key, collapsible: widget.collapsible));
  }

  @override
  void didUpdateWidget(SliverCollapsibleGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = {for (final group in widget.groups) group.key};
    _entryKeys.removeWhere((key, _) => !keys.contains(key));
    _controllers.removeWhere((key, controller) {
      if (keys.contains(key)) {
        return false;
      }
      controller.dispose();
      return true;
    });
    if (oldWidget.collapsible == widget.collapsible) {
      return;
    }
    for (final group in widget.groups) {
      final open = _isOpen(group.key, collapsible: widget.collapsible);
      if (open != _isOpen(group.key, collapsible: oldWidget.collapsible)) {
        _move(group.key, open: open);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildEntry(BuildContext context, int group, int index) {
    final keys = _entryKeys[widget.groups[group].key];
    return ItemPositionProvider(
      key: keys != null && index < keys.length ? keys[index] : null,
      position: ItemPosition.get(index, widget.groups[group].itemCount),
      child: widget.itemBuilder(context, group, index),
    );
  }

  int _unfoldingCount(BuildContext context, int group) => math.min(
    widget.groups[group].itemCount,
    MediaQuery.sizeOf(context).height ~/ kMinInteractiveDimension + 1,
  );

  /// An entry is at least [kMinInteractiveDimension] tall, so these fill the
  /// screen whatever lies past them. They move as one block, its bottom
  /// showing first, as [UnfoldMotion] has them.
  Widget _buildUnfolding(BuildContext context, int group) {
    final unfolding = _unfoldingCount(context, group);
    return SizeTransition(
      sizeFactor: _controllers[widget.groups[group].key]!,
      alignment: Alignment.bottomCenter,
      child: RepaintBoundary(
        child: Column(
          children: [
            for (var index = 0; index < unfolding; index++)
              _buildEntry(context, group, index),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CollapsibleGroup group) {
    final collapsible = widget.collapsible;
    final unfold =
        _controllers[group.key] ??
        (_isOpen(group.key, collapsible: collapsible)
            ? kAlwaysCompleteAnimation
            : kAlwaysDismissedAnimation);
    // Unkeyed, so headers update in place as a group jumps to the top.
    return MemoBuilder(
      inputs: [
        group.label,
        group.itemCount,
        group.leading,
        group.trailing,
        unfold,
        collapsible,
      ],
      builder: (_) => CollapsibleHeader(
        label: group.label,
        count: group.itemCount,
        leading: group.leading,
        trailing: group.trailing,
        unfold: unfold,
        onToggle: collapsible ? () => _toggle(group.key) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collapsible = widget.collapsible;
    final rows = <(int, int)>[];
    for (final (index, group) in widget.groups.indexed) {
      rows.add((index, _header));
      final open = _isOpen(group.key, collapsible: collapsible);
      if (open || _controllers.containsKey(group.key)) {
        final keys = _entryKeys[group.key] ??= [];
        final unfolding = _unfoldingCount(context, index);
        while (keys.length < unfolding) {
          keys.add(GlobalKey());
        }
      }
      if (_controllers.containsKey(group.key)) {
        rows.add((index, _unfolding));
      } else if (open) {
        for (var item = 0; item < group.itemCount; item++) {
          rows.add((index, item));
        }
      }
    }
    return SliverPrismList(
      itemCount: rows.length,
      estimatedItemExtent: widget.estimatedItemExtent,
      itemBuilder: (context, row) {
        final (index, item) = rows[row];
        final group = widget.groups[index];
        return switch (item) {
          _header => _buildHeader(group),
          _unfolding => _buildUnfolding(context, index),
          _ => _buildEntry(context, index, item),
        };
      },
    );
  }
}

/// The header of a [SliverCollapsibleGroups] group, its chevron turning with
/// [unfold] from pointing at the label to pointing down; without [onToggle]
/// it has no chevron.
class CollapsibleHeader extends StatefulWidget {
  final String label;
  final int count;
  final Widget? leading;
  final Widget? trailing;
  final Animation<double> unfold;
  final VoidCallback? onToggle;

  const CollapsibleHeader({
    super.key,
    required this.label,
    required this.count,
    this.leading,
    this.trailing,
    required this.unfold,
    this.onToggle,
  });

  @override
  State<CollapsibleHeader> createState() => _CollapsibleHeaderState();
}

class _CollapsibleHeaderState extends State<CollapsibleHeader> {
  static const _spacing = 8.0;

  late final _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => widget.onToggle?.call(),
    ),
  };
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final collapsible = widget.onToggle != null;
    final focused = collapsible && _focused;
    final leading = widget.leading;
    final trailing = widget.trailing;
    final label = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.label),
          TextSpan(
            text: ' ${widget.count}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.headline.of(context),
    );
    return FocusableActionDetector(
      enabled: collapsible,
      actions: _actions,
      mouseCursor: collapsible ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: Semantics(
        button: collapsible,
        expanded: collapsible ? widget.unfold.value > 0 : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: AppShape.md.copyWith(
                  side: focused ? focusRingSide(colorScheme) : BorderSide.none,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  spacing: _spacing,
                  children: [
                    Expanded(
                      child: leading == null
                          ? label
                          : Row(
                              children: [
                                _LeadingGap(gap: _spacing, child: leading),
                                Expanded(child: label),
                              ],
                            ),
                    ),
                    if (trailing != null)
                      DefaultTextStyle.merge(
                        style: AppTextStyle.caption1
                            .of(context)
                            .toTabular
                            .copyWith(color: colorScheme.onSurfaceVariant),
                        child: trailing,
                      ),
                    if (collapsible)
                      RotationTransition(
                        turns: widget.unfold.drive(UnfoldMotion.chevronTurns),
                        child: GlyphIcon(
                          Glyphs.chevronDown,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadingGap extends SingleChildRenderObjectWidget {
  final double gap;

  const _LeadingGap({required this.gap, required super.child});

  @override
  _RenderLeadingGap createRenderObject(BuildContext context) =>
      _RenderLeadingGap(gap, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLeadingGap renderObject,
  ) {
    renderObject
      ..gap = gap
      ..textDirection = Directionality.of(context);
  }
}

/// Lays its child out with [gap] after it in reading order, or as nothing
/// while the child is zero wide.
class _RenderLeadingGap extends RenderShiftedBox {
  _RenderLeadingGap(this._gap, this._textDirection) : super(null);

  double _gap;
  TextDirection _textDirection;

  set gap(double value) {
    if (_gap == value) {
      return;
    }
    _gap = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  double _withGap(double width) => width > 0 ? width + _gap : 0;

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.loosen().deflate(EdgeInsets.only(right: _gap));

  Size _sizeFor(BoxConstraints constraints, Size child) =>
      constraints.constrain(Size(_withGap(child.width), child.height));

  @override
  double computeMinIntrinsicWidth(double height) =>
      _withGap(child?.getMinIntrinsicWidth(height) ?? 0);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _withGap(child?.getMaxIntrinsicWidth(height) ?? 0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    return _sizeFor(
      constraints,
      child.getDryLayout(_childConstraints(constraints)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    final start = _textDirection == TextDirection.rtl
        ? size.width - child.size.width
        : 0.0;
    (child.parentData! as BoxParentData).offset = Offset(start, 0);
  }
}

/// How a group's entries unfold from under its header and fold back, as
/// iOS 27's outline list (`UICellAccessory.outlineDisclosure`) moves them.
///
/// The entries move as one block from behind the header, clipped at its
/// bottom edge, so the block's bottom shows first; they neither fade nor
/// stagger. What follows the group moves with the block's bottom, and the
/// chevron turns from pointing at the label to pointing down.
abstract final class UnfoldMotion {
  /// UIKit's spring for the outline, read from its `CASpringAnimation`s:
  /// critically damped, a 0.25 s response.
  static const spring = SpringDescription(
    mass: 1,
    stiffness: 631.65,
    damping: 50.27,
  );

  /// Ends the motion where UIKit's animation ends, 0.367 s from rest.
  static const _tolerance = Tolerance(distance: 1e-3, velocity: 0.03);

  static final chevronTurns = Tween<double>(begin: -0.25, end: 0);

  /// Moves [controller] toward [open] from where it stands and as fast as it
  /// moves, so a tap during the motion turns it around without a jolt.
  static void run(
    AnimationController controller, {
    required bool open,
    bool animate = true,
  }) {
    final target = open ? 1.0 : 0.0;
    if (!controller.isAnimating && controller.value == target) {
      return;
    }
    // Without motion it still runs, from the target: setting the value alone
    // reports no status when it lands on the one a new controller starts with.
    final simulation = SpringSimulation(
      spring,
      animate ? controller.value : target,
      target,
      animate ? controller.velocity : 0,
      snapToEnd: true,
      tolerance: _tolerance,
    );
    open
        ? controller.animateWith(simulation)
        : controller.animateBackWith(simulation);
  }
}
