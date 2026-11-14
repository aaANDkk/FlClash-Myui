import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'ring_chart.dart';
import 'site_icon.dart';

class TrafficStatsScope extends StatelessWidget {
  const TrafficStatsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(visualDensity: VisualDensity.standard),
    child: child,
  );
}

enum TrafficStatsPeriod { day, week, month }

enum TrafficStatsRankTab { domain, process, node, profile }

Color trafficUploadColor(BuildContext context) =>
    DashboardColors.of(context).complement;

Color trafficDownloadColor(BuildContext context) => context.colorScheme.primary;

Color trafficDirectColor(BuildContext context) =>
    DashboardColors.of(context).complement;

String trafficStatsDayKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _weekStart(DateTime date) {
  final d = _dateOnly(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

DateTime _monthEnd(int year, int month) => DateTime(year, month + 1, 0);

(String start, String end) trafficStatsDateRange(
  TrafficStatsPeriod period,
  DateTime anchor,
) {
  final d = _dateOnly(anchor);
  switch (period) {
    case TrafficStatsPeriod.day:
      final key = trafficStatsDayKey(d);
      return (key, key);
    case TrafficStatsPeriod.week:
      final start = _weekStart(d);
      final end = start.add(const Duration(days: 6));
      return (trafficStatsDayKey(start), trafficStatsDayKey(end));
    case TrafficStatsPeriod.month:
      final start = DateTime(d.year, d.month, 1);
      final end = _monthEnd(d.year, d.month);
      return (trafficStatsDayKey(start), trafficStatsDayKey(end));
  }
}

DateTime trafficStatsStepAnchor(
  TrafficStatsPeriod period,
  DateTime anchor,
  int delta,
) {
  final d = _dateOnly(anchor);
  switch (period) {
    case TrafficStatsPeriod.day:
      return d.add(Duration(days: delta));
    case TrafficStatsPeriod.week:
      return d.add(Duration(days: delta * 7));
    case TrafficStatsPeriod.month:
      return DateTime(d.year, d.month + delta, 1);
  }
}

bool trafficStatsCanStepForward(
  TrafficStatsPeriod period,
  DateTime anchor, [
  DateTime? now,
]) {
  final current = _dateOnly(now ?? DateTime.now());
  final d = _dateOnly(anchor);
  switch (period) {
    case TrafficStatsPeriod.day:
      return d.isBefore(current);
    case TrafficStatsPeriod.week:
      return _weekStart(d).isBefore(_weekStart(current));
    case TrafficStatsPeriod.month:
      return d.year < current.year ||
          (d.year == current.year && d.month < current.month);
  }
}

String trafficStatsPeriodLabel(TrafficStatsPeriod period, DateTime anchor) {
  final d = _dateOnly(anchor);
  switch (period) {
    case TrafficStatsPeriod.day:
      return trafficStatsDayKey(d);
    case TrafficStatsPeriod.week:
      final start = _weekStart(d);
      final end = start.add(const Duration(days: 6));
      String mmdd(DateTime v) =>
          '${v.month.toString().padLeft(2, '0')}/${v.day.toString().padLeft(2, '0')}';
      if (start.year != end.year) {
        return '${trafficStatsDayKey(start)} \u2013 ${trafficStatsDayKey(end)}';
      }
      return '${start.year} ${mmdd(start)} \u2013 ${mmdd(end)}';
    case TrafficStatsPeriod.month:
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  }
}

String trafficStatsFormatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  final show = bytes.traffic;
  return '${show.value} ${show.unit}';
}

String trafficStatsFormatAxisBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  final show = bytes.traffic;
  return '${show.value} ${show.unit}';
}

class _GlyphBadge extends StatelessWidget {
  const _GlyphBadge({
    required this.glyph,
    required this.color,
    this.size = 28,
    this.iconSize = 16,
  });

  final Glyph glyph;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: AppShape.all(AppCorner.sm),
      ),
      child: GlyphIcon(glyph, size: iconSize, color: color),
    );
  }
}

class TrafficStatsPeriodBar extends StatelessWidget {
  const TrafficStatsPeriodBar({
    super.key,
    required this.period,
    required this.anchor,
    required this.onPeriodChanged,
    required this.onStep,
  });

