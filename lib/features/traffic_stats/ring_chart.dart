import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@immutable
class RingSegment {
  final double value;
  final Color color;

  const RingSegment({required this.value, required this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RingSegment && value == other.value && color == other.color;

  @override
  int get hashCode => Object.hash(value, color);
}

class RingChart extends StatelessWidget {
  final List<RingSegment> segments;
  final double? total;
  final Color trackColor;
  final Color? innerDiscColor;
  final Widget? centerChild;
  final double size;
  final double strokeWidth;
  final int? tickCount;

  const RingChart({
    super.key,
    required this.segments,
    required this.trackColor,
    this.innerDiscColor,
    this.total,
    this.centerChild,
    this.size = 76,
    this.strokeWidth = 5.8,
    this.tickCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  segments: segments,
                  total: total,
                  trackColor: trackColor,
                  innerDiscColor: innerDiscColor,
                  strokeWidth: strokeWidth,
                  tickCount: tickCount,
                  progress: progress,
                ),
              );
            },
          ),
          ?centerChild,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<RingSegment> segments;
  final double? total;
  final Color trackColor;
  final Color? innerDiscColor;
  final double strokeWidth;
  final int? tickCount;
  final double progress;

  _RingPainter({
    required this.segments,
    required this.total,
    required this.trackColor,
    required this.innerDiscColor,
    required this.strokeWidth,
    required this.tickCount,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final sum = segments.fold<double>(0, (acc, item) => acc + item.value);
    final fullTotal = max(sum, total ?? 0);

    if (tickCount case final count? when count > 0) {
      _paintTicks(canvas, size, center, count, fullTotal);
      return;
    }

    final radius = (size.width - strokeWidth) / 2;
    if (innerDiscColor case final disc?) {
      canvas.drawCircle(
        center,
        radius - strokeWidth * 1.4,
        Paint()..color = disc,
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    if (fullTotal <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final visible = segments.where((item) => item.value > 0).length;
    final hasGap = visible > 1;
    final gap = hasGap ? (strokeWidth + 2.5) / radius : 0.0;
    final availableAngle = 2 * pi - gap * (hasGap ? visible : 0);

    var startAngle = -pi / 2 + gap / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweepAngle = segment.value / fullTotal * availableAngle * progress;
      if (sweepAngle <= 0) continue;
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = segment.color,
      );
      startAngle += sweepAngle + gap;
    }
  }

  void _paintTicks(
    Canvas canvas,
    Size size,
    Offset center,
    int count,
    double fullTotal,
  ) {
    final outerRadius = size.shortestSide / 2 - strokeWidth / 2;
    final innerRadius = max(0.0, outerRadius - strokeWidth * 1.65);
    if (innerDiscColor case final disc?) {
      final discRadius = max(0.0, innerRadius - strokeWidth / 2 - 4.5);
      canvas.drawCircle(center, discRadius, Paint()..color = disc);
    }

    final tickColors = _resolveTickColors(count, fullTotal);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final angle = -pi / 2 + i * (2 * pi / count);
      final dx = cos(angle);
      final dy = sin(angle);
      final t = (progress * count - i).clamp(0.0, 1.0);
      paint.color = fullTotal > 0
          ? Color.lerp(trackColor, tickColors[i], t)!
          : trackColor;
      canvas.drawLine(
        Offset(center.dx + innerRadius * dx, center.dy + innerRadius * dy),
        Offset(center.dx + outerRadius * dx, center.dy + outerRadius * dy),
        paint,
      );
    }
  }

  List<Color> _resolveTickColors(int count, double fullTotal) {
    if (fullTotal <= 0) {
      return List.filled(count, trackColor);
    }
    final active = [
      for (final segment in segments)
        if (segment.value > 0) segment,
    ];
    if (active.isEmpty) {
      return List.filled(count, trackColor);
    }
    final exact = [
      for (final segment in active) segment.value / fullTotal * count,
    ];
    final counts = [for (final v in exact) v.floor()];
    // Reserve at least one tick for every non-zero segment when ticks allow.
    if (active.length <= count) {
      for (var i = 0; i < counts.length; i++) {
        if (counts[i] == 0) counts[i] = 1;
      }
    }
    var assigned = counts.fold<int>(0, (sum, c) => sum + c);
    while (assigned < count) {
      var bestIndex = 0;
      var bestRemainder = -double.infinity;
      for (var i = 0; i < active.length; i++) {
        final remainder = exact[i] - counts[i];
        if (remainder > bestRemainder) {
          bestRemainder = remainder;
          bestIndex = i;
        }
      }
      counts[bestIndex]++;
      assigned++;
    }
    while (assigned > count) {
      var bestIndex = 0;
      var maxCount = -1;
      for (var i = 0; i < counts.length; i++) {
        if (counts[i] > maxCount) {
          maxCount = counts[i];
          bestIndex = i;
        }
      }
      if (maxCount <= 1) break;
      counts[bestIndex]--;
      assigned--;
    }
    final colors = <Color>[];
    for (var i = 0; i < active.length; i++) {
      colors.addAll(List.filled(counts[i], active[i].color));
    }
    while (colors.length < count) {
      colors.add(trackColor);
    }
    return colors;
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.total != total ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.innerDiscColor != innerDiscColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.tickCount != tickCount ||
        !listEquals(oldDelegate.segments, segments);
  }
}
