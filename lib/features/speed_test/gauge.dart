import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

const _gaugeMarks = [0.0, 5.0, 10.0, 50.0, 100.0, 250.0, 500.0, 750.0, 1000.0];
String speedTestValue(double bps) => bps < 0
    ? '—'
    : bps >= 1e9
    ? (bps / 1e9).toStringAsFixed(2)
    : (bps / 1e6).toStringAsFixed(1);
String speedTestUnit(double bps) => bps >= 1e9 ? 'Gbps' : 'Mbps';
double speedGaugeFraction(double bps) {
  final mbps = bps / 1e6;
  if (mbps <= 0) return 0;
  final segments = _gaugeMarks.length - 1;
  for (var i = 0; i < segments; i++) {
    final low = _gaugeMarks[i], high = _gaugeMarks[i + 1];
    if (mbps <= high) return (i + (mbps - low) / (high - low)) / segments;
  }
  return 1;
}

class SpeedTestGauge extends StatefulWidget {
  const SpeedTestGauge({
    super.key,
    this.state,
    required this.waiting,
    required this.color,
    required this.otherColor,
  });
  final SpeedTestState? state;
  final bool waiting;
  final Color color;
  final Color otherColor;
  @override
  State<SpeedTestGauge> createState() => _SpeedTestGaugeState();
}

