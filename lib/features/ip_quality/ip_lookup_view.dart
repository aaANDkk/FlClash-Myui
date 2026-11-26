import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ip.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ip_locate.dart';
import 'risk_model.dart';
import 'risk_provider.dart';
import 'risk_view.dart';

const _wideLeftFlex = 9;
const _wideRightFlex = 13;
const _wideCardGap = 12.0;
const _wideMinLeftWidth = 228.0;
const _flagCardHorizontalPadding = 20.0;

double _measureSingleLineFlagsCardWidth(BuildContext context, IpRisk risk) {
  final l = context.appLocalizations;
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final locale = Localizations.maybeLocaleOf(context);

  double measurePill(String label, {required bool emphasized, required double iconSize}) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTextStyle.caption1.of(context, emphasized: emphasized),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    final width =
        ipFlagPillHorizontalPadding * 2 +
        iconSize +
        ipFlagPillIconGap +
        painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  var maxRowWidth = 0.0;
  for (final group in IpRiskGroup.values) {
    final groupChecks = risk.checks.where((c) => c.group == group).toList();
    if (groupChecks.isEmpty) continue;
    final homeBroadband =
        risk.isHomeBroadband && group == IpRiskGroup.datacenter;
    final pillWidths = <double>[
      if (homeBroadband)
        measurePill(l.ipRiskHomeBroadband, emphasized: true, iconSize: 13.0)
      else
        for (final check in groupChecks)
          measurePill(
            riskCheckLabel(context, check.name),
            emphasized: check.hit == true,
            iconSize: check.hit == false ? 11.0 : 13.0,
          ),
    ];
    final rowWidth =
        pillWidths.fold<double>(0.0, (sum, w) => sum + w) +
        math.max(0, pillWidths.length - 1) * ipFlagPillSpacing;
    if (rowWidth > maxRowWidth) {
      maxRowWidth = rowWidth;
    }
  }
  return maxRowWidth + _flagCardHorizontalPadding * 2 + 2.0;
}

({double left, double right}) _wideColumnWidths(
  BuildContext context,
  double contentWidth,
  IpRisk risk,
) {
  final usable = math.max(0.0, contentWidth - _wideCardGap);
  final defaultRight =
      usable * _wideRightFlex / (_wideLeftFlex + _wideRightFlex);
  if (risk.checks.isEmpty) {
    return (left: usable - defaultRight, right: defaultRight);
  }
  final requiredRight = _measureSingleLineFlagsCardWidth(context, risk);
  final maxRight = math.max(defaultRight, usable - _wideMinLeftWidth);
  final right = requiredRight.clamp(defaultRight, maxRight);
  return (left: usable - right, right: right);
}

class IpLookupView extends ConsumerStatefulWidget {
  const IpLookupView({super.key, this.initialIp = ''});

  final String initialIp;

  @override
  ConsumerState<IpLookupView> createState() => _IpLookupViewState();
}

class _IpLookupViewState extends ConsumerState<IpLookupView>
    with RouteSettledMixin<IpLookupView> {
  late final OutboundIpProbe _probe;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _watchingProbe = false;
  String? _queriedIp;
  bool _retrying = false;
  bool _retryHold = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier);
    final initial = publicIpOf(widget.initialIp);
    _queriedIp = initial;
    _controller = TextEditingController(text: initial ?? '');
  }

  @override
  void didSettleRoute() {
    if (!_watchingProbe) {
      _watchingProbe = true;
      _probe.watch(routedOutbound);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_watchingProbe) {
      _probe.unwatch(routedOutbound);
    }
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

    final riskState = routeSettled && activeIp.isNotEmpty
        ? ref.watch(ipRiskProvider(activeIp))
        : null;
    final locateState = routeSettled && activeIp.isNotEmpty
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
        !routeSettled ||
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
          builder: (context) => NullStatusSwitcher(
            isLoading: !_retrying && isLoading,
            isEmpty: false,
            loadingStatus: const Center(child: ActivityIndicator.page()),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const sidePadding = 16.0;
                final isWide = constraints.maxWidth >= 760;
                final showSubsequentLoading = !_retrying && isLoading;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ListView(
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
                          layoutBuilder: (currentChild, previousChildren) =>
                              Align(
                                alignment: Alignment.topCenter,
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                ),
                              ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child:
                                    child.key is ValueKey<String> &&
                                            (child.key as ValueKey<String>)
                                                .value
                                                .startsWith('data:')
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
                            contentWidth: math.max(
                              0.0,
                              constraints.maxWidth - sidePadding * 2,
                            ),
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
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedSwitcher(
                          duration: context.motionDuration(commonDuration),
                          reverseDuration: context.motionDuration(
                            const Duration(milliseconds: 150),
                          ),
                          switchInCurve: Easing.emphasizedDecelerate,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              ActivityPresence(
                                animation: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: animation.drive(
                                      Tween(begin: 0.92, end: 1.0),
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                          child: showSubsequentLoading
                              ? Center(
                                  key: ValueKey('loading:$activeIp'),
                                  child: const ActivityIndicator.page(),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('loading:idle'),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isWide,
    required double contentWidth,
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
      return SizedBox.shrink(key: ValueKey('loading-slot:$activeIp'));
    }

    if (!isLoading && risk != null && attribution != null) {
      final hasChecks = risk.checks.isNotEmpty;
      final wideWidths = isWide
          ? _wideColumnWidths(context, contentWidth, risk)
          : null;
      final heroCard = RepaintBoundary(
        child: _IpRiskHeroCard(
          ip: activeIp,
          risk: risk,
          hidden: hidden,
          isOutbound: isOutbound,
          fillHeight: isWide && hasChecks,
        ),
      );
      final attributionCard = RepaintBoundary(
        child: IpAttributionCard(
          risk: risk,
          attribution: attribution,
          hidden: hidden,
          isWide: isWide,
          wideCardGap: _wideCardGap,
          wideLeftFlex: _wideLeftFlex,
          wideRightFlex: _wideRightFlex,
          wideLeftWidth: wideWidths?.left,
          wideRightWidth: wideWidths?.right,
        ),
      );
      final flagsCard = hasChecks
          ? RepaintBoundary(
              child: RiskChecksCard(risk: risk, isWide: isWide),
            )
          : null;
      return Column(
        key: ValueKey('data:$activeIp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide) ...[
            if (flagsCard != null && wideWidths != null)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: wideWidths.left, child: heroCard),
                    const SizedBox(width: _wideCardGap),
                    SizedBox(width: wideWidths.right, child: flagsCard),
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
    final scoreColor = riskScoreColor(risk.displayScore);

    final header = Row(
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
        RiskInlineMetrics(risk: risk),
      ],
    );

    final riskScale = RiskScaleSection(risk: risk, animate: true);

    return Card(
      radius: AppCorner.xl,
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
