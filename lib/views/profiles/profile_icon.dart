import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/profiles/custom/icon.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Glyph profileDefaultGlyph(ProfileType type) => switch (type) {
  ProfileType.url => AppGlyphs.cloud,
  ProfileType.file => AppGlyphs.profiles,
  ProfileType.custom => AppGlyphs.puzzle,
};

Color profileTypeAccent(BuildContext context, ProfileType type) {
  final colorScheme = context.colorScheme;
  return switch (type) {
    ProfileType.url => colorScheme.primary,
    ProfileType.file => DashboardColors.of(context).complement,
    ProfileType.custom => colorScheme.tertiary,
  };
}

String profileTypeStamp(BuildContext context, ProfileType type) {
  final l = context.appLocalizations;
  return switch (type) {
    ProfileType.url => l.remote,
    ProfileType.file => 'YAML',
    ProfileType.custom => l.custom,
  };
}

Future<void> openProfileIconPicker(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final current = ref.read(profileIconProvider(profile.id));
  final value = await showNestedSheet<String>(
    context,
    builder: (_) => IconPickerView(
      value: current.isEmpty ? null : current,
      groupName: profile.realLabel,
    ),
  );
  if (value == null) {
    return;
  }
  ref.read(profileIconsProvider.notifier).setIcon(profile.id, value);
}

/// Official concentric icon plate for a profile, rendering either a user-picked
/// icon from the built-in icon sets or one of the 3 distinct type glyphs.
class ProfileIconBadge extends ConsumerWidget {
  const ProfileIconBadge({
    super.key,
    required this.profile,
    this.size = 40,
    this.radius,
    this.onTap,
  });

  final Profile profile;
  final double size;
  final double? radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customSrc = ref.watch(profileIconProvider(profile.id));
    final fill = DashboardColors.of(context).tone;
    final accent = profileTypeAccent(context, profile.type);
    final cornerRadius = radius ?? (size >= 44 ? AppCorner.xl - 10 : AppCorner.xl - 12);
    final glyphSize = size * 0.48;
    final fallback = Center(
      child: GlyphIcon(
        profileDefaultGlyph(profile.type),
        size: glyphSize,
        color: accent,
      ),
    );
    final inner = SizedBox.square(
      dimension: size,
      child: customSrc.isEmpty
          ? fallback
          : Padding(
              padding: EdgeInsets.all(size >= 44 ? 7 : 6),
              child: IconTheme.merge(
                data: IconThemeData(size: glyphSize, color: accent),
                child: CommonTargetIcon(
                  src: customSrc,
                  fallback: fallback,
                  rasterizeSvg: true,
                ),
              ),
            ),
    );
    final shape = AppShape.all(cornerRadius);
    final onTap = this.onTap;
    if (onTap == null) {
      return Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(color: fill, shape: shape),
        clipBehavior: Clip.antiAlias,
        child: inner,
      );
    }
    return Tooltip(
      message: context.appLocalizations.customIcon,
      child: PressSurface(
        fill: fill,
        shape: shape,
        clipsChild: true,
        onPressed: onTap,
        child: inner,
      ),
    );
  }
}

/// Thin circular progress ring for remote profile cards with traffic data.
class ProfileTrafficRing extends StatelessWidget {
  const ProfileTrafficRing({
    super.key,
    required this.share,
    this.size = 28,
    this.strokeWidth = 3.0,
  });

  final double share;
  final double size;
  final double strokeWidth;

  static const _nearlyUsedShare = 0.9;

  @override
  Widget build(BuildContext context) {
    final colors = DashboardColors.of(context);
    final active = share >= _nearlyUsedShare
        ? colors.warn
        : context.colorScheme.primary;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TrafficRingPainter(
          share: share.clamp(0.0, 1.0),
          active: active,
          track: colors.tone2,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _TrafficRingPainter extends CustomPainter {
  const _TrafficRingPainter({
    required this.share,
    required this.active,
    required this.track,
    required this.strokeWidth,
  });

  final double share;
  final Color active;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw remaining traffic arc (or full thin ring if unused) so it reads like
    // a clean fuel gauge at a glance.
    final remaining = (1.0 - share).clamp(0.0, 1.0);
    if (remaining <= 0) return;
    final activePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * remaining,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(_TrafficRingPainter oldDelegate) =>
      oldDelegate.share != share ||
      oldDelegate.active != active ||
      oldDelegate.track != track ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Uniform circular type glyph badge used as the right anchor on cards without
/// a traffic progress ring (local YAML, custom profiles, or unlimited remote).
class ProfileTypeBadgeCircle extends StatelessWidget {
  const ProfileTypeBadgeCircle({
    super.key,
    required this.type,
    this.size = 28,
  });

  final ProfileType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = context.colorScheme.brightness == Brightness.dark;
    final accent = profileTypeAccent(context, type);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.11),
        shape: AppShape.full,
      ),
      alignment: Alignment.center,
      child: GlyphIcon(
        profileDefaultGlyph(type),
        size: size * 0.54,
        color: accent,
      ),
    );
  }
}
