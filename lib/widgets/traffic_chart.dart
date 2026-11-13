import 'dart:math' as math;
import 'package:fl_clash/models/models.dart';
import 'package:flutter/widgets.dart';

const _minSpeedScale = 8 * 1024.0;

/// The shared dashboard and speed test waveform.
class TrafficBarsChart extends StatelessWidget {
  const TrafficBarsChart({
    super.key,
    required this.samples,
    this.capacity = 40,
    this.upload,
    required this.downColor,
    required this.upColor,
    required this.baselineColor,
  });
  final bool? upload;
  final List<Traffic> samples;
  final int capacity;
  final Color downColor;
  final Color upColor;
  final Color baselineColor;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: upload != null
        ? _SingleTrafficBarsPainter(
            samples: samples,
            capacity: capacity,
            upload: upload!,
            color: upload! ? upColor : downColor,
            baselineColor: baselineColor,
          )
        : _TrafficBarsPainter(
            samples: samples,
            capacity: capacity,
            downColor: downColor,
            upColor: upColor,
            baselineColor: baselineColor,
          ),
  );
}

class _TrafficBarsPainter extends CustomPainter {
  const _TrafficBarsPainter({
    required this.samples,
    required this.capacity,
    required this.downColor,
    required this.upColor,
    required this.baselineColor,
  });

  static const _downShare = 0.58;
  static const _barShare = 0.62;
  static const _baselineGap = 2.0;
  static const _oldestOpacity = 0.4;
  static const _minBarLength = 0.01;

  final List<Traffic> samples;
  final int capacity;
  final Color downColor;
  final Color upColor;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * _downShare;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = baselineColor,
    );
    final step = size.width / capacity;
    final barWidth = step * _barShare;
    final inset = _baselineGap + barWidth / 2;
    final downScale = _scaleOf(true);
    final upScale = _scaleOf(false);
    final downRoom = baseline - inset - barWidth / 2;
    final upRoom = size.height - baseline - inset - barWidth / 2;
    final bar = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    for (var age = 0; age < capacity; age++) {
      final sample = age < samples.length
          ? samples[samples.length - 1 - age]
          : const Traffic();
      final x = size.width - step * (age + 0.5);
      final opacity = 1 - (1 - _oldestOpacity) * age / (capacity - 1);
      final top = baseline - inset;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top - _barLength(sample.down / downScale * downRoom)),
        bar..color = downColor.withValues(alpha: opacity),
      );
      final bottom = baseline + inset;
      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, bottom + _barLength(sample.up / upScale * upRoom)),
        bar..color = upColor.withValues(alpha: opacity),
      );
    }
  }

  /// A renderer may drop a zero-length line, caps included, and an idle second
  /// still has to show its dot.
  double _barLength(double length) => math.max(length, _minBarLength);

  double _scaleOf(bool download) => math.max(
    _minSpeedScale,
    samples
        .skip(math.max(0, samples.length - capacity))
        .fold<double>(
          0,
          (peak, sample) =>
              math.max(peak, (download ? sample.down : sample.up).toDouble()),
        ),
  );

  @override
  bool shouldRepaint(_TrafficBarsPainter oldDelegate) {
    return !identical(oldDelegate.samples, samples) ||
        oldDelegate.capacity != capacity ||
        oldDelegate.downColor != downColor ||
        oldDelegate.upColor != upColor ||
        oldDelegate.baselineColor != baselineColor;
  }
}

class _SingleTrafficBarsPainter extends CustomPainter {
  const _SingleTrafficBarsPainter({
    required this.samples,
    required this.capacity,
    required this.upload,
    required this.color,
    required this.baselineColor,
  });

  static const _barShare = 0.60;
  static const _baselineGap = 2.0;
  static const _oldestOpacity = 0.4;
  static const _minBarLength = 0.01;

  final List<Traffic> samples;
  final int capacity;
  final bool upload;
  final Color color;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 0.5;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = baselineColor,
    );
    final step = size.width / capacity;
    final barWidth = step * _barShare;
    final inset = _baselineGap + barWidth / 2;
    final scale = math.max(
      _minSpeedScale,
      samples
          .skip(math.max(0, samples.length - capacity))
          .fold<double>(
            0,
            (peak, sample) =>
                math.max(peak, (upload ? sample.up : sample.down).toDouble()),
          ),
    );
    final room = math.max(0.0, baseline - inset - barWidth / 2);
    final bar = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final bottom = baseline - inset;
    for (var age = 0; age < capacity; age++) {
      final sample = age < samples.length
          ? samples[samples.length - 1 - age]
          : const Traffic();
      final x = size.width - step * (age + 0.5);
      final opacity = 1 - (1 - _oldestOpacity) * age / (capacity - 1);
      final length = math.max(
        (upload ? sample.up : sample.down) / scale * room,
        _minBarLength,
      );
      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, bottom - length),
        bar..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SingleTrafficBarsPainter oldDelegate) {
    return !identical(oldDelegate.samples, samples) ||
        oldDelegate.capacity != capacity ||
        oldDelegate.upload != upload ||
        oldDelegate.color != color ||
        oldDelegate.baselineColor != baselineColor;
  }
}
