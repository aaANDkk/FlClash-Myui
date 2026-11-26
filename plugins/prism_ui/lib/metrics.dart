import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/view_scope.dart';

extension AdaptiveSizeExt on num {
  double ap(BuildContext context) => this * _adaptiveScaleOf(context);

  double mAp(BuildContext context) => this * min(_adaptiveScaleOf(context), 1);
}

double _adaptiveScaleOf(BuildContext context) =>
    1 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 0.5;

EdgeInsets baseInfoEdgeInsetsOf(BuildContext context) =>
    EdgeInsets.all(16.mAp(context));

/// Spaces a page's self-drawn sections, each an `InfoHeader` over its
/// content; a grouped list spaces its sections by [listSectionGap] instead.
const infoSectionSpacing = 16.0;

/// Where a self-drawn section's content starts below its `InfoHeader`.
const infoSectionContentGap = 8.0;

/// Pads a small card of figures set among a list's sections, tighter than a
/// page's own cards.
const figureCardPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

/// The least a section's header leaves above its rows.
const listHeaderGap = 6.0;

/// A control that switches a page between its views.
const viewSwitcherHeight = 44.0;

/// A glyph set inline with footnote text.
const footnoteGlyphSize = 14.0;

/// iOS 27 sets these by the width of the view a list spans, not the list's.
@immutable
class ListInsets {
  const ListInsets._({required this.margin, required this.leading});

  static const compact = ListInsets._(margin: 16, leading: 16);
  static const regular = ListInsets._(margin: 20, leading: 16);
  static const wide = ListInsets._(margin: 20, leading: 20);

  final double margin;

  final double leading;

  double get trailing => margin;

  static ListInsets forWidth(double width) {
    if (width > 402) return wide;
    if (width >= 400) return regular;
    return compact;
  }

  static ListInsets of(BuildContext context) =>
      ViewScope.listInsetsOf(context) ??
      forWidth(MediaQuery.sizeOf(context).width);

  EdgeInsets page({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(margin, top, margin, bottom);

  @override
  bool operator ==(Object other) =>
      other is ListInsets && other.margin == margin && other.leading == leading;

  @override
  int get hashCode => Object.hash(margin, leading);
}

const listSectionGap = 35.0;

EdgeInsets listHeaderPaddingOf(BuildContext context) {
  final leading = ListInsets.of(context).leading;
  return EdgeInsets.fromLTRB(leading, listSectionGap, leading, listHeaderGap) *
      1.mAp(context);
}

/// iOS's least tap target, under any text size.
const listRowMinHeight = 44.0;
const listRowVerticalPadding = 15.5;
const listTwoLineRowVerticalPadding = 10.0;

/// How tall a `ListRow` stands around a title and an optional subtitle this
/// tall, by default padded as one line or two.
double listRowExtent({
  required double titleHeight,
  double? subtitleHeight,
  double minHeight = listRowMinHeight,
  double? verticalPadding,
}) {
  final padding =
      verticalPadding ??
      (subtitleHeight == null
          ? listRowVerticalPadding
          : listTwoLineRowVerticalPadding);
  return max(minHeight, titleHeight + (subtitleHeight ?? 0) + 2 * padding);
}

/// A row's leading glyph slot: its center 12 past the inset, the title 40.
const listLeadingSlotWidth = 24.0;
const pageToolbarHeight = 72.0;
const sheetToolbarHeight = 48.0;
const sheetAppBarHeight = 68.0;

/// Where a page's content starts below its app bar.
const appBarContentGap = 12.0;

/// How far into a page's bar a banner rests: 8 below a root page's title,
/// whose line ends 51 into the bar, and clear of the bar's 44 buttons.
const bannerBarClearance = 59.0;

const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
