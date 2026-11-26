import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/vertical_ticket_perforation.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'ip_locate.dart';
import 'risk_model.dart';

const riskGradient = [Color(0xFF4CAF50), Color(0xFFC57F0A), Color(0xFFEF5350)];

const ipFlagPillSpacing = 6.0;
const ipFlagPillHorizontalPadding = 9.0;
const ipFlagPillIconGap = 6.0;

Color riskScoreColor(int score) {
  final t = score.clamp(0, 100) / 100;
  return t < .5
      ? Color.lerp(riskGradient[0], riskGradient[1], t * 2)!
      : Color.lerp(riskGradient[1], riskGradient[2], (t - .5) * 2)!;
}

extension RiskView on IpRisk {
  String? get countryLabel {
    final text = [
      if (countryCode.isNotEmpty) countryCode.countryFlagEmoji,
      country.isNotEmpty ? country : countryCode,
    ].where((s) => s.isNotEmpty).join(' ');
    return text.isEmpty ? null : text;
  }

  String? get placeLabel {
    final text = [
      region,
      city,
    ].where((s) => s.isNotEmpty).toSet().join(' \u00b7 ');
    return text.isEmpty ? null : text;
  }

  String? get fullLocationLabel {
    final text = [?countryLabel, ?placeLabel].join(' \u00b7 ');
    return text.isEmpty ? null : text;
  }

  String? typeLabel(BuildContext context) {
    final l = context.appLocalizations;
    if (isHomeBroadband) return l.ipRiskHomeBroadband;
    if (isDatacenter) return l.ipRiskDatacenter;
    if (isResidentialProxy) return l.ipRiskResidentialProxy;
    for (final check in checks) {
      if (check.group == IpRiskGroup.proxy && check.hit == true) {
        return riskCheckLabel(context, check.name);
      }
    }
    return null;
  }

  String levelLabel(BuildContext context) => level.label(context);
}

extension RiskLevelView on IpRiskLevel {
  String label(BuildContext context) => switch (this) {
    IpRiskLevel.low => context.appLocalizations.ipRiskLow,
    IpRiskLevel.medium => context.appLocalizations.ipRiskMedium,
    IpRiskLevel.high => context.appLocalizations.ipRiskHigh,
    IpRiskLevel.veryHigh => context.appLocalizations.ipRiskVeryHigh,
  };
}

String riskCheckLabel(BuildContext context, String name) {
  final l = context.appLocalizations;
  return switch (name) {
    'Datacenter' => l.ipRiskDatacenter,
    'Residential Proxy' => l.ipRiskResidentialProxy,
    'Anonymizing VPN' => l.ipRiskAnonymousVpn,
    'Tor Exit Node' => l.ipRiskTorExit,
    'Server' => l.ipRiskServer,
    'Public Proxy' => l.ipRiskPublicProxy,
    'Web Proxy' => l.ipRiskWebProxy,
    'Search Engine Robot' => l.ipRiskSearchRobot,
    _ => name,
  };
}

class IpHeaderIconBadge extends StatelessWidget {
  const IpHeaderIconBadge({
    super.key,
    required this.glyph,
    required this.color,
  });

  final Glyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: AppShape.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GlyphIcon(glyph, size: 18, color: color),
      ),
    );
  }
}

