import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'risk_model.dart';

const riskGradient = [Color(0xFF4CAF50), Color(0xFFC57F0A), Color(0xFFEF5350)];

Color riskScoreColor(int score) {
  final t = score.clamp(0, 100) / 100;
  return t < .5
      ? Color.lerp(riskGradient[0], riskGradient[1], t * 2)!
      : Color.lerp(riskGradient[1], riskGradient[2], (t - .5) * 2)!;
}

extension RiskView on IpRisk {
  String? typeLabel(BuildContext context) => isHomeBroadband
      ? context.appLocalizations.ipRiskHomeBroadband
      : isDatacenter
      ? context.appLocalizations.ipRiskDatacenter
      : isResidentialProxy
      ? context.appLocalizations.ipRiskResidentialProxy
      : null;
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

class RiskLevelBadge extends StatelessWidget {
  const RiskLevelBadge({super.key, required this.risk});
  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = riskScoreColor(risk.displayScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: .12),
        shape: AppShape.sm,
      ),
      child: Text(
        risk.levelLabel(context),
        style: AppTextStyle.footnote
            .of(context, emphasized: true)
            .copyWith(color: color),
      ),
    );
  }
}

class RiskScoreCard extends StatelessWidget {
  const RiskScoreCard({super.key, required this.risk});
  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final color = riskScoreColor(risk.displayScore);
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l.ipRiskScore, style: AppTextStyle.subheadline.of(context)),
              const SizedBox(width: 4),
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
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${risk.displayScore}',
                    style: AppTextStyle.display
                        .of(context, emphasized: true)
                        .toTabular
                        .copyWith(color: color),
                  ),
                  Text(
                    ' / 100',
                    style: AppTextStyle.body
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              RiskLevelBadge(risk: risk),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: '${l.ipRiskScore} ${risk.displayScore} / 100',
            child: SizedBox(
              height: 24,
              width: double.infinity,
              child: CustomPaint(
                painter: _RiskScale(
                  risk.displayScore,
                  context.colorScheme.surface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.ipRiskLow, style: AppTextStyle.footnote.of(context)),
              Text(l.ipRiskHigh, style: AppTextStyle.footnote.of(context)),
            ],
          ),
        ],
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

class _RiskScale extends CustomPainter {
  const _RiskScale(this.score, this.surface);
  final int score;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 8, size.width, 8);
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
        rect.left + rect.width * score.clamp(0, 100) / 100,
        size.height,
      ),
    );
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(rect, AppRadius.full.topLeft),
      Paint()
        ..shader = const LinearGradient(
          colors: riskGradient,
        ).createShader(rect),
    );
    canvas.restore();
    final center = Offset(
      (rect.width * score.clamp(0, 100) / 100).clamp(8, size.width - 8),
      12,
    );
    canvas.drawCircle(center, 8, Paint()..color = riskScoreColor(score));
    canvas.drawCircle(center, 4, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(_RiskScale oldDelegate) =>
      score != oldDelegate.score || surface != oldDelegate.surface;
}

class RiskChecksCard extends StatelessWidget {
  const RiskChecksCard({super.key, required this.risk});
  final IpRisk risk;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final groups = IpRiskGroup.values
        .where((group) => risk.checks.any((c) => c.group == group))
        .toList();
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, group) in groups.indexed) ...[
            if (index > 0) const SizedBox(height: 20),
            Text(
              switch (group) {
                IpRiskGroup.datacenter => l.ipRiskHostingOrProxy,
                IpRiskGroup.blacklist => l.ipRiskBlacklist,
                IpRiskGroup.proxy => l.ipRiskProxyType,
              },
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (risk.isHomeBroadband && group == IpRiskGroup.datacenter)
                  const _RiskFlag(
                    check: IpRiskCheck(
                      group: IpRiskGroup.datacenter,
                      name: 'Home Broadband',
                      hit: false,
                    ),
                    home: true,
                  )
                else
                  for (final check in risk.checks.where(
                    (c) => c.group == group,
                  ))
                    _RiskFlag(check: check),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskFlag extends StatelessWidget {
  const _RiskFlag({required this.check, this.home = false});
  final IpRiskCheck check;
  final bool home;

  @override
  Widget build(BuildContext context) {
    final hit = check.hit == true;
    final color = home
        ? riskGradient.first
        : hit
        ? context.colorScheme.error
        : context.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: ShapeDecoration(
        color: hit || home
            ? color.withValues(alpha: .1)
            : context.colorScheme.onSurface.withValues(alpha: .045),
        shape: AppShape.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (home)
            GlyphIcon(AppGlyphs.checkCircle, size: 14, color: color)
          else if (hit)
            GlyphIcon(AppGlyphs.error, size: 14, color: color)
          else if (check.hit == null)
            GlyphIcon(AppGlyphs.helpCircle, size: 14, color: color)
          else
            DecoratedBox(
              decoration: ShapeDecoration(
                shape: AppShape.circle.copyWith(
                  side: BorderSide(color: color, width: 1.4),
                ),
              ),
              child: const SizedBox.square(dimension: 12),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              home
                  ? context.appLocalizations.ipRiskHomeBroadband
                  : riskCheckLabel(context, check.name),
              style: AppTextStyle.footnote
                  .of(context, emphasized: hit || home)
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
