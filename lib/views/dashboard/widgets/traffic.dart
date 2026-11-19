import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/text_ink.dart';
import 'package:fl_clash/widgets/traffic_chart.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'card.dart';

const _desktopChartLength = 30;

const _phoneChartLength = 40;

const _phoneDirections = [TrafficDirection.download, TrafficDirection.upload];

num _peakOf(Iterable<Traffic> samples, TrafficDirection direction) => samples
    .fold<num>(0, (peak, traffic) => math.max(peak, direction.of(traffic)));

enum TrafficDirection {
  upload,
  download;

  num of(Traffic traffic) => this == upload ? traffic.up : traffic.down;

  Glyph get glyph => this == upload ? AppGlyphs.arrowUp : AppGlyphs.arrowDown;

  String get arrow => this == upload ? '↑' : '↓';

  Color colorOf(BuildContext context) => accentOf(context);

  Color glyphColorOf(BuildContext context) => accentOf(context);

  Color accentOf(BuildContext context) => this == upload
      ? DashboardColors.of(context).complement
      : context.colorScheme.primary;

  String labelOf(BuildContext context) => this == upload
      ? context.appLocalizations.upload
      : context.appLocalizations.download;
}

String _speedUnit(TrafficShow show) => '${show.unit}/s';

class _Figure extends StatelessWidget {
  const _Figure({
    required this.show,
    required this.unit,
    required this.style,
    required this.unitStyle,
  });

  final TrafficShow show;
  final String unit;
  final AppTextStyle style;
  final AppTextStyle unitStyle;