  final TrafficStatsPeriod period;
  final DateTime anchor;
  final ValueChanged<TrafficStatsPeriod> onPeriodChanged;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final canForward = trafficStatsCanStepForward(period, anchor);
    final segments = SegmentedControl<TrafficStatsPeriod>(
      segments: [
        (TrafficStatsPeriod.day, l.trafficStatsDay),
        (TrafficStatsPeriod.week, l.trafficStatsWeek),
        (TrafficStatsPeriod.month, l.trafficStatsMonth),
      ],
      value: period,
      onChanged: onPeriodChanged,
    );
    final dateStepper = Card(
      radius: AppCorner.full,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            IconButton(
              icon: const GlyphIcon(AppGlyphs.chevronBack, size: 18),
              onPressed: () => onStep(-1),
            ),
            Expanded(
              child: Text(
                trafficStatsPeriodLabel(period, anchor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyle.subheadline
                    .of(context, emphasized: true)
                    .toTabular,
              ),
            ),
            IconButton(
              icon: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
              onPressed: canForward ? () => onStep(1) : null,
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            children: [
              SizedBox(width: 248, child: segments),
              const SizedBox(width: 12),
              Expanded(child: dateStepper),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [segments, const SizedBox(height: 10), dateStepper],
        );
      },
    );
  }
}

