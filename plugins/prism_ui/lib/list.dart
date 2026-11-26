import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/checkbox.dart';
import 'package:prism_ui/divider.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/prism_list.dart';
import 'package:prism_ui/focus.dart';
import 'package:prism_ui/inherited.dart';
import 'package:prism_ui/item_position.dart';
import 'package:prism_ui/list_text.dart';
import 'package:prism_ui/measure.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/models.dart';
import 'package:prism_ui/shape.dart';

import 'button.dart';
import 'card.dart';
import 'list_row.dart';
import 'navigation_dock.dart';
import 'scaffold.dart';
import 'sortable.dart';

part 'list_row_separator.dart';
part 'list_selected.dart';

/// A section's title, which grows to fit its action buttons.
class ListHeader extends StatelessWidget {
  static const _actionSize = TonalButtonSize.section;

  final String title;

  /// Sits under [title], and the actions center against the two together.
  final String? caption;
  final List<IconButtonData> actions;
  final Widget? trailing;
  final EdgeInsets? padding;

  /// Drops the gap above, for a list's first section where what holds the
  /// list already spaces it from what sits over it.
  final bool atTop;

  const ListHeader({
    super.key,
    required this.title,
    this.caption,
    this.padding,
    this.actions = const [],
    this.trailing,
    this.atTop = false,
  });

  Widget _buildActions() {
    final grouped = actions.length > 1 ? actions.take(2) : null;
    return TonalButtonTheme(
      size: _actionSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: appBarActionSpace,
        children: [
          if (grouped != null)
            TonalButtonGroup(
              size: _actionSize,
              children: [
                for (final data in grouped) AppBarActionButton(data: data),
              ],
            ),
          for (final data in actions.skip(grouped?.length ?? 0))
            ElasticPress(
              enabled: !data.isLoading && data.onPressed != null,
              child: AppBarActionButton(data: data),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = this.padding ?? listHeaderPaddingOf(context);
    final header = ListTextScope.of(context).header;
    final lineHeight = MeasureScope.of(context).textHeight(header);
    final caption = this.caption;
    final hasActions = actions.isNotEmpty || trailing != null;
    final overhang = caption == null && hasActions
        ? (_actionSize.button - lineHeight) / 2
        : 0.0;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: header
          .of(context, emphasized: true)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding.left,
        atTop ? 0 : math.max(0, padding.top - overhang),
        padding.right,
        hasActions
            ? math.max(listHeaderGap, padding.bottom - overhang)
            : padding.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: hasActions ? _actionSize.button : 0,
        ),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: caption == null
                  ? titleText
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        titleText,
                        Text(caption, style: context.listCaptionStyle),
                      ],
                    ),
            ),
            ?trailing,
            if (actions.isNotEmpty) _buildActions(),
          ],
        ),
      ),
    );
  }
}

/// A section's footnote. Its last line hangs into the gap above the next
/// section, which iOS 27 closes up after a footer: a header's line then starts
/// 16.33 dp under the footer's, where it starts [listSectionGap] under a card.
/// A [last] footer ends its list, so it has no gap below to hang into.
class ListFooter extends StatelessWidget {
  static const _top = 6.5;
  static const _nextHeaderGap = 16.33;

  final String text;
  final bool last;

  const ListFooter({super.key, required this.text, this.last = false});

  @override
  Widget build(BuildContext context) {
    final leading = context.listInsets.leading;
    final scale = 1.mAp(context);
    return _HangingBottom(
      hang: last ? 0 : (listSectionGap - _nextHeaderGap) * scale,
      child: Container(
        alignment: AlignmentDirectional.centerStart,
        padding:
            EdgeInsetsDirectional.fromSTEB(leading, _top, leading, 0) * scale,
        child: Text(text, style: context.listCaptionStyle),
      ),
    );
  }
}

class _HangingBottom extends SingleChildRenderObjectWidget {
  final double hang;

  const _HangingBottom({required this.hang, required super.child});

  @override
  _RenderHangingBottom createRenderObject(BuildContext context) =>
      _RenderHangingBottom(hang);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHangingBottom renderObject,
  ) {
    renderObject.hang = hang;
  }
}

class _RenderHangingBottom extends RenderProxyBox {
  _RenderHangingBottom(this._hang);

  double _hang;

  set hang(double value) {
    if (_hang == value) {
      return;
    }
    _hang = value;
    markNeedsLayout();
  }

  double _shorten(double height) => math.max(0, height - _hang);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _shorten(super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _shorten(super.computeMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final size = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(Size(size.width, _shorten(size.height)));
  }

  @override
  void performLayout() {
    final child = this.child!
      ..layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, _shorten(child.size.height)),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!(Offset.zero & child!.size).contains(position)) {
      return false;
    }
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

class ListSectionGap extends StatelessWidget {
  const ListSectionGap({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: listHeaderPaddingOf(context).top);
  }
}

/// A section's rows alone, for a group under a header its caller lays out.
Widget generateGroup(Iterable<Widget> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...items.mapIndexed<Widget>(
        (index, item) => ItemPositionProvider(
          position: ItemPosition.get(index, items.length),
          child: item,
        ),
      ),
    ],
  );
}

Widget generateSection({
  String? title,
  required Iterable<Widget> items,
  List<IconButtonData> actions = const [],
  String? footer,
  bool atTop = false,
  bool last = false,
}) {
  return Column(
    children: [
      if (items.isNotEmpty)
        if (title != null)
          ListHeader(title: title, actions: actions, atTop: atTop)
        else if (!atTop)
          const ListSectionGap(),
      generateGroup(items),
      if (items.isNotEmpty && footer != null)
        ListFooter(text: footer, last: last),
    ],
  );
}

/// [generateSection] as slivers that build only the rows in view.
Widget generateSliverSection<T>({
  String? title,
  required List<T> items,
  required Widget Function(T item) itemBuilder,
  List<IconButtonData> actions = const [],
  String? footer,
  bool atTop = false,
  bool last = false,
  bool addAutomaticKeepAlives = true,
}) {
  if (items.isEmpty) {
    return const SliverToBoxAdapter();
  }
  return SliverMainAxisGroup(
    slivers: [
      if (title != null)
        SliverToBoxAdapter(
          child: ListHeader(title: title, actions: actions, atTop: atTop),
        )
      else if (!atTop)
        const SliverToBoxAdapter(child: ListSectionGap()),
      SliverPrismList(
        itemCount: items.length,
        addAutomaticKeepAlives: addAutomaticKeepAlives,
        itemBuilder: (_, index) => ItemPositionProvider(
          position: ItemPosition.get(index, items.length),
          child: itemBuilder(items[index]),
        ),
      ),
      if (footer != null)
        SliverToBoxAdapter(
          child: ListFooter(text: footer, last: last),
        ),
    ],
  );
}