class _SpeedTestGaugeState extends State<SpeedTestGauge>
    with TickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final _spinner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final _spinPresence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 150),
  );
  late final _needlePresence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
  );
  bool _initialized = false;
  double _fromFraction = 0;
  double _toFraction = 0;
  double _fromSpeed = 0;
  double _toSpeed = 0;

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener(_onMotionStatus);
    _spinPresence.addStatusListener(_onSpinPresenceStatus);
  }

  void _onMotionStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && widget.waiting) {
      _sync();
    }
  }

  void _onSpinPresenceStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.dismissed) {
      _spinner.reset();
      if (!widget.waiting) {
        _sync();
      }
    }
  }

  SpeedTestPhase? get _phase {
    final state = widget.state;
    return state?.error.isNotEmpty == true ? null : state?.phase;
  }

  bool get _measured {
    final phase = _phase;
    return phase == SpeedTestPhase.download ||
        phase == SpeedTestPhase.upload ||
        phase == SpeedTestPhase.done;
  }

  double get _desiredSpeed {
    if (widget.waiting) return 0;
    final state = widget.state;
    final phase = _phase;
    final raw = phase == SpeedTestPhase.done
        ? state!.download
        : state?.speed ?? 0;
    return raw < 0 ? 0 : raw;
  }

  double get _desiredFraction => speedGaugeFraction(_desiredSpeed);

  double get _currentFraction {
    final t = Curves.easeOutCubic.transform(_motion.value);
    return ui.lerpDouble(_fromFraction, _toFraction, t) ?? _toFraction;
  }

  double get _currentSpeed {
    final t = Curves.easeOutCubic.transform(_motion.value);
    return ui.lerpDouble(_fromSpeed, _toSpeed, t) ?? _toSpeed;
  }

  void _startSpin({required bool immediate}) {
    if (immediate) {
      _spinner.reset();
      _spinPresence.value = 1;
      return;
    }
    if (!_spinner.isAnimating) {
      _spinner.repeat(reverse: true);
    }
    if (_spinPresence.status != AnimationStatus.forward &&
        _spinPresence.value < 1) {
      unawaited(_spinPresence.forward());
    }
  }

  void _stopSpin({required bool immediate}) {
    if (immediate) {
      _spinner.reset();
      _spinPresence.value = 0;
      return;
    }
    if (_spinPresence.value > 0 &&
        _spinPresence.status != AnimationStatus.reverse) {
      unawaited(_spinPresence.reverse());
    } else if (_spinPresence.value == 0) {
      _spinner.reset();
    }
  }

  void _syncNeedle({required bool immediate}) {
    final show = _measured && !widget.waiting;
    if (immediate) {
      _needlePresence.value = show ? 1 : 0;
      return;
    }
    if (show) {
      if (_needlePresence.status != AnimationStatus.forward &&
          _needlePresence.value < 1) {
        unawaited(_needlePresence.forward());
      }
    } else {
      if (_needlePresence.value > 0 &&
          _needlePresence.status != AnimationStatus.reverse) {
        unawaited(_needlePresence.reverse());
      }
    }
  }

  void _sync({bool initial = false}) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final targetFraction = _desiredFraction;
    final targetSpeed = _desiredSpeed;
    if (initial || disableAnimations) {
      _fromFraction = _toFraction = targetFraction;
      _fromSpeed = _toSpeed = targetSpeed;
      _motion.value = 1;
      _syncNeedle(immediate: disableAnimations || initial);
      if (widget.waiting) {
        _startSpin(immediate: disableAnimations);
      } else {
        _stopSpin(immediate: disableAnimations || initial);
      }
      return;
    }

    if (widget.waiting) {
      _syncNeedle(immediate: false);
      if ((_toFraction - targetFraction).abs() > 0.0001 ||
          (_toSpeed - targetSpeed).abs() > 1) {
        _stopSpin(immediate: false);
        _fromFraction = _currentFraction;
        _toFraction = targetFraction;
        _fromSpeed = _currentSpeed;
        _toSpeed = targetSpeed;
        unawaited(_motion.forward(from: 0));
        return;
      }
      if (_currentFraction <= 0.002 && !_motion.isAnimating) {
        _startSpin(immediate: false);
      }
      return;
    }

    // Clear the probing arc gracefully before restoring progress so the two
    // arcs never overlap on the same track.
    if (_spinPresence.value > 0.001) {
      _stopSpin(immediate: false);
      return;
    }

    _spinner.reset();
    _syncNeedle(immediate: false);
    if ((_toFraction - targetFraction).abs() > 0.0001 ||
        (_toSpeed - targetSpeed).abs() > 1) {
      _fromFraction = _currentFraction;
      _toFraction = targetFraction;
      _fromSpeed = _currentSpeed;
      _toSpeed = targetSpeed;
      unawaited(_motion.forward(from: 0));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initial = !_initialized;
    _initialized = true;
    _sync(initial: initial);
  }

  @override
  void didUpdateWidget(covariant SpeedTestGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _motion.removeStatusListener(_onMotionStatus);
    _spinPresence.removeStatusListener(_onSpinPresenceStatus);
    _motion.dispose();
    _spinner.dispose();
    _spinPresence.dispose();
    _needlePresence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final phase = _phase;
    final waiting = widget.waiting;
    final probing =
        waiting &&
        phase != SpeedTestPhase.connecting &&
        phase != SpeedTestPhase.latency;
    final label = waiting
        ? switch (phase) {
            SpeedTestPhase.connecting => l.speedTestConnecting,
            SpeedTestPhase.latency => l.delay,
            _ => l.speedTestProbing,
          }
        : switch (phase) {
            SpeedTestPhase.download || SpeedTestPhase.done => l.download,
            SpeedTestPhase.upload => l.upload,
            SpeedTestPhase.latency => l.delay,
            SpeedTestPhase.connecting => l.speedTestConnecting,
            _ => l.speedTestReady,
          };
    final measured = _measured;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(320.0, constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            height: width * .96,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _motion,
                  _spinner,
                  _spinPresence,
                  _needlePresence,
                ]),
                builder: (context, _) {
                  final fraction = _currentFraction;
                  final value = _currentSpeed;
                  final spinOpacity = Curves.easeOutCubic.transform(
                    _spinPresence.value,
                  );
                  final needleOpacity = Curves.easeOutCubic.transform(
                    _needlePresence.value,
                  );
                  return CustomPaint(
                    painter: _GaugePainter(
                      fraction: fraction,
                      color: widget.color,
                      startColor: widget.otherColor,
                      trackColor: context.colorScheme.onSurface.withValues(
                        alpha: .06,
                      ),
                      needleColor: const Color(0xff8e8e93),
                      labelStyle: AppTextStyle.body
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                      passedLabelColor: context.colorScheme.onSurface,
                      spin: spinOpacity > 0.001
                          ? Curves.easeInOutSine.transform(_spinner.value)
                          : null,
                      spinOpacity: spinOpacity,
                      needleOpacity: needleOpacity,
                    ),
                    child: Align(
                      alignment: const Alignment(0, .94),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: width * .62),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 5,
                                children: [
                                  if (probing) const ActivityIndicator(size: 12),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    style: AppTextStyle.footnote
                                        .of(context)
                                        .copyWith(
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            !waiting && measured
                                ? speedTestValue(value)
                                : '0.0',
                            style: AppTextStyle.display
                                .of(context, emphasized: true)
                                .toTabular,
                          ),
                          Text(
                            speedTestUnit(waiting ? 0 : value),
                            style: AppTextStyle.footnote
                                .of(context)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color startColor;
  final Color trackColor;
  final Color needleColor;
  final TextStyle labelStyle;
  final Color passedLabelColor;
  final double? spin;
  final double spinOpacity;
  final double needleOpacity;

  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.startColor,
    required this.trackColor,
    required this.needleColor,
    required this.labelStyle,
    required this.passedLabelColor,
    required this.spin,
    required this.spinOpacity,
    required this.needleOpacity,
  });

  static const _start = pi * 0.75;
  static const _sweep = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width / 13;
    final center = Offset(size.width / 2, size.width / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, _start, _sweep, false, stroke..color = trackColor);

    final sweep = _sweep * fraction;
    if (fraction > 0.002) {
      final arcAlpha = (fraction / 0.015).clamp(0.0, 1.0);
      final activeStart = startColor.withValues(alpha: startColor.a * arcAlpha);
      final activeEnd = color.withValues(alpha: color.a * arcAlpha);
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        stroke
          ..color = activeEnd
          ..shader = SweepGradient(
            endAngle: _sweep,
            colors: [activeStart, activeEnd],
            transform: const GradientRotation(_start),
          ).createShader(rect),
      );
      stroke.shader = null;
      // The rounded start cap crosses the sweep shader's seam.
      canvas.drawCircle(
        center + Offset(cos(_start), sin(_start)) * radius,
        strokeWidth / 2,
        Paint()..color = activeStart,
      );
    }

    final spin = this.spin;
    if (spin != null && spinOpacity > 0.001) {
      final length = (pi / 5) * (0.35 + 0.65 * spinOpacity);
      final start = _start + (_sweep - length) * spin;
      final capMargin = strokeWidth / radius;
      final spinStart = startColor.withValues(alpha: startColor.a * spinOpacity);
      final spinEnd = color.withValues(alpha: color.a * spinOpacity);
      canvas.drawArc(
        rect,
        start,
        length,
        false,
        stroke
          ..color = spinEnd
          ..shader = SweepGradient(
            endAngle: length + 2 * capMargin,
            colors: [spinStart, spinEnd],
            transform: GradientRotation(start - capMargin),
          ).createShader(rect),
      );
      stroke.shader = null;
    }

    final labelRadius = radius - strokeWidth / 2 - size.width * 0.085;
    final segments = _gaugeMarks.length - 1;
    for (var i = 0; i < _gaugeMarks.length; i++) {
      final position = i / segments;
      final angle = _start + _sweep * position;
      final mark = _gaugeMarks[i];
      final text = i == segments ? '1G+' : mark.toStringAsFixed(0);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: position <= fraction + 0.001
              ? labelStyle.copyWith(color: passedLabelColor)
              : labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelCenter = center + Offset(cos(angle), sin(angle)) * labelRadius;
      painter.paint(
        canvas,
        labelCenter - Offset(painter.width / 2, painter.height / 2),
      );
    }

    if (needleOpacity <= 0.001) return;
    final angle = _start + sweep;
    final direction = Offset(cos(angle), sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final outer = size.width / 2;
    final base = center - direction * outer * (0.1 * needleOpacity);
    final tip = center + direction * outer * (0.18 + 0.32 * needleOpacity);
    final baseHalf = outer * 0.03;
    final tipHalf = outer * 0.018;
    final needle = Path()
      ..moveTo(base.dx + normal.dx * baseHalf, base.dy + normal.dy * baseHalf)
      ..lineTo(tip.dx + normal.dx * tipHalf, tip.dy + normal.dy * tipHalf)
      ..lineTo(tip.dx - normal.dx * tipHalf, tip.dy - normal.dy * tipHalf)
      ..lineTo(base.dx - normal.dx * baseHalf, base.dy - normal.dy * baseHalf)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..shader = ui.Gradient.linear(
          base,
          tip,
          [
            needleColor.withValues(alpha: 0),
            needleColor.withValues(alpha: 0.35 * needleOpacity),
            needleColor.withValues(alpha: 0.9 * needleOpacity),
          ],
          const [0, 0.4, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.color != color ||
        oldDelegate.startColor != startColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.needleColor != needleColor ||
        oldDelegate.passedLabelColor != passedLabelColor ||
        oldDelegate.spin != spin ||
        oldDelegate.spinOpacity != spinOpacity ||
        oldDelegate.needleOpacity != needleOpacity ||
        oldDelegate.labelStyle != labelStyle;
  }
}