  @override
  Widget build(BuildContext context) {
    final figureStyle = DashboardText.figure(
      context,
      style,
    ).copyWith(fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: figureStyle,
        children: [
          TextSpan(text: show.value),
          TextSpan(
            text: ' $unit',
            style: DashboardText.unit(context, unitStyle),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}

class _SpeedChart extends StatelessWidget {
  const _SpeedChart({required this.direction, required this.traffics});

  final TrafficDirection direction;
  final FixedList<Traffic> traffics;

  @override
  Widget build(BuildContext context) {
    return TrafficBarsChart(
      samples: traffics.list,
      capacity: _desktopChartLength,
      upload: direction == TrafficDirection.upload,
      downColor: TrafficDirection.download.colorOf(context),
      upColor: TrafficDirection.upload.colorOf(context),
      baselineColor: Divider.colorOf(context),
    );
  }
}

/// The upload or the download on its own desktop card.
class SpeedCard extends ConsumerWidget {
  const SpeedCard({super.key, required this.direction});

  final TrafficDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final padding = dashboardCardPadding(density);
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider);
    final total = ref.watch(
      totalTrafficProvider.select((state) => direction.of(state)),
    );
    final current = direction.of(traffics.list.safeLast(const Traffic()));
    final samples = traffics.list;
    final peak = _peakOf(
      samples.skip(math.max(0, samples.length - _desktopChartLength)),
      direction,
    );
    final speed = current.traffic;
    final chart = RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: compact ? 46 : 58,
        child: _SpeedChart(direction: direction, traffics: traffics),
      ),
    );
    return DashboardCard(
      padding: padding,
      semanticLabel: direction.labelOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24 * scale,
              child: Row(
                spacing: 8,
                children: [
                  GlyphIcon(
                    direction.glyph,
                    size: 18,
                    color: direction.glyphColorOf(context),
                  ),
                  Text(
                    direction.labelOf(context),
                    maxLines: 1,
                    style: DashboardText.cardTitle(context),
                  ),
                  Expanded(
                    child: Text(
                      appLocalizations.trafficPeak(
                        '${dashboardTraffic(peak)}/s',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: DashboardText.label(context),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            _Figure(
              show: speed,
              unit: _speedUnit(speed),
              style: compact ? AppTextStyle.largeTitle : AppTextStyle.display,
              unitStyle: AppTextStyle.subheadline,
            ),
            const SizedBox(height: 2),
            Text(
              appLocalizations.trafficTotal(dashboardTraffic(total)),
              maxLines: 1,
              style: DashboardText.label(context),
            ),
            SizedBox(height: compact ? 8 : 10),
            if (constraints.hasBoundedHeight) Expanded(child: chart) else chart,
          ],
        ),
      ),
    );
  }
}

/// The phone's single card: both directions read against one time axis.
class NetworkSpeedCard extends ConsumerWidget {
  const NetworkSpeedCard({super.key});

  static const _chartHeight = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider);
    final total = ref.watch(totalTrafficProvider);
    final latest = traffics.list.safeLast(const Traffic());
    final totals = [
      for (final direction in _phoneDirections)
        '${direction.arrow} ${dashboardTraffic(direction.of(total))}',
    ].join(' ');
    final label = DashboardText.label(context);
    return DashboardCard(
      semanticLabel: appLocalizations.networkSpeed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.speed,
            title: appLocalizations.networkSpeed,
            share: 0.65,
            trailing: [
              Text(
                appLocalizations.trafficTotal(totals),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: label,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _speedSlotWidth(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    for (final direction in _phoneDirections)
                      _SpeedFigure(
                        direction: direction,
                        speed: direction.of(latest),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: double.infinity,
                    height: _chartHeight,
                    child: TrafficBarsChart(
                      samples: traffics.list,
                      capacity: _phoneChartLength,
                      downColor: TrafficDirection.download.accentOf(context),
                      upColor: TrafficDirection.upload.accentOf(context),
                      baselineColor: Divider.colorOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _speedSlotWidth(BuildContext context) {
  final figureStyle = DashboardText.figure(
    context,
    AppTextStyle.title3,
  ).copyWith(fontWeight: FontWeight.w700);
  final unitStyle = DashboardText.unit(context, AppTextStyle.caption1);
  final textScaler = MediaQuery.textScalerOf(context);
  final painter = TextPainter(
    text: TextSpan(
      style: figureStyle,
      children: [
        const TextSpan(text: '888.8'),
        TextSpan(text: ' MB/s', style: unitStyle),
      ],
    ),
    textDirection: Directionality.of(context),
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final ink = _digitInkOf(_speedFigureStyle(context), textScaler);
  final arrowWidth = ink.height * _SpeedArrow._aspectRatio + 5;
  return arrowWidth + painter.width + 2;
}

TextStyle _speedFigureStyle(BuildContext context) => DashboardText.figure(
  context,
  AppTextStyle.title3,
).copyWith(fontWeight: FontWeight.w700);

typedef _DigitInkKey = (TextStyle, double);

final _digitInks = <_DigitInkKey, TextInk>{};
final _measuringDigitInks = <_DigitInkKey>{};

/// Bumped whenever a measurement lands, so figures drawn on the estimate
/// redraw on the real ink.
final _digitInkRevision = ValueNotifier<int>(0);

/// Digits only: a figure's height is its digits', whatever unit follows.
const _inkSample = '0123456789';

_DigitInkKey _digitInkKeyOf(TextStyle style, TextScaler scaler) {
  final plain = style.copyWith(color: const Color(0xFF000000));
  return (plain, scaler.scale(plain.fontSize ?? 14));
}

/// The measured ink if it is known, otherwise a rough estimate while the
/// glyphs are rasterized once in the background.
TextInk _digitInkOf(TextStyle style, TextScaler scaler) {
  final key = _digitInkKeyOf(style, scaler);
  final ink = _digitInks[key];
  if (ink != null) {
    return ink;
  }
  if (_measuringDigitInks.add(key)) {
    measureTextInk(_inkSample, key.$1, scaler).then(
      (ink) {
        _measuringDigitInks.remove(key);
        if (ink != null) {
          _digitInks[key] = ink;
          _digitInkRevision.value++;
        }
      },
      onError: (_) {
        _measuringDigitInks.remove(key);
      },
    );
  }
  return TextInk(key.$2 * 0.72, 0);
}

class _SpeedFigure extends StatelessWidget {
  const _SpeedFigure({required this.direction, required this.speed});

  final TrafficDirection direction;
  final num speed;

  @override
  Widget build(BuildContext context) {
    final show = speed.traffic;
    final figureStyle = _speedFigureStyle(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return ValueListenableBuilder<int>(
      valueListenable: _digitInkRevision,
      builder: (context, _, _) {
        final ink = _digitInkOf(figureStyle, textScaler);
        // The arrow spans exactly the digits' ink: its top on their top, its
        // bottom on their bottom, both found from the same baseline.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              BaselineAt(
                baseline: ink.ascent,
                child: _SpeedArrow(
                  glyph: direction.glyph,
                  color: direction.accentOf(context),
                  height: ink.height,
                  opticalOffset: 0,
                ),
              ),
              const SizedBox(width: 5),
              _Figure(
                show: show,
                unit: _speedUnit(show),
                style: AppTextStyle.title3,
                unitStyle: AppTextStyle.caption1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A compact arrow whose bottom ink aligns flush with the widget's bottom,
/// so [PlaceholderAlignment.baseline] rests the arrow directly on the alphabetic
/// baseline of the adjacent figures without arbitrary pixel translation.
class _SpeedArrow extends StatelessWidget {
  const _SpeedArrow({
    required this.glyph,
    required this.color,
    this.height = 17,
    this.opticalOffset = 0.3,
  });

  final Glyph glyph;
  final Color color;
  final double height;
  final double opticalOffset;

  static const _aspectRatio =
      _SpeedArrowPainter._inkWidth / _SpeedArrowPainter._inkHeight;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: height * _aspectRatio,
      height: height,
      child: CustomPaint(
        painter: _SpeedArrowPainter(
          glyph: glyph,
          color: color,
          opticalOffset: opticalOffset,
        ),
      ),
    );
    if (glyph.matchTextDirection &&
        Directionality.of(context) == TextDirection.rtl) {
      return Transform.flip(flipX: true, child: icon);
    }
    return icon;
  }
}

class _SpeedArrowPainter extends CustomPainter {
  const _SpeedArrowPainter({
    required this.glyph,
    required this.color,
    this.opticalOffset = 0.3,
  });

  final Glyph glyph;
  final Color color;
  final double opticalOffset;

  static const _inkTop = 4.1;
  static const _inkBottom = 19.9;
  static const _inkHeight = _inkBottom - _inkTop;
  static const _inkLeft = 4.6;
  static const _inkRight = 19.4;
  static const _inkWidth = _inkRight - _inkLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _inkHeight;
    canvas.save();
    final dx = (size.width - _inkWidth * scale) / 2 - _inkLeft * scale;
    final dy = -_inkTop * scale + opticalOffset;
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = Glyph.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final shape in glyph.shapes) {
      canvas.drawPath(shape.path, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpeedArrowPainter oldDelegate) =>
      glyph != oldDelegate.glyph ||
      color != oldDelegate.color ||
      opticalOffset != oldDelegate.opticalOffset;
}