class TrafficStatsDisabledCard extends StatelessWidget {
  const TrafficStatsDisabledCard({super.key, required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlyphBadge(
            glyph: AppGlyphs.dataUsage,
            color: cs.primary,
            size: 56,
            iconSize: 28,
          ),
          const SizedBox(height: 16),
          Text(
            l.trafficStatsDisabled,
            textAlign: TextAlign.center,
            style: AppTextStyle.title3.of(context, emphasized: true),
          ),
          const SizedBox(height: 8),
          Text(
            l.trafficStatsDisabledDesc,
            textAlign: TextAlign.center,
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onEnable,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l.trafficStatsEnable),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrafficStatsDisabledBanner extends StatelessWidget {
  const TrafficStatsDisabledBanner({super.key, required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _GlyphBadge(glyph: AppGlyphs.dataUsage, color: cs.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.trafficStatsDisabled,
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
                const SizedBox(height: 2),
                Text(
                  l.trafficStatsDisabledDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onEnable,
            child: Text(l.trafficStatsEnableAction),
          ),
        ],
      ),
    );
  }
}

class TrafficStatsOverviewCard extends StatelessWidget {
  const TrafficStatsOverviewCard({super.key, required this.result});

  final TrafficStatsResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final upColor = trafficUploadColor(context);
    final downColor = trafficDownloadColor(context);
    final directColor = trafficDirectColor(context);
    final proxyTotal = result.proxyTotal;
    final directTotal = (result.total - proxyTotal).clamp(0, result.total);
    final splitTotal = proxyTotal + directTotal;
    final proxyPct = splitTotal > 0
        ? (proxyTotal * 100 / splitTotal).round()
        : 0;

    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.trafficStatsOverview,
            style: AppTextStyle.headline.of(context, emphasized: true),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.trafficStatsTotal,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        trafficStatsFormatBytes(result.total),
                        style: AppTextStyle.title1
                            .of(context, emphasized: true)
                            .toTabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              RingChart(
                size: 84,
                strokeWidth: 7.5,
                trackColor: cs.surfaceContainerHighest,
                total: splitTotal > 0 ? splitTotal.toDouble() : null,
                segments: [
                  RingSegment(
                    value: proxyTotal.toDouble(),
                    color: cs.primary,
                  ),
                  RingSegment(
                    value: directTotal.toDouble(),
                    color: directColor,
                  ),
                ],
                centerChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$proxyPct%',
                      style: AppTextStyle.subheadline
                          .of(context, emphasized: true)
                          .toTabular,
                    ),
                    Text(
                      l.proxies,
                      style: AppTextStyle.caption2
                          .of(context)
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverviewMetricTile(
                      leading: GlyphIcon(
                        AppGlyphs.arrowDown,
                        size: 13,
                        color: downColor,
                      ),
                      label: l.download,
                      value: trafficStatsFormatBytes(result.down),
                    ),
                    const SizedBox(height: 8),
                    _OverviewMetricTile(
                      leading: GlyphIcon(
                        AppGlyphs.arrowUp,
                        size: 13,
                        color: upColor,
                      ),
                      label: l.upload,
                      value: trafficStatsFormatBytes(result.up),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverviewMetricTile(
                      leading: _OverviewDot(color: cs.primary),
                      label: l.proxies,
                      value: trafficStatsFormatBytes(proxyTotal),
                    ),
                    const SizedBox(height: 8),
                    _OverviewMetricTile(
                      leading: _OverviewDot(color: directColor),
                      label: l.direct,
                      value: trafficStatsFormatBytes(directTotal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewDot extends StatelessWidget {
  const _OverviewDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: ShapeDecoration(color: color, shape: AppShape.full),
    );
  }
}

class _OverviewMetricTile extends StatelessWidget {
  const _OverviewMetricTile({
    required this.leading,
    required this.label,
    required this.value,
  });

  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Row(
      children: [
        SizedBox(width: 14, height: 18, child: Center(child: leading)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          maxLines: 1,
          style: AppTextStyle.subheadline
              .of(context, emphasized: true)
              .toTabular,
        ),
      ],
    );
  }
}

class TrafficStatsTrendCard extends StatefulWidget {
  const TrafficStatsTrendCard({
    super.key,
    required this.points,
    required this.period,
  });

  final List<TrafficStatsPoint> points;
  final TrafficStatsPeriod period;

  @override
  State<TrafficStatsTrendCard> createState() => _TrafficStatsTrendCardState();
}

class _TrafficStatsTrendCardState extends State<TrafficStatsTrendCard> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant TrafficStatsTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points &&
        _selectedIndex != null &&
        _selectedIndex! >= widget.points.length) {
      _selectedIndex = null;
    }
  }

  void _updateIndexFromDx(double dx, double width, double rightPad) {
    final count = widget.points.length;
    if (count == 0) return;
    const leftPad = _TrendBarPainter._leftPad;
    final chartWidth = width - leftPad - rightPad;
    if (chartWidth <= 0) return;
    final rel = ((dx - leftPad) / chartWidth).clamp(0.0, 0.9999);
    final idx = (rel * count).floor().clamp(0, count - 1);
    if (idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  String _pointDisplayLabel(TrafficStatsPoint point) {
    switch (widget.period) {
      case TrafficStatsPeriod.day:
        return '${point.label}:00';
      case TrafficStatsPeriod.week:
        final parts = point.label.split('-');
        return parts.length == 3 ? '${parts[1]}/${parts[2]}' : point.label;
      case TrafficStatsPeriod.month:
        return point.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final upColor = trafficUploadColor(context);
    final downColor = trafficDownloadColor(context);
    final hasAnyTraffic = widget.points.any((p) => p.total > 0);
    final activePoint =
        _selectedIndex != null && _selectedIndex! < widget.points.length
        ? widget.points[_selectedIndex!]
        : null;

    final labelStyle = AppTextStyle.caption2
        .of(context)
        .toTabular
        .copyWith(color: cs.onSurfaceVariant);
    final rightPad = _TrendBarPainter.measureRightPad(
      widget.points,
      labelStyle,
    );

    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.trafficStatsTrend,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headline.of(context, emphasized: true),
                ),
              ),
              const SizedBox(width: 8),
              if (activePoint != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: AppShape.full,
                  ),
                  child: Text(
                    '${_pointDisplayLabel(activePoint)}  \u2193 ${trafficStatsFormatAxisBytes(activePoint.down)}  \u2191 ${trafficStatsFormatAxisBytes(activePoint.up)}',
                    style: AppTextStyle.caption2
                        .of(context, emphasized: true)
                        .toTabular,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendDot(color: downColor, label: l.download),
                    const SizedBox(width: 10),
                    _LegendDot(color: upColor, label: l.upload),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 158,
            child: !hasAnyTraffic
                ? Center(
                    child: Text(
                      l.noData,
                      style: AppTextStyle.subheadline
                          .of(context)
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => MouseRegion(
                      onHover: (e) => _updateIndexFromDx(
                        e.localPosition.dx,
                        constraints.maxWidth,
                        rightPad,
                      ),
                      onExit: (_) {
                        if (_selectedIndex != null) {
                          setState(() => _selectedIndex = null);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _updateIndexFromDx(
                          d.localPosition.dx,
                          constraints.maxWidth,
                          rightPad,
                        ),
                        onHorizontalDragUpdate: (d) => _updateIndexFromDx(
                          d.localPosition.dx,
                          constraints.maxWidth,
                          rightPad,
                        ),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, 158),
                          painter: _TrendBarPainter(
                            points: widget.points,
                            period: widget.period,
                            selectedIndex: _selectedIndex,
                            rightPad: rightPad,
                            downloadColor: downColor,
                            uploadColor: upColor,
                            gridColor: cs.outlineVariant.withValues(alpha: 0.4),
                            highlightColor: cs.primary.withValues(alpha: 0.08),
                            labelStyle: labelStyle,
                            activeLabelStyle: AppTextStyle.caption2
                                .of(context, emphasized: true)
                                .toTabular
                                .copyWith(color: cs.primary),
                          ),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: ShapeDecoration(color: color, shape: AppShape.full),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TrendBarPainter extends CustomPainter {
  _TrendBarPainter({
    required this.points,
    required this.period,
    required this.selectedIndex,
    required this.rightPad,
    required this.downloadColor,
    required this.uploadColor,
    required this.gridColor,
    required this.highlightColor,
    required this.labelStyle,
    required this.activeLabelStyle,
  });

  final List<TrafficStatsPoint> points;
  final TrafficStatsPeriod period;
  final int? selectedIndex;
  final double rightPad;
  final Color downloadColor;
  final Color uploadColor;
  final Color gridColor;
  final Color highlightColor;
  final TextStyle labelStyle;
  final TextStyle activeLabelStyle;

  static const _leftPad = 4.0;
  static const _minRightPad = 46.0;
  static const _topPad = 10.0;
  static const _bottomPad = 24.0;
  static const _axisGap = 8.0;
  static const _unitNames = ['B', 'KB', 'MB', 'GB', 'TB'];
  static const _niceSteps = [
    1.0,
    1.2,
    1.6,
    2.0,
    2.4,
    3.0,
    4.0,
    5.0,
    6.0,
    8.0,
    10.0,
  ];

  static ({int maxBytes, String topLabel, String midLabel}) _scaleOf(
    List<TrafficStatsPoint> points,
  ) {
    var rawMax = 0;
    for (final p in points) {
      if (p.total > rawMax) rawMax = p.total;
    }
    if (rawMax <= 0) {
      return (maxBytes: 1, topLabel: '1 B', midLabel: '0.5 B');
    }
    var factor = 1.0;
    var unitIdx = 0;
    while (rawMax / factor >= 1024 && unitIdx < _unitNames.length - 1) {
      factor *= 1024;
      unitIdx++;
    }
    final val = rawMax / factor;
    final mag = math
        .pow(10, (math.log(val) / math.ln10).floor())
        .toDouble();
    final norm = val / mag;
    var step = 10.0;
    for (final candidate in _niceSteps) {
      if (norm <= candidate + 1e-9) {
        step = candidate;
        break;
      }
    }
    final topVal = step * mag;
    final midVal = topVal / 2;
    final maxBytes = math.max(rawMax, (topVal * factor).round());
    final decimals = unitIdx == 0 ? 0 : 1;
    final unit = _unitNames[unitIdx];
    return (
      maxBytes: maxBytes,
      topLabel: '${topVal.fixed(decimals: decimals)} $unit',
      midLabel: '${midVal.fixed(decimals: decimals)} $unit',
    );
  }

  static double measureRightPad(
    List<TrafficStatsPoint> points,
    TextStyle labelStyle,
  ) {
    final scale = _scaleOf(points);
    var maxWidth = 0.0;
    for (final text in ['0', scale.topLabel, scale.midLabel]) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxWidth) maxWidth = tp.width;
    }
    return math.max(_minRightPad, maxWidth + _axisGap);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const chartLeft = _leftPad;
    final chartRight = size.width - rightPad;
    const chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final scale = _scaleOf(points);
    final maxTotal = scale.maxBytes;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.7;
    final dashPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.7;

    const steps = 2;
    for (var s = 0; s <= steps; s++) {
      final frac = s / steps;
      final y = chartBottom - chartHeight * frac;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final label = s == 0
          ? '0'
          : s == steps
          ? scale.topLabel
          : scale.midLabel;
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(chartRight + _axisGap, math.max(0.0, y - tp.height / 2)),
      );
    }

    final count = points.length;
    final slotWidth = chartWidth / count;
    final guideBottom = math.min(size.height - 2.0, chartBottom + 20.0);
    for (final boundary in _verticalGuideIndices(count)) {
      final x = chartLeft + boundary * slotWidth;
      _drawDashedVerticalLine(canvas, x, chartTop, guideBottom, dashPaint);
    }

    final barWidth = math.max(
      3.0,
      math.min(
        count <= 10 ? 28.0 : 14.0,
        slotWidth * (count <= 10 ? 0.56 : 0.62),
      ),
    );
    final downPaint = Paint()..color = downloadColor;
    final upPaint = Paint()..color = uploadColor;
    final cornerRadius = math.min(
      count <= 10 ? 4.0 : 2.8,
      barWidth * 0.25,
    );
    final topRadius = Radius.circular(cornerRadius);
    const minSegH = 3.0;

    for (var i = 0; i < count; i++) {
      final point = points[i];
      final slotLeft = chartLeft + i * slotWidth;
      final cx = slotLeft + slotWidth / 2;
      final isSelected = selectedIndex == i;

      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(slotLeft, chartTop, slotWidth, chartHeight),
            const Radius.circular(6),
          ),
          Paint()..color = highlightColor,
        );
      }

      if (point.total > 0) {
        var totalH = 0.0;
        var downH = 0.0;
        var upH = 0.0;
        if (point.up > 0 && point.down > 0) {
          final rawH = (point.total / maxTotal) * chartHeight;
          final minBothH = math.min(chartHeight, 2 * minSegH + 1.5);
          totalH = math.max(rawH, minBothH).clamp(minBothH, chartHeight).toDouble();
          final extra = math.max(0.0, totalH - 2 * minSegH);
          downH = minSegH + extra * (point.down / point.total);
          upH = totalH - downH;
        } else if (point.down > 0) {
          final minSingle = math.min(chartHeight, minSegH);
          downH = math
              .max((point.down / maxTotal) * chartHeight, minSingle)
              .clamp(minSingle, chartHeight)
              .toDouble();
          totalH = downH;
        } else if (point.up > 0) {
          final minSingle = math.min(chartHeight, minSegH);
          upH = math
              .max((point.up / maxTotal) * chartHeight, minSingle)
              .clamp(minSingle, chartHeight)
              .toDouble();
          totalH = upH;
        }

        final barLeft = cx - barWidth / 2;
        final barRight = cx + barWidth / 2;
        final barTop = chartBottom - totalH;
        final barClip = RRect.fromLTRBAndCorners(
          barLeft,
          barTop,
          barRight,
          chartBottom,
          topLeft: topRadius,
          topRight: topRadius,
        );

        canvas.save();
        canvas.clipRRect(barClip);
        if (downH > 0) {
          canvas.drawRect(
            Rect.fromLTRB(barLeft, chartBottom - downH, barRight, chartBottom),
            downPaint,
          );
        }
        if (upH > 0) {
          canvas.drawRect(
            Rect.fromLTRB(barLeft, barTop, barRight, chartBottom - downH),
            upPaint,
          );
        }
        canvas.restore();
      }

      if (_shouldShowTick(i, count)) {
        final tp = TextPainter(
          text: TextSpan(
            text: _shortAxisLabel(point.label),
            style: isSelected ? activeLabelStyle : labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final x = period == TrafficStatsPeriod.week
            ? (cx - tp.width / 2)
                  .clamp(chartLeft, math.max(chartLeft, chartRight - tp.width))
                  .toDouble()
            : (slotLeft + 4.0)
                  .clamp(chartLeft, math.max(chartLeft, chartRight - tp.width))
                  .toDouble();
        tp.paint(canvas, Offset(x, chartBottom + 6));
      }
    }
  }

  List<int> _verticalGuideIndices(int count) {
    switch (period) {
      case TrafficStatsPeriod.day:
        return [
          for (var i = 0; i < count; i += 6) i,
          count,
        ];
      case TrafficStatsPeriod.week:
        return [for (var i = 0; i <= count; i++) i];
      case TrafficStatsPeriod.month:
        return [
          for (var i = 0; i < count; i += 7)
            if (i == 0 || count - i >= 4) i,
          count,
        ];
    }
  }

  void _drawDashedVerticalLine(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Paint paint,
  ) {
    const dash = 2.5;
    const gap = 2.5;
    var y = top;
    while (y < bottom) {
      final nextY = math.min(y + dash, bottom);
      canvas.drawLine(Offset(x, y), Offset(x, nextY), paint);
      y += dash + gap;
    }
  }

  bool _shouldShowTick(int index, int count) {
    switch (period) {
      case TrafficStatsPeriod.day:
        return index == 0 || index == 6 || index == 12 || index == 18;
      case TrafficStatsPeriod.week:
        return true;
      case TrafficStatsPeriod.month:
        return (index % 7 == 0) && (index == 0 || count - index >= 4);
    }
  }

  String _shortAxisLabel(String raw) {
    switch (period) {
      case TrafficStatsPeriod.day:
        return raw;
      case TrafficStatsPeriod.week:
        final parts = raw.split('-');
        return parts.length == 3 ? '${parts[1]}/${parts[2]}' : raw;
      case TrafficStatsPeriod.month:
        final parts = raw.split('-');
        return parts.length == 3
            ? '${int.tryParse(parts[2]) ?? parts[2]}'
            : raw;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendBarPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.period != period ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.rightPad != rightPad ||
      oldDelegate.downloadColor != downloadColor ||
      oldDelegate.uploadColor != uploadColor ||
      oldDelegate.gridColor != gridColor;
}

class TrafficStatsRuleHitsSection extends StatelessWidget {
  const TrafficStatsRuleHitsSection({
    super.key,
    required this.rules,
    required this.totalHits,
    this.horizontalPadding = 16,
  });

  final List<TrafficStatsItem> rules;
  final int totalHits;
  final double horizontalPadding;

  static const _ringPalette = [
    Color(0xFF4C8DFF),
    Color(0xFF34C759),
    Color(0xFFFF9F0A),
    Color(0xFFAF52DE),
    Color(0xFFFF375F),
    Color(0xFF30B0C7),
  ];

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return const SizedBox.shrink();
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final sideInsets = EdgeInsets.symmetric(horizontal: horizontalPadding);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: sideInsets,
          child: ListHeader(title: l.trafficStatsRuleHits),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: sideInsets,
          child: IntrinsicHeight(
            child: Row(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rules.length; i++)
                  _RuleHitCard(
                    item: rules[i],
                    totalHits: totalHits,
                    accent: _ringPalette[i % _ringPalette.length],
                    hitCountText: l.trafficStatsHitCount(rules[i].hits),
                    defaultBadge: l.defaultText,
                    fallbackRuleBadge: l.rule,
                    trackColor: cs.surfaceContainerHighest,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleHitCard extends StatelessWidget {
  const _RuleHitCard({
    required this.item,
    required this.totalHits,
    required this.accent,
    required this.hitCountText,
    required this.defaultBadge,
    required this.fallbackRuleBadge,
    required this.trackColor,
  });

  final TrafficStatsItem item;
  final int totalHits;
  final Color accent;
  final String hitCountText;
  final String defaultBadge;
  final String fallbackRuleBadge;
  final Color trackColor;

  ({String body, String badge}) _splitRuleName(String raw) {
    final sep = raw.indexOf(',');
    if (sep > 0 && sep + 1 < raw.length) {
      return (
        body: raw.substring(sep + 1).trim(),
        badge: raw.substring(0, sep).trim(),
      );
    }
    final upper = raw.trim().toUpperCase();
    return (
      body: raw,
      badge: (upper == 'MATCH' || upper == 'FINAL')
          ? defaultBadge
          : fallbackRuleBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final pct = totalHits > 0 ? (item.hits * 100 / totalHits).round() : 0;
    final rule = _splitRuleName(item.name);
    final captionMuted = AppTextStyle.caption1
        .of(context)
        .toTabular
        .copyWith(color: cs.onSurfaceVariant);
    final captionStrong = AppTextStyle.caption1
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: cs.onSurface);
    return SizedBox(
      width: 244,
      child: Card(
        radius: AppCorner.xl,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RingChart(
                  size: 44,
                  strokeWidth: 4.5,
                  trackColor: trackColor,
                  total: totalHits > 0 ? totalHits.toDouble() : null,
                  segments: [
                    RingSegment(value: item.hits.toDouble(), color: accent),
                  ],
                  centerChild: Text(
                    '$pct%',
                    style: AppTextStyle.caption2
                        .of(context, emphasized: true)
                        .toTabular
                        .copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rule.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline
                        .of(context, emphasized: true)
                        .copyWith(color: cs.onSurface, height: 1.25),
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                  child: const SizedBox(height: 0.5),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: item.name,
                        triggerMode: TooltipTriggerMode.longPress,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: AppShape.xs,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            child: Text(
                              rule.badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.caption2
                                  .of(context, emphasized: true)
                                  .copyWith(color: accent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$hitCountText \u00b7 ',
                              style: captionMuted,
                            ),
                            TextSpan(
                              text: trafficStatsFormatBytes(item.total),
                              style: captionStrong,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TrafficStatsRankingSection extends StatelessWidget {
  const TrafficStatsRankingSection({
    super.key,
    required this.result,
    required this.settings,
    required this.tab,
    required this.onTabChanged,
  });

  final TrafficStatsResult result;
  final TrafficStatsSettings settings;
  final TrafficStatsRankTab tab;
  final ValueChanged<TrafficStatsRankTab> onTabChanged;

  List<TrafficStatsItem> _itemsForTab() {
    switch (tab) {
      case TrafficStatsRankTab.domain:
        return result.hosts;
      case TrafficStatsRankTab.process:
        return result.processes;
      case TrafficStatsRankTab.node:
        return result.nodes;
      case TrafficStatsRankTab.profile:
        return result.profiles;
    }
  }

  Widget _leadingForItem(BuildContext context, TrafficStatsItem item) {
    final cs = context.colorScheme;
    switch (tab) {
      case TrafficStatsRankTab.domain:
        return SiteIcon(
          domain: item.name,
          enabled: settings.siteIcon,
          size: 28,
        );
      case TrafficStatsRankTab.process:
        if (system.isAndroid && item.name.contains('.')) {
          return ClipRRect(
            borderRadius: AppRadius.all(AppCorner.sm),
            child: PackageIcon(packageName: item.name, size: 28),
          );
        }
        return _GlyphBadge(glyph: AppGlyphs.appsList, color: cs.primary);
      case TrafficStatsRankTab.node:
        return _GlyphBadge(glyph: AppGlyphs.connections, color: cs.primary);
      case TrafficStatsRankTab.profile:
        return _GlyphBadge(glyph: AppGlyphs.profiles, color: cs.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final items = _itemsForTab();
    final sumTotal = result.total > 0
        ? result.total
        : items.fold<int>(0, (prev, item) => prev + item.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListHeader(title: l.trafficStatsRanking),
        if (!settings.detail) ...[
          Card(
            radius: AppCorner.lg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                GlyphIcon(AppGlyphs.info, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.trafficStatsDetailOffTip,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SegmentedControl<TrafficStatsRankTab>(
          segments: [
            (TrafficStatsRankTab.domain, l.domain),
            (TrafficStatsRankTab.process, l.process),
            (TrafficStatsRankTab.node, l.trafficStatsNode),
            (TrafficStatsRankTab.profile, l.profile),
          ],
          value: tab,
          onChanged: onTabChanged,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            radius: AppCorner.xl,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Center(
              child: Text(
                l.noData,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          generateGroup([
            for (final item in items)
              DecorationListItem(
                leading: _leadingForItem(context, item),
                title: Row(
                  children: [
                    Expanded(
                      child:
                          tab == TrafficStatsRankTab.node ||
                              tab == TrafficStatsRankTab.profile
                          ? EmojiText(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      trafficStatsFormatBytes(item.total),
                      style: AppTextStyle.subheadline
                          .of(context, emphasized: true)
                          .toTabular,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: AppRadius.full,
                      child: SizedBox(
                        height: 4,
                        width: double.infinity,
                        child: ColoredBox(
                          color: cs.surfaceContainerHighest,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              heightFactor: 1,
                              widthFactor: sumTotal > 0 && item.total > 0
                                  ? (item.total / sumTotal)
                                        .clamp(0.02, 1.0)
                                        .toDouble()
                                  : 0,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: cs.primary,
                                  shape: AppShape.full,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '\u2193 ${trafficStatsFormatBytes(item.down)}   \u2191 ${trafficStatsFormatBytes(item.up)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.caption1
                                .of(context)
                                .toTabular
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sumTotal > 0
                              ? '${(item.total * 100 / sumTotal).toStringAsFixed(1)}%'
                              : '0.0%',
                          style: AppTextStyle.caption2
                              .of(context)
                              .toTabular
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ]),
      ],
    );
  }
}
