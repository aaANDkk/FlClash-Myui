part of 'list.dart';

bool _isEnd(ItemPosition? position) =>
    position == ItemPosition.end || position == ItemPosition.startAndEnd;

BorderRadius listItemRadiusOf(ItemPosition? position) {
  final isStart =
      position == ItemPosition.start || position == ItemPosition.startAndEnd;
  return AppRadius.vertical(
    top: isStart ? AppCorner.listGroup : AppCorner.none,
    bottom: _isEnd(position) ? AppCorner.listGroup : AppCorner.none,
  );
}

/// Overrides the resting background fill of descendant [DecorationListItem]
/// cards, e.g. transparent inside a shared translucent frosted card.
class ListCardFillScope extends InheritedWidget {
  const ListCardFillScope({
    super.key,
    required this.fill,
    required super.child,
  });

  final Color fill;

  static Color? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListCardFillScope>()?.fill;

  @override
  bool updateShouldNotify(ListCardFillScope oldWidget) =>
      fill != oldWidget.fill;
}

class DecorationListItem extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool? isSelected;
  final double? horizontalTitleGap;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double? minVerticalPadding;
  final ListRowAlignment alignment;

  /// Never under the card's tap target, which would space the row apart from
  /// the rows it groups with.
  final double? minHeight;
  final bool invalid;

  /// Off for rows something else runs through, such as a rail, which a line
  /// under each row would cut.
  final bool separated;

  const DecorationListItem({
    super.key,
    this.contentPadding,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
    this.isSelected,
    this.onPressed,
    this.onLongPress,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.alignment = ListRowAlignment.center,
    this.minHeight,
    this.invalid = false,
    this.separated = true,
  });

  @override
  State<DecorationListItem> createState() => _DecorationListItemState();
}

class _DecorationListItemState extends State<DecorationListItem> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proxy = ProxyDecoratorProvider.of(context);
    final proxyDecorator = proxy?.isProxyDecorator ?? false;
    final sortable = SortableItem.maybeOf(context);
    final sorting = sortable?.sorting ?? false;
    final position = ItemPositionProvider.of(context)?.position;
    final isEnd = _isEnd(position);
    final insets = context.listInsets;
    final minHeight = math.max(
      widget.minHeight ?? context.listRowHeight,
      Card.tapTargetOf(context).height,
    );
    final unscaledRowHeight = listRowExtent(
      titleHeight: ListTextScope.of(context).title.leading,
    );
    final shortRow =
        widget.minHeight != null &&
        widget.subtitle == null &&
        minHeight < unscaledRowHeight;
    final row = _ListRowSeparator(
      separated: widget.separated && !proxyDecorator && !isEnd,
      emphasized: widget.invalid,
      states: _states,
      endIndent: insets.leading,
      child: Card(
        shape: AppShape.of(listItemRadiusOf(position)),
        isError: widget.invalid,
        isSelected: widget.isSelected,
        selectionTint: ListCardFillScope.maybeOf(context),
        padding: EdgeInsets.zero,
        statesController: _states,
        inert: sorting,
        onPressed: proxyDecorator ? null : widget.onPressed,
        onLongPress: proxyDecorator ? null : widget.onLongPress,
        child: _FillsBoundedHeight(
          child: ListRow(
            leading: widget.leading == null
                ? null
                : IgnorePointer(ignoring: sorting, child: widget.leading),
            padding:
                widget.contentPadding ??
                EdgeInsetsDirectional.only(
                  start: insets.leading,
                  end: widget.trailing == null
                      ? insets.leading
                      : insets.trailing,
                ),
            title: _ListRowSeparatorStart(child: widget.title),
            subtitle: widget.subtitle,
            minVerticalPadding:
                widget.minVerticalPadding ??
                (shortRow
                    ? math.max(
                        0.0,
                        listRowVerticalPadding -
                            (unscaledRowHeight - minHeight) / 2,
                      )
                    : null),
            minHeight: minHeight,
            alignment: widget.alignment,
            horizontalTitleGap: widget.horizontalTitleGap,
            trailing: sortable == null
                ? widget.trailing
                : SortableTrailing(item: sortable, child: widget.trailing),
          ),
        ),
      ),
    );
    if (!proxyDecorator) {
      return row;
    }
    // A change of the card's shape eases in over the button's own animation
    // duration, which would trail the lift; the clip follows it frame by frame.
    return ClipRSuperellipse(
      borderRadius: AppRadius.all(AppCorner.listGroup * proxy!.lift),
      child: row,
    );
  }
}

class _FillsBoundedHeight extends SingleChildRenderObjectWidget {
  const _FillsBoundedHeight({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFillsBoundedHeight();
}

class _RenderFillsBoundedHeight extends RenderProxyBox {
  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.hasBoundedHeight
      ? constraints.tighten(height: constraints.maxHeight)
      : constraints;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child?.getDryLayout(_childConstraints(constraints)) ??
      constraints.smallest;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => child?.getDryBaseline(_childConstraints(constraints), baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = child.size;
  }
}

class SelectedDecorationListItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onSelected;
  final VoidCallback onPressed;
  final double? horizontalTitleGap;
  final Widget? leading;
  final bool invalid;
  final double? minVerticalPadding;

  const SelectedDecorationListItem({
    super.key,
    required this.isSelected,
    required this.onSelected,
    this.horizontalTitleGap,
    this.isEditing = false,
    this.invalid = false,
    required this.title,
    required this.onPressed,
    this.minVerticalPadding,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: title,
      minVerticalPadding: minVerticalPadding,
      contentPadding: EdgeInsetsDirectional.only(
        start: context.listInsets.leading,
        end: context.listInsets.trailing - Checkbox.edgeInset,
      ),
      isSelected: isSelected,
      invalid: invalid,
      leading: leading,
      horizontalTitleGap: horizontalTitleGap,
      onPressed: () {
        if (isEditing) {
          onSelected();
          return;
        }
        onPressed();
      },
      subtitle: subtitle,
      trailing: Checkbox(
        value: isSelected,
        isCircle: true,
        onChanged: (_) {
          onSelected();
        },
      ),
    );
  }
}
