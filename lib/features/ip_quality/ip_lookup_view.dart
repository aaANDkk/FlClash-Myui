import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ip.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/vertical_ticket_perforation.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ip_locate.dart';
import 'risk_model.dart';
import 'risk_provider.dart';
import 'risk_view.dart';

class IpLookupView extends ConsumerStatefulWidget {
  const IpLookupView({super.key, this.initialIp = ''});

  final String initialIp;

  @override
  ConsumerState<IpLookupView> createState() => _IpLookupViewState();
}

class _IpLookupViewState extends ConsumerState<IpLookupView> {
  late final OutboundIpProbe _probe;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  String? _queriedIp;
  bool _retrying = false;
  bool _retryHold = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier)..watch(routedOutbound);
    final initial = publicIpOf(widget.initialIp);
    _queriedIp = initial;
    _controller = TextEditingController(text: initial ?? '');
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _probe.unwatch(routedOutbound);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final parsed = publicIpOf(_controller.text);
    if (parsed == null) {
      dialogs.showBanner(
        context.appLocalizations.ipRiskInvalid,
        level: BannerLevel.error,
      );
      return;
    }
    _focusNode.unfocus();
    setState(() {
      _queriedIp = parsed;
      _retrying = false;
    });
    if (_controller.text.trim() != parsed) {
      _controller.value = TextEditingValue(
        text: parsed,
        selection: TextSelection.collapsed(offset: parsed.length),
      );
    }
  }

  void _useOutboundIp() {
    _focusNode.unfocus();
    _controller.clear();
    setState(() {
      _queriedIp = null;
      _retrying = false;
    });
  }

  void _startRetryHold() {
    _retryTimer?.cancel();
    setState(() => _retryHold = true);
    _retryTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _retryHold = false);
    });
  }

  void _retryFailed(
    String activeIp, {
    required bool riskFailed,
    required bool attributionFailed,
  }) {
    if (_retryHold) return;
    _startRetryHold();
    setState(() => _retrying = true);
    if (activeIp.isEmpty) {
      _probe.refresh(const [routedOutbound]);
      return;
    }
    if (riskFailed || (!riskFailed && !attributionFailed)) {
      refreshIpRisk(ref, activeIp);
    }
    if (attributionFailed) {
      ref.invalidate(ipLocateProvider(activeIp));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final entry = ref.watch(
      outboundIpProbeProvider.select((s) => s.entryOf(routedOutbound)),
    );
    final outboundIp = entry.value?.ip ?? '';
    final activeIp = _queriedIp ?? outboundIp;
    final isOutbound =
        activeIp.isNotEmpty &&
        (_queriedIp == null || _queriedIp == outboundIp);
    final isCustom =
        _queriedIp != null &&
        outboundIp.isNotEmpty &&
        _queriedIp != outboundIp;

    final probingOutbound =
        _queriedIp == null &&
        outboundIp.isEmpty &&
        (entry.phase == ProbePhase.probing || entry.phase == ProbePhase.empty);
    final outboundFailed =
        _queriedIp == null &&
        outboundIp.isEmpty &&
        entry.phase == ProbePhase.failed;

    final riskState = activeIp.isNotEmpty
        ? ref.watch(ipRiskProvider(activeIp))
        : null;
    final locateState = activeIp.isNotEmpty
        ? ref.watch(ipLocateProvider(activeIp))
        : null;

    final risk = riskState == null || riskState.hasError
        ? null
        : riskState.value;
    final attribution = locateState == null || locateState.hasError
        ? null
        : locateState.value;

    final riskFailed = riskState != null && !riskState.isLoading && risk == null;
    final attributionFailed =
        locateState != null && !locateState.isLoading && attribution == null;

    final isLoading =
        probingOutbound ||
        (!riskFailed &&
            !attributionFailed &&
            ((riskState?.isLoading ?? false) ||
                (locateState?.isLoading ?? false)));

    final hidden = ref.watch(appSettingProvider.select((s) => s.hideIp));

    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.standard),
      child: Scaffold(
        title: l.ipQuery,
        iconActions: [
          IconButtonData(
            glyph: hidden ? AppGlyphs.eyeOff : AppGlyphs.eye,
            tooltip: l.hideIp,
            onPressed: () => ref
                .read(appSettingProvider.notifier)
                .update((s) => s.copyWith(hideIp: !hidden)),
          ),
        ],
        body: Builder(
          builder: (context) => LayoutBuilder(
            builder: (context, constraints) {
              const sidePadding = 16.0;
              final isWide = constraints.maxWidth >= 760;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  sidePadding,
                  context.contentTopPadding,
                  sidePadding,
                  24 + context.bottomInset,
                ),
                children: [
                  _IpSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    showOutboundShortcut: isCustom,
                    isWide: constraints.maxWidth >= 600,
                    onSubmitted: _submitSearch,
                    onUseOutbound: _useOutboundIp,
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: context.motionDuration(commonDuration),
                    reverseDuration: context.motionDuration(
                      const Duration(milliseconds: 160),
                    ),
                    switchInCurve: Easing.emphasizedDecelerate,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (currentChild, previousChildren) => Align(
                      alignment: Alignment.topCenter,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[...previousChildren, ?currentChild],
                      ),
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child.key is ValueKey<String> &&
                              (child.key as ValueKey<String>).value.startsWith(
                                'data:',
                              )
                          ? ScaleTransition(
                              scale: animation.drive(
                                Tween(begin: 0.96, end: 1.0),
                              ),
                              child: child,
                            )
                          : child,
                    ),
                    child: _buildContent(
                      context,
                      isWide: isWide,
                      activeIp: activeIp,
                      isOutbound: isOutbound,
                      hidden: hidden,
                      isLoading: isLoading,
                      outboundFailed: outboundFailed,
                      risk: risk,
                      attribution: attribution,
                      onRetry: () => _retryFailed(
                        activeIp,
                        riskFailed: riskFailed,
                        attributionFailed: attributionFailed,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isWide,
    required String activeIp,
    required bool isOutbound,
    required bool hidden,
    required bool isLoading,
    required bool outboundFailed,
    required IpRisk? risk,
    required IpLocateInfo? attribution,
    required VoidCallback onRetry,
  }) {
    final l = context.appLocalizations;
    if (!_retrying && isLoading) {
      return SizedBox(
        key: ValueKey('loading:$activeIp'),
        height: 280,
        child: const Center(child: ActivityIndicator.page()),
      );
    }

    if (!isLoading && risk != null && attribution != null) {
      final hasChecks = risk.checks.isNotEmpty;
      final heroCard = _IpRiskHeroCard(
        ip: activeIp,
        risk: risk,
        hidden: hidden,
        isOutbound: isOutbound,
        fillHeight: isWide && hasChecks,
      );
      final attributionCard = _IpAttributionCard(
        risk: risk,
        attribution: attribution,
        hidden: hidden,
        isWide: isWide,
      );
      final flagsCard = hasChecks
          ? _IpFlagsCard(risk: risk, isWide: isWide)
          : null;
      return Column(
        key: ValueKey('data:$activeIp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide) ...[
            if (flagsCard != null)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 9, child: heroCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 13, child: flagsCard),
                  ],
                ),
              )
            else
              heroCard,
            const SizedBox(height: 12),
            attributionCard,
          ] else ...[
            heroCard,
            const SizedBox(height: 12),
            attributionCard,
            if (flagsCard != null) ...[const SizedBox(height: 12), flagsCard],
          ],
          ListFooter(text: '${l.ipRiskSource} ${l.ipRiskSources}'),
        ],
      );
    }

    return _IpLookupErrorCard(
      key: ValueKey('error:$activeIp:$outboundFailed'),
      ip: activeIp,
      hidden: hidden,
      loading: isLoading || _retryHold,
      onRetry: onRetry,
    );
  }
}

