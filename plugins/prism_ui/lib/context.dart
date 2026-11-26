import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/color.dart';
import 'package:prism_ui/inherited.dart';
import 'package:prism_ui/list_text.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/theme_data.dart';
import 'package:prism_ui/typography.dart';
import 'package:prism_ui/view_scope.dart';

extension BuildContextExtension on BuildContext {
  bool get isMobileView => ViewScope.isMobileOf(this, listen: false);

  void safeNestedPop<T extends Object?>([T? result]) {
    final nestedPop = SheetProvider.of(this)?.nestedNavigatorPop;
    if (nestedPop != null) {
      return nestedPop(result);
    } else {
      return Navigator.of(this).pop(result);
    }
  }

  bool get isInCompactSheet => SheetProvider.of(this)?.type.isCompact ?? false;

  /// Where a page's app bar ends, for a body built outside the scaffold's.
  double get appBarInset =>
      FloatingBarScope.of(this) ??
      (isInCompactSheet
          ? sheetAppBarHeight
          : MediaQuery.paddingOf(this).top + pageToolbarHeight);

  /// A compact sheet's header already trails its own gap.
  double get contentTopPadding =>
      TopInsetScope.of(this) ??
      (isInCompactSheet ? sheetAppBarHeight : appBarInset + appBarContentGap);

  /// For a page that opens on a section: the section's own gap above it then
  /// lands it where [contentTopPadding] puts any other page's content.
  double get sectionsTopPadding =>
      math.max(0, contentTopPadding - listHeaderPaddingOf(this).top);

  /// What the end of a body scrolls clear of: the system bar the body runs
  /// under and what floats over its foot. A docked search only counts below
  /// the scaffold that docks it.
  double get bottomInset =>
      BottomInsetScope.of(this) + MediaQuery.paddingOf(this).bottom;

  ListInsets get listInsets => ListInsets.of(this);

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  bool get disableAnimations => MediaQuery.disableAnimationsOf(this);

  Duration motionDuration(Duration duration) =>
      disableAnimations ? Duration.zero : duration;

  TextStyle get listTitleStyle => ListTextScope.of(
    this,
  ).title.of(this).copyWith(color: colorScheme.onSurface);

  /// A value at a row's end, set apart from the row's title.
  TextStyle get listValueStyle => ListTextScope.of(
    this,
  ).title.of(this).copyWith(color: colorScheme.onSurfaceVariant);

  TextStyle get listSubtitleStyle => ListTextScope.of(
    this,
  ).subtitle.of(this).copyWith(color: colorScheme.onSurfaceVariant);

  TextStyle get listCaptionStyle => AppTextStyle.footnote
      .of(this)
      .copyWith(color: colorScheme.onSurfaceVariant);

  TextStyle get cardHeaderStyle => AppTextStyle.headline
      .of(this)
      .copyWith(color: colorScheme.onSurfaceVariant.opacity80);
}
