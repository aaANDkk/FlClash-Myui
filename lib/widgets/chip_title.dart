import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// A small pill a title carries. Every badge a title shows is drawn this way, so
/// an expiry date, a "permanent" label and a source label read as one family.
class TitleChip extends StatelessWidget {
  const TitleChip({
    super.key,
    required this.label,
    required this.color,
    this.tooltip,
  });

  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 2);

  static double widthOf(BuildContext context, String label) =>
      chipLabelWidth(context, label) + _padding.horizontal;

  final String label;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: color.opacity15,
        shape: AppShape.full,
      ),
      child: Padding(
        padding: _padding,
        child: Text(
          label,
          maxLines: 1,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .copyWith(color: color),
        ),
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip == null) {
      return pill;
    }
    return Tooltip(message: tooltip, child: pill);
  }
}

class ExpireChip extends StatelessWidget {
  final DateTime expire;

  const ExpireChip({super.key, required this.expire});

  static double widthOf(BuildContext context, DateTime expire) =>
      TitleChip.widthOf(context, expire.show);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return TitleChip(
      label: expire.show,
      color: expire.isBeforeNow ? colorScheme.error : colorScheme.primary,
      tooltip: context.appLocalizations.expireTime,
    );
  }
}

/// A title followed by an optional label chip and an expiry chip. The expiry
/// chip gives way before it would squeeze the title below half the row.
class ChipTitle extends StatelessWidget {
  final String title;
  final String? chip;
  final DateTime? expire;
  final String? expireText;
  final TextStyle? style;

  const ChipTitle({
    super.key,
    required this.title,
    this.chip,
    this.expire,
    this.expireText,
    this.style,
  });

  static const _gap = 8.0;

  bool _fitsExpire(BuildContext context, double maxWidth, String label) {
    final chip = this.chip;
    final titleWidth = MeasureScope.of(context)
        .computeTextSize(
          Text(title, style: DefaultTextStyle.of(context).style.merge(style)),
        )
        .width;
    final chipsWidth =
        (chip == null ? 0 : TitleChip.widthOf(context, chip) + _gap) +
        TitleChip.widthOf(context, label) +
        _gap;
    return maxWidth - chipsWidth >= min(titleWidth, maxWidth / 2);
  }

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    final chip = this.chip;
    final expire = this.expire;
    final expireText = this.expireText;
    final text = Text(
      title,
      style: style,
      strutStyle: StrutStyle.fromTextStyle(
        DefaultTextStyle.of(context).style.merge(style),
        forceStrutHeight: true,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textWidthBasis: TextWidthBasis.longestLine,
    );
    final expireLabel = expire?.show ?? expireText;
    if (chip == null && expireLabel == null) {
      return text;
    }
    final colorScheme = context.colorScheme;
    final expireBadge = switch ((expire, expireText)) {
      (final expire?, _) => ExpireChip(expire: expire),
      (null, final text?) => TitleChip(
          label: text,
          color: colorScheme.primary,
        ),
      _ => null,
    };
    Widget row({required bool showExpire}) => Row(
      spacing: _gap,
      children: [
        Flexible(child: text),
        if (chip != null)
          TitleChip(label: chip, color: colorScheme.primary),
        if (showExpire && expireBadge != null) expireBadge,
      ],
    );
    if (expireLabel == null) {
      return row(showExpire: false);
    }
    return LayoutBuilder(
      builder: (context, constraints) =>
          row(showExpire: _fitsExpire(context, constraints.maxWidth, expireLabel)),
    );
  }
}