class _IpHeaderIconBadge extends StatelessWidget {
  const _IpHeaderIconBadge({required this.glyph, required this.color});

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

class _IpSearchBar extends StatelessWidget {
  const _IpSearchBar({
    required this.controller,
    required this.focusNode,
    required this.showOutboundShortcut,
    required this.isWide,
    required this.onSubmitted,
    required this.onUseOutbound,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showOutboundShortcut;
  final bool isWide;
  final VoidCallback onSubmitted;
  final VoidCallback onUseOutbound;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colors = DashboardColors.of(context);
    final shortcut = _OutboundShortcutPill(onPressed: onUseOutbound);
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  controller: controller,
                  focusNode: focusNode,
                  height: 42,
                  fill: colors.tone,
                  hintText: l.ipRiskHint,
                  onSubmitted: onSubmitted,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: isWide
                    ? FilledButton.icon(
                        onPressed: onSubmitted,
                        icon: const GlyphIcon(AppGlyphs.search, size: 17),
                        label: Text(l.search),
                      )
                    : FilledButton(
                        onPressed: onSubmitted,
                        child: Text(l.search),
                      ),
              ),
              if (isWide && showOutboundShortcut) ...[
                const SizedBox(width: 8),
                shortcut,
              ],
            ],
          ),
          if (!isWide && showOutboundShortcut) ...[
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerStart, child: shortcut),
          ],
        ],
      ),
    );
  }
}