class RiskLevelBadge extends StatelessWidget {
  const RiskLevelBadge({super.key, required this.risk});
  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = riskScoreColor(risk.displayScore);
    return _RiskPill(
      label: risk.levelLabel(context),
      background: color.withValues(alpha: .12),
      foreground: color,
      emphasized: true,
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({
    required this.label,
    required this.background,
    required this.foreground,
    this.emphasized = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: background, shape: AppShape.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTextStyle.caption1
                  .of(context, emphasized: emphasized)
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class RiskInlineMetrics extends StatelessWidget {
  const RiskInlineMetrics({super.key, required this.risk});

  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final hitCount = risk.checks.where((c) => c.hit == true).length;
    final totalChecks = risk.checks.length;
    final flagColor = totalChecks == 0
        ? cs.onSurfaceVariant
        : hitCount == 0
        ? riskGradient.first
        : cs.error;
    final resolvedType = risk.typeLabel(context);
    final typeText = resolvedType ?? l.unknown;
    final typeColor = risk.isHomeBroadband
        ? riskGradient.first
        : resolvedType == null
        ? cs.onSurfaceVariant
        : null;

    return Wrap(
      spacing: 18,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineMetric(
          label: l.ipType,
          value: typeText,
          valueColor: typeColor,
          emphasized: resolvedType != null,
        ),
        _InlineMetric(
          dotColor: totalChecks == 0 ? null : flagColor,
          label: l.ipFlags,
          value: totalChecks == 0 ? '\u2014' : '$hitCount / $totalChecks',
          valueColor: totalChecks == 0 ? null : flagColor,
          tabular: true,
        ),
      ],
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    this.dotColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = true,
    this.tabular = false,
  });

  final Color? dotColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    var valueStyle = AppTextStyle.footnote
        .of(context, emphasized: emphasized)
        .copyWith(color: valueColor ?? cs.onSurface);
    if (tabular) {
      valueStyle = valueStyle.toTabular;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (dotColor != null)
          DecoratedBox(
            decoration: ShapeDecoration(
              color: dotColor!,
              shape: AppShape.circle,
            ),
            child: const SizedBox.square(dimension: 7),
          ),
        Text(
          label,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: cs.onSurfaceVariant),
        ),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class RiskScaleSection extends StatelessWidget {
  const RiskScaleSection({
    super.key,
    required this.risk,
    this.animate = false,
  });

  final IpRisk risk;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final surface = DashboardColors.of(context).card;
    final targetScore = risk.displayScore.toDouble();

    Widget paintBar(double score) => CustomPaint(
      painter: RiskScaleBarPainter(score: score, surface: surface),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${l.ipRiskScore} ${risk.displayScore} / 100',
          child: RepaintBoundary(
            child: SizedBox(
              height: 24,
              width: double.infinity,
              child: animate
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: targetScore),
                      duration: context.motionDuration(
                        const Duration(milliseconds: 520),
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (_, animatedScore, _) => paintBar(animatedScore),
                    )
                  : paintBar(targetScore),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.ipRiskLow,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              l.ipRiskHigh,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class RiskScaleBarPainter extends CustomPainter {
  const RiskScaleBarPainter({required this.score, required this.surface});

  final double score;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 8, size.width, 8);
    final clamped = score.clamp(0.0, 100.0);
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(rect, AppRadius.full.topLeft),
      Paint()
        ..shader = LinearGradient(
          colors: riskGradient.map((c) => c.withValues(alpha: .24)).toList(),
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        rect.left,
        0,
        rect.left + rect.width * clamped / 100,
        size.height,
      ),
    );
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(rect, AppRadius.full.topLeft),
      Paint()
        ..shader = const LinearGradient(colors: riskGradient).createShader(rect),
    );
    canvas.restore();
    final center = Offset(
      (rect.width * clamped / 100).clamp(8.0, math.max(8.0, size.width - 8.0)),
      12,
    );
    canvas.drawCircle(
      center,
      8,
      Paint()..color = riskScoreColor(clamped.round()),
    );
    canvas.drawCircle(center, 4, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(RiskScaleBarPainter oldDelegate) =>
      score != oldDelegate.score || surface != oldDelegate.surface;
}

class RiskScoreCard extends StatelessWidget {
  const RiskScoreCard({super.key, required this.risk});
  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final scoreColor = riskScoreColor(risk.displayScore);
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IpHeaderIconBadge(glyph: AppGlyphs.verified, color: scoreColor),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.ipRiskScore,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.headline.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    MinIconButtonTheme(
                      child: IconButton(
                        tooltip: l.ipRiskNoteTitle,
                        onPressed: () => dialogs.showAlert(
                          title: l.ipRiskNoteTitle,
                          message: riskNoteMessage(context, risk),
                        ),
                        icon: const GlyphIcon(AppGlyphs.info, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RiskLevelBadge(risk: risk),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${risk.displayScore}',
                maxLines: 1,
                style: AppTextStyle.display
                    .of(context, emphasized: true)
                    .toTabular
                    .copyWith(fontSize: 44, height: 1.0, color: scoreColor),
              ),
              const SizedBox(width: 5),
              Text(
                '/ 100',
                maxLines: 1,
                style: AppTextStyle.callout
                    .of(context, emphasized: true)
                    .toTabular
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RiskInlineMetrics(risk: risk),
          const SizedBox(height: 12),
          RiskScaleSection(risk: risk),
        ],
      ),
    );
  }
}

class IpAttributionCard extends StatelessWidget {
  const IpAttributionCard({
    super.key,
    required this.risk,
    required this.attribution,
    required this.hidden,
    this.isWide = false,
    this.wideCardGap = 12.0,
    this.wideLeftFlex = 9,
    this.wideRightFlex = 13,
    this.wideLeftWidth,
    this.wideRightWidth,
  });

  final IpRisk risk;
  final IpLocateInfo? attribution;
  final bool hidden;
  final bool isWide;
  final double wideCardGap;
  final int wideLeftFlex;
  final int wideRightFlex;
  final double? wideLeftWidth;
  final double? wideRightWidth;

  Widget _field(BuildContext context, String label, Widget value) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyle.caption1
              .of(context)
              .copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        value,
      ],
    );
  }

