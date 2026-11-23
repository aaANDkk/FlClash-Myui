import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class VerticalTicketPerforationPainter extends CustomPainter {
  const VerticalTicketPerforationPainter({
    required this.notchColor,
    required this.dashColor,
  });

  final Color notchColor;
  final Color dashColor;

  static const _notchRadius = 9.0;
  static const _dashHeight = 5.0;
  static const _dashGap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    var y = _notchRadius + 6.0;
    final maxY = size.height - _notchRadius - 6.0;
    while (y < maxY) {
      final endY = math.min(y + _dashHeight, maxY);
      canvas.drawLine(Offset(x, y), Offset(x, endY), dashPaint);
      y += _dashHeight + _dashGap;
    }
    final notchPaint = Paint()..color = notchColor;
    canvas.drawCircle(Offset(x, 0), _notchRadius, notchPaint);
    canvas.drawCircle(Offset(x, size.height), _notchRadius, notchPaint);
  }

  @override
  bool shouldRepaint(VerticalTicketPerforationPainter oldDelegate) =>
      oldDelegate.notchColor != notchColor || oldDelegate.dashColor != dashColor;
}