class _OutboundShortcutPill extends StatelessWidget {
  const _OutboundShortcutPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final colors = DashboardColors.of(context);
    return PressRegion(
      onTap: onPressed,
      shape: AppShape.full,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colors.tone, shape: AppShape.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              GlyphIcon(AppGlyphs.location, size: 15, color: cs.primary),
              Text(
                l.outboundIp,
                maxLines: 1,
                style: AppTextStyle.caption1
                    .of(context, emphasized: true)
                    .copyWith(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IpRiskHeroCard extends StatelessWidget {
  const _IpRiskHeroCard({
    required this.ip,
    required this.risk,
    required this.hidden,
    required this.isOutbound,
    this.fillHeight = false,
  });

  final String ip;
  final IpRisk risk;
  final bool hidden;
  final bool isOutbound;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final colors = DashboardColors.of(context);
    final isDark = cs.brightness == Brightness.dark;
    final scoreColor = riskScoreColor(risk.displayScore);
    final hitCount = risk.checks.where((c) => c.hit == true).length;
    final totalChecks = risk.checks.length;
    final typeText = risk.typeLabel(context) ?? risk.levelLabel(context);
    final typeColor = risk.isHomeBroadband ? riskGradient.first : scoreColor;
    final flagColor = totalChecks == 0
        ? cs.onSurfaceVariant
        : hitCount == 0
        ? riskGradient.first
        : cs.error;

    final header = Row(
      children: [
        _IpHeaderIconBadge(glyph: AppGlyphs.verified, color: scoreColor),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  l.ipRiskScore,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headline.of(context, emphasized: true),
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
    );

    final scoreBlock = Row(
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
    );

    final ipColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isOutbound ? l.outboundIpAddress : l.ipAddress,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  hidden ? '*****' : ip,
                  maxLines: 1,
                  style: hidden
                      ? AppTextStyle.title2
                            .of(context, emphasized: true)
                            .toJetBrainsMono
                            .copyWith(color: cs.success)
                      : AppTextStyle.title2
                            .of(context, emphasized: true)
                            .toTabular,
                ),
              ),
            ),
            const SizedBox(width: 4),
            MinIconButtonTheme(
              child: IconButton(
                tooltip: l.copy,
                onPressed: ip.isEmpty
                    ? null
                    : () => dialogs.copyToClipboard(context, ip),
                icon: const GlyphIcon(AppGlyphs.copy, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InlineMetric(
              dotColor: typeColor,
              label: l.ipType,
              value: typeText,
              valueColor: risk.isHomeBroadband ? riskGradient.first : null,
            ),
            _InlineMetric(
              dotColor: flagColor,
              label: l.ipFlags,
              value: totalChecks == 0 ? '\u2014' : '$hitCount / $totalChecks',
              valueColor: totalChecks == 0 ? null : flagColor,
              tabular: true,
            ),
          ],
        ),
      ],
    );

    final riskScale = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${l.ipRiskScore} ${risk.displayScore} / 100',
          child: SizedBox(
            height: 24,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: risk.displayScore.toDouble()),
              duration: context.motionDuration(
                const Duration(milliseconds: 520),
              ),
              curve: Curves.easeOutCubic,
              builder: (_, animatedScore, _) => CustomPaint(
                painter: _RiskScaleBarPainter(
                  score: animatedScore,
                  surface: colors.card,
                ),
              ),
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

    return Card(
      radius: AppCorner.xl,
      padding: EdgeInsets.zero,
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: AppShape.xl,
          textDirection: Directionality.of(context),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.88, -1.15),
                      radius: 1.05,
                      colors: [
                        scoreColor.withValues(alpha: isDark ? 0.16 : 0.13),
                        scoreColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.72],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  header,
                  const SizedBox(height: 8),
                  scoreBlock,
                  const SizedBox(height: 9),
                  if (fillHeight) const Spacer(flex: 1),
                  Divider(
                    height: 1,
                    thickness: Divider.separatorThicknessOf(context),
                  ),
                  const SizedBox(height: 9),
                  if (fillHeight) const Spacer(flex: 1),
                  ipColumn,
                  const SizedBox(height: 11),
                  if (fillHeight) const Spacer(flex: 2),
                  riskScale,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.dotColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.tabular = false,
  });

  final Color dotColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    var valueStyle = AppTextStyle.footnote
        .of(context, emphasized: true)
        .copyWith(color: valueColor ?? cs.onSurface);
    if (tabular) {
      valueStyle = valueStyle.toTabular;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(color: dotColor, shape: AppShape.circle),
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

class _RiskScaleBarPainter extends CustomPainter {
  const _RiskScaleBarPainter({required this.score, required this.surface});

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
  bool shouldRepaint(_RiskScaleBarPainter oldDelegate) =>
      score != oldDelegate.score || surface != oldDelegate.surface;
}

class _IpAttributionCard extends StatelessWidget {
  const _IpAttributionCard({
    required this.risk,
    required this.attribution,
    required this.hidden,
    required this.isWide,
  });

  final IpRisk risk;
  final IpLocateInfo attribution;
  final bool hidden;
  final bool isWide;

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
    return SelectableText(
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
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: asn,
              style: AppTextStyle.subheadline
                  .of(context, emphasized: true)
                  .toTabular,
            ),
            TextSpan(
              text: ' · $network',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (asn.isNotEmpty) {
      return SelectableText(
        asn,
        style: AppTextStyle.subheadline.of(context, emphasized: true).toTabular,
      );
    }
    return SelectableText(
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
            GlyphIcon(AppGlyphs.location, size: 14, color: cs.primary),
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
            SelectableText(
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

    const verticalPadding = EdgeInsets.symmetric(vertical: 18);
    final left = Padding(padding: verticalPadding, child: leftZone);
    final right = Padding(padding: verticalPadding, child: rightZone);
    return Card(
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
                    color: cs.primary.withValues(alpha: isDark ? 0.09 : 0.065),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: specs.isEmpty
                  ? left
                  : !hasLocation
                  ? right
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 9, child: left),
                          SizedBox(
                            width: 41.5,
                            child: CustomPaint(
                              painter: VerticalTicketPerforationPainter(
                                notchColor: SurfaceLevel.page.colorOf(cs),
                                dashColor: cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.55 : 0.48,
                                ),
                              ),
                            ),
                          ),
                          Expanded(flex: 13, child: right),
                        ],
                      ),
                    ),
            ),
          ],
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
    final info = attribution.ip == risk.ip ? attribution : null;
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
              SelectableText(
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

    return Card(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _IpHeaderIconBadge(
                        glyph: AppGlyphs.location,
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
                  if (sections.isNotEmpty) ...[
                    const SizedBox(height: 12),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IpFlagsCard extends StatelessWidget {
  const _IpFlagsCard({required this.risk, required this.isWide});

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
              _IpHeaderIconBadge(glyph: AppGlyphs.target, color: cs.primary),
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
      spacing: 6,
      runSpacing: 6,
      children: [
        if (homeBroadband)
          const _LookupFlagPill(
            check: IpRiskCheck(
              group: IpRiskGroup.datacenter,
              name: 'Home Broadband',
              hit: false,
            ),
            home: true,
          )
        else
          for (final check in checks) _LookupFlagPill(check: check),
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

class _LookupFlagPill extends StatelessWidget {
  const _LookupFlagPill({required this.check, this.home = false});

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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: ShapeDecoration(
        color: hit || home ? color.withValues(alpha: 0.12) : colors.tone,
        shape: AppShape.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
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

class _IpLookupErrorCard extends StatelessWidget {
  const _IpLookupErrorCard({
    super.key,
    required this.ip,
    required this.hidden,
    required this.loading,
    required this.onRetry,
  });

  final String ip;
  final bool hidden;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    return Card(
      radius: AppCorner.xl,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphIcon(AppGlyphs.error, size: 28, color: cs.error),
          const SizedBox(height: 12),
          if (ip.isNotEmpty) ...[
            Text(
              hidden ? '*****' : ip,
              textAlign: TextAlign.center,
              style: hidden
                  ? AppTextStyle.headline
                        .of(context, emphasized: true)
                        .toJetBrainsMono
                        .copyWith(color: cs.success)
                  : AppTextStyle.headline
                        .of(context, emphasized: true)
                        .toTabular,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            l.ipRiskFailed,
            textAlign: TextAlign.center,
            style: AppTextStyle.body.of(context).copyWith(color: cs.error),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: FadeBox(
              child: loading
                  ? const SizedBox(
                      key: ValueKey('spinner'),
                      height: 48,
                      child: Center(child: ActivityIndicator(size: 20)),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('retry'),
                      onPressed: onRetry,
                      icon: const GlyphIcon(AppGlyphs.refresh, size: 18),
                      label: Text(l.retry),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