  Widget _textValue(BuildContext context, String value) {
    return Text(
      value,
      style: AppTextStyle.subheadline.of(context, emphasized: true),
    );
  }

  Widget _asnValue(
    BuildContext context, {
    required String asn,
    required String network,
  }) {
    final cs = context.colorScheme;
    if (asn.isNotEmpty && network.isNotEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: asn,
              style: AppTextStyle.subheadline
                  .of(context, emphasized: true)
                  .toTabular,
            ),
            TextSpan(
              text: ' \u00b7 $network',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (asn.isNotEmpty) {
      return Text(
        asn,
        style: AppTextStyle.subheadline.of(context, emphasized: true).toTabular,
      );
    }
    return Text(
      network,
      style: AppTextStyle.subheadline.of(context, emphasized: true),
    );
  }

  Widget _buildWideBoardingPass(
    BuildContext context, {
    required String country,
    required String place,
    required String countryCode,
    required bool hasLocation,
    required String company,
    required String asn,
    required String network,
    required bool showNetwork,
    required bool showAsnRow,
    required bool showHostname,
  }) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final specs = <({String label, Widget value})>[
      if (company.isNotEmpty)
        (label: l.isp, value: _textValue(context, company)),
      if (showAsnRow)
        (
          label: l.ipRiskAsn,
          value: _asnValue(
            context,
            asn: asn,
            network: showNetwork ? network : '',
          ),
        ),
      if (showHostname)
        (label: l.ipRiskHostname, value: _textValue(context, risk.hostname)),
    ];

    var visualRows = specs.length;
    if (company.length > 44) visualRows++;
    if (showHostname && risk.hostname.length > 44) visualRows++;

    final countryFontSize = switch (visualRows) {
      <= 1 => 20.0,
      2 => 23.0,
      3 => 26.5,
      _ => 29.0,
    };
    final placeFontSize = switch (visualRows) {
      <= 1 => 12.5,
      2 => 13.5,
      3 => 14.5,
      _ => 15.0,
    };
    final headerGap = switch (visualRows) {
      <= 1 => 5.0,
      2 => 8.0,
      3 => 10.0,
      _ => 12.0,
    };
    final placeGap = switch (visualRows) {
      <= 1 => 2.0,
      2 => 3.0,
      _ => 4.0,
    };

    final leftZone = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GlyphIcon(AppGlyphs.flag, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                country.isNotEmpty || !hasLocation
                    ? l.ipRiskLocation
                    : l.ipRiskCity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.caption1
                    .of(context, emphasized: true)
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (countryCode.isNotEmpty) ...[
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                    side: BorderSide(
                      color: cs.primary.withValues(alpha: isDark ? 0.42 : 0.32),
                      width: 1.3,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    countryCode,
                    style: AppTextStyle.caption2
                        .of(context, emphasized: true)
                        .toTabular
                        .copyWith(color: cs.primary, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (hasLocation) ...[
          SizedBox(height: headerGap),
          if (country.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: EmojiText(
                country,
                maxLines: 1,
                style: AppTextStyle.title2
                    .of(context, emphasized: true)
                    .copyWith(fontSize: countryFontSize, height: 1.16),
              ),
            ),
          if (place.isNotEmpty) ...[
            SizedBox(height: country.isNotEmpty ? placeGap : 0),
            Text(
              place,
              style: country.isNotEmpty
                  ? AppTextStyle.subheadline
                        .of(context)
                        .copyWith(
                          fontSize: placeFontSize,
                          color: cs.onSurfaceVariant,
                        )
                  : AppTextStyle.title3
                        .of(context, emphasized: true)
                        .copyWith(fontSize: countryFontSize),
            ),
          ],
        ],
      ],
    );

    final rightZone = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, spec) in specs.indexed) ...[
          if (index > 0) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              thickness: Divider.separatorThicknessOf(context),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: spec.value),
            ],
          ),
        ],
      ],
    );

    const singleZonePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 18);
    if (specs.isEmpty && !hasLocation && countryCode.isEmpty) {
      return const SizedBox.shrink();
    }
    return SelectionArea(
      child: Card(
        radius: AppCorner.xl,
        padding: EdgeInsets.zero,
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: AppShape.xl,
            textDirection: Directionality.of(context),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IgnorePointer(
                    child: GlyphIcon(
                      AppGlyphs.proxies,
                      size: 124,
                      color: cs.primary.withValues(
                        alpha: isDark ? 0.09 : 0.065,
                      ),
                    ),
                  ),
                ),
              ),
              if (specs.isEmpty || !hasLocation)
                Padding(
                  padding: singleZonePadding,
                  child: specs.isEmpty ? leftZone : rightZone,
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wideLeftWidth != null)
                        SizedBox(
                          width: wideLeftWidth,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              20,
                              18,
                              15,
                              18,
                            ),
                            child: leftZone,
                          ),
                        )
                      else
                        Expanded(
                          flex: wideLeftFlex,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              20,
                              18,
                              15,
                              18,
                            ),
                            child: leftZone,
                          ),
                        ),
                      SizedBox(
                        width: wideCardGap,
                        child: OverflowBox(
                          minWidth: 20,
                          maxWidth: 20,
                          child: CustomPaint(
                            painter: VerticalTicketPerforationPainter(
                              notchColor: SurfaceLevel.page.colorOf(cs),
                              dashColor: cs.outlineVariant.withValues(
                                alpha: isDark ? 0.55 : 0.48,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (wideRightWidth != null)
                        SizedBox(
                          width: wideRightWidth,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              15,
                              18,
                              20,
                              18,
                            ),
                            child: rightZone,
                          ),
                        )
                      else
                        Expanded(
                          flex: wideRightFlex,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              15,
                              18,
                              20,
                              18,
                            ),
                            child: rightZone,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final colors = DashboardColors.of(context);
    final isDark = cs.brightness == Brightness.dark;
    final country = risk.countryLabel ?? '';
    final place = risk.placeLabel ?? '';
    final countryCode = risk.countryCode.trim().toUpperCase();
    final hasLocation = country.isNotEmpty || place.isNotEmpty;
    final info = attribution?.ip == risk.ip ? attribution : null;
    final company = info?.company ?? '';
    final network = info?.network ?? '';
    final asn = info?.asn ?? '';
    final showNetwork = network.isNotEmpty && network != company;
    final showAsnRow = asn.isNotEmpty || showNetwork;
    final showHostname = !hidden && risk.hostname.isNotEmpty;

    if (isWide) {
      return _buildWideBoardingPass(
        context,
        country: country,
        place: place,
        countryCode: countryCode,
        hasLocation: hasLocation,
        company: company,
        asn: asn,
        network: network,
        showNetwork: showNetwork,
        showAsnRow: showAsnRow,
        showHostname: showHostname,
      );
    }

    const sectionGap = 10.0;
    final sections = <Widget>[
      if (hasLocation)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (country.isNotEmpty)
              EmojiText(
                country,
                style: AppTextStyle.title2
                    .of(context, emphasized: true)
                    .copyWith(fontSize: 22, height: 1.2),
              ),
            if (place.isNotEmpty) ...[
              SizedBox(height: country.isNotEmpty ? 3 : 0),
              Text(
                place,
                style: country.isNotEmpty
                    ? AppTextStyle.subheadline
                          .of(context)
                          .copyWith(color: cs.onSurfaceVariant)
                    : AppTextStyle.title3.of(context, emphasized: true),
              ),
            ],
          ],
        ),
      if (company.isNotEmpty)
        _field(context, l.isp, _textValue(context, company)),
      if (showAsnRow)
        _field(
          context,
          l.ipRiskAsn,
          _asnValue(context, asn: asn, network: showNetwork ? network : ''),
        ),
      if (showHostname)
        _field(context, l.ipRiskHostname, _textValue(context, risk.hostname)),
    ];

    final showHeader = hasLocation || countryCode.isNotEmpty;
    if (!showHeader && sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Card(
        radius: AppCorner.xl,
        padding: EdgeInsets.zero,
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: AppShape.xl,
            textDirection: Directionality.of(context),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                bottom: -22,
                child: IgnorePointer(
                  child: GlyphIcon(
                    AppGlyphs.proxies,
                    size: 128,
                    color: cs.primary.withValues(alpha: isDark ? 0.10 : 0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showHeader) ...[
                      Row(
                        children: [
                          IpHeaderIconBadge(
                            glyph: AppGlyphs.flag,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              country.isNotEmpty || !hasLocation
                                  ? l.ipRiskLocation
                                  : l.ipRiskCity,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.headline.of(
                                context,
                                emphasized: true,
                              ),
                            ),
                          ),
                          if (countryCode.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            DecoratedBox(
                              decoration: ShapeDecoration(
                                color: colors.tone,
                                shape: AppShape.full,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  countryCode,
                                  style: AppTextStyle.footnote
                                      .of(context, emphasized: true)
                                      .toTabular
                                      .copyWith(color: cs.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (sections.isNotEmpty) const SizedBox(height: 12),
                    ],
                    for (final (index, section) in sections.indexed) ...[
                      if (index > 0) ...[
                        const SizedBox(height: sectionGap),
                        Divider(
                          height: 1,
                          thickness: Divider.separatorThicknessOf(context),
                        ),
                        const SizedBox(height: sectionGap),
                      ],
                      section,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InlineSpan riskNoteMessage(BuildContext context, IpRisk risk) {
  final l = context.appLocalizations;
  final note = risk.note;
  final basis = switch (note?.direct) {
    true => l.ipRiskNoteDirect(risk.displayScore),
    false => l.ipRiskNoteIndirect(
      risk.displayScore,
      note!.isp.isNotEmpty ? note.isp : risk.isp,
    ),
    null => l.ipRiskNoteGeneric,
  };
  final spans = <InlineSpan>[TextSpan(text: basis)];
  void row(String title, String value) {
    spans.add(TextSpan(text: '\n\n$title: $value'));
  }

  void party(String title, String name, IpRiskLevel? level) {
    spans.add(TextSpan(text: '\n\n$title: $name'));
    if (level == null) return;
    final label = level.label(context);
    spans.add(
      TextSpan(
        text: ' · ',
        style: TextStyle(color: context.colorScheme.onSurface),
      ),
    );
    spans.add(
      TextSpan(
        text: label,
        style: TextStyle(
          color: riskScoreColor(switch (level) {
            IpRiskLevel.low => 0,
            IpRiskLevel.medium => 50,
            IpRiskLevel.high || IpRiskLevel.veryHigh => 100,
          }),
        ),
      ),
    );
  }

  if (note?.amount case final amount?) {
    row(
      note?.direct == false ? l.ipRiskNoteAmountIsp : l.ipRiskNoteAmount,
      switch (amount) {
        IpRiskAmount.low => l.ipRiskAmountLow,
        IpRiskAmount.medium => l.ipRiskAmountMedium,
        IpRiskAmount.high => l.ipRiskAmountHigh,
      },
    );
  }
  if (note?.share case final share?) {
    row(l.ipRiskNoteShare, switch (share) {
      IpRiskShare.little => l.ipRiskShareLittle,
      IpRiskShare.some => l.ipRiskShareSome,
      IpRiskShare.almostAll => l.ipRiskShareAlmostAll,
    });
  }
  if (note != null) {
    if (note.operatorName.isNotEmpty) {
      party(l.isp, note.operatorName, note.operatorLevel);
    }
    if (note.ownerName.isNotEmpty &&
        (note.ownerName != note.operatorName ||
            note.ownerLevel != note.operatorLevel)) {
      party(l.ipRiskNoteOwner, note.ownerName, note.ownerLevel);
    }
    if (note.connection case final connection?) {
      row(l.ipRiskNoteConnection, switch (connection) {
        IpRiskConnection.server => l.ipRiskCommercialServer,
        IpRiskConnection.vpn => l.ipRiskAnonymousVpn,
        IpRiskConnection.publicProxy => l.ipRiskPublicProxy,
        IpRiskConnection.tor => l.ipRiskTorExit,
        IpRiskConnection.webProxy => l.ipRiskWebProxy,
      });
      if (connection != IpRiskConnection.server) {
        spans.add(TextSpan(text: '\n${l.ipRiskNoteProxying}'));
      }
    }
    final warning = switch (note.warning) {
      IpRiskLevel.high => l.ipRiskNoteWarningHigh,
      IpRiskLevel.veryHigh => l.ipRiskNoteWarningVeryHigh,
      _ => null,
    };
    if (warning != null) {
      spans.add(
        TextSpan(
          text: '\n\n$warning',
          style: TextStyle(color: context.colorScheme.error),
        ),
      );
    }
  }
  spans.add(TextSpan(text: '\n\n${l.ipRiskNoteFootnote}'));
  return TextSpan(children: spans);
}

class RiskChecksCard extends StatelessWidget {
  const RiskChecksCard({super.key, required this.risk, this.isWide = false});

  final IpRisk risk;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final groups = IpRiskGroup.values
        .where((group) => risk.checks.any((c) => c.group == group))
        .toList();
    if (groups.isEmpty) return const SizedBox.shrink();

    final hitCount = risk.checks.where((c) => c.hit == true).length;
    final totalCount = risk.checks.length;
    final summaryColor = hitCount > 0 ? cs.error : riskGradient.first;

    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              IpHeaderIconBadge(glyph: AppGlyphs.target, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.ipFlags,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headline.of(context, emphasized: true),
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: summaryColor.withValues(alpha: 0.12),
                  shape: AppShape.full,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      GlyphIcon(
                        hitCount > 0
                            ? AppGlyphs.error
                            : AppGlyphs.checkCircle,
                        size: 14,
                        color: summaryColor,
                      ),
                      Text(
                        '$hitCount / $totalCount',
                        style: AppTextStyle.caption1
                            .of(context, emphasized: true)
                            .toTabular
                            .copyWith(color: summaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isWide ? 11 : 14),
          for (final (index, group) in groups.indexed) ...[
            if (index > 0) ...[
              SizedBox(height: isWide ? 8 : 14),
              if (isWide) const Spacer(),
              Divider(
                height: 1,
                thickness: Divider.separatorThicknessOf(context),
              ),
              SizedBox(height: isWide ? 8 : 14),
              if (isWide) const Spacer(),
            ],
            _FlagGroupRow(
              title: switch (group) {
                IpRiskGroup.datacenter => l.ipRiskHostingOrProxy,
                IpRiskGroup.blacklist => l.ipRiskBlacklist,
                IpRiskGroup.proxy => l.ipRiskProxyType,
              },
              checks: risk.checks.where((c) => c.group == group).toList(),
              homeBroadband:
                  risk.isHomeBroadband && group == IpRiskGroup.datacenter,
            ),
          ],
        ],
      ),
    );
  }
}

class _FlagGroupRow extends StatelessWidget {
  const _FlagGroupRow({
    required this.title,
    required this.checks,
    required this.homeBroadband,
  });

  final String title;
  final List<IpRiskCheck> checks;
  final bool homeBroadband;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final groupHits = checks.where((c) => c.hit == true).length;
    final countText = Text(
      '$groupHits/${checks.length}',
      textAlign: TextAlign.end,
      style: AppTextStyle.caption1
          .of(context, emphasized: groupHits > 0)
          .toTabular
          .copyWith(
            color: groupHits > 0
                ? cs.error
                : cs.onSurfaceVariant.withValues(alpha: 0.78),
          ),
    );
    final labelText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.caption1
          .of(context, emphasized: true)
          .copyWith(color: cs.onSurfaceVariant),
    );
    final pills = Wrap(
      spacing: ipFlagPillSpacing,
      runSpacing: ipFlagPillSpacing,
      children: [
        if (homeBroadband)
          const _RiskFlagPill(
            check: IpRiskCheck(
              group: IpRiskGroup.datacenter,
              name: 'Home Broadband',
              hit: false,
            ),
            home: true,
          )
        else
          for (final check in checks) _RiskFlagPill(check: check),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: labelText),
            const SizedBox(width: 8),
            countText,
          ],
        ),
        const SizedBox(height: 6),
        pills,
      ],
    );
  }
}

class _RiskFlagPill extends StatelessWidget {
  const _RiskFlagPill({required this.check, this.home = false});

  final IpRiskCheck check;
  final bool home;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = DashboardColors.of(context);
    final hit = check.hit == true;
    final color = home
        ? riskGradient.first
        : hit
        ? cs.error
        : cs.onSurfaceVariant;
    final leading = home
        ? GlyphIcon(AppGlyphs.checkCircle, size: 13, color: color)
        : hit
        ? GlyphIcon(AppGlyphs.error, size: 13, color: color)
        : check.hit == null
        ? GlyphIcon(AppGlyphs.helpCircle, size: 13, color: color)
        : DecoratedBox(
            decoration: ShapeDecoration(
              shape: AppShape.circle.copyWith(
                side: BorderSide(color: color, width: 1.3),
              ),
            ),
            child: const SizedBox.square(dimension: 11),
          );
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(
        horizontal: ipFlagPillHorizontalPadding,
        vertical: 3,
      ),
      decoration: ShapeDecoration(
        color: hit || home ? color.withValues(alpha: 0.12) : colors.tone,
        shape: AppShape.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ipFlagPillIconGap,
        children: [
          leading,
          Flexible(
            child: Text(
              home
                  ? context.appLocalizations.ipRiskHomeBroadband
                  : riskCheckLabel(context, check.name),
              style: AppTextStyle.caption1
                  .of(context, emphasized: hit || home)
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
