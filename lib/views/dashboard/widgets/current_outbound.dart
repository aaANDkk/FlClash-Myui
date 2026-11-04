import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/probe_start_hold.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/shapes/shapes.dart';

import 'card.dart';

const _builtinOutbounds = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'};

bool isBuiltinOutbound(String name) => _builtinOutbounds.contains(name);

const _ipMask = '*****';

const _decorationGrowth = 0.06;

const _decorationTurn = 2 * math.pi / 12;

const _decorationBottomGap = 10.0;

/// The address the proxied traffic leaves by, next to the start button.
class CurrentOutboundCard extends ConsumerStatefulWidget {
  const CurrentOutboundCard({super.key});

  @override
  ConsumerState<CurrentOutboundCard> createState() =>
      _CurrentOutboundCardState();
}

class _CurrentOutboundCardState extends ConsumerState<CurrentOutboundCard>
    with ProbeStartHold<CurrentOutboundCard> {
  late final OutboundIpProbe _probe;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier)..watch(routedOutbound);
  }

  @override
  void dispose() {
    _probe.unwatch(routedOutbound);
    super.dispose();
  }

  void _refresh(String? ip) {
    _probe.refresh(const [routedOutbound]);
    if (ip != null && ref.read(ipQualityProvider(ip)).hasError) {
      ref.invalidate(ipQualityProvider(ip));
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final isStart = ref.watch(isStartProvider);
    final suspended = isStart && ref.watch(suspendProvider);
    final rootAccess =
        mitmFeature && (ref.watch(rootAccessProvider).value ?? false);
    final entry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final ipInfo = entry.value;
    final phase = shownPhase(entry);
    final failed = phase == ProbePhase.failed && ipInfo == null;
    final qualityState = ipInfo == null
        ? null
        : ref.watch(ipQualityProvider(ipInfo.ip));
    final quality = qualityState?.value;
    final qualityLoading =
        qualityState != null && quality == null && qualityState.isLoading;
    final loading = ipInfo == null ? !failed : qualityLoading;
    final metrics = _OutboundMetrics.of(density);
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final (chipLabel, chipTone) = suspended
        ? (appLocalizations.suspended, DashboardChipTone.warn)
        : isStart
        ? (appLocalizations.running, DashboardChipTone.ok)
        : (appLocalizations.notRunning, DashboardChipTone.idle);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: rootAccess ? 1 : 0),
      duration: context.motionDuration(commonDuration),
      builder: (context, root, child) => DashboardCard(
        padding: EdgeInsets.zero,
        semanticLabel: rootAccess
            ? '${appLocalizations.status} ${appLocalizations.root}'
            : appLocalizations.status,
        side: root == 0
            ? BorderSide.none
            : BorderSide(
                color: context.colorScheme.primary.withValues(alpha: root),
                width: 1.5,
              ),
        child: child!,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppShape.all(dashboardCardRadius(density)),
                textDirection: Directionality.of(context),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    end: metrics.decorationEnd,
                    bottom: metrics.decorationBottom,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: isStart ? 1 : 0),
                      duration: context.motionDuration(_morphDuration),
                      curve: Curves.easeOutBack,
                      builder: (_, progress, _) => Transform.rotate(
                        angle: _decorationTurn * progress,
                        child: Transform.scale(
                          scale: 1 + _decorationGrowth * progress,
                          child: ShapeBadge(
                            shape: MaterialShapes.cookie12Sided,
                            color: Color.lerp(
                              colors.tone,
                              Color.alphaBlend(
                                colorScheme.primary.withValues(alpha: 0.1),
                                colors.card,
                              ),
                              progress.clamp(0, 1),
                            )!,
                            size: metrics.decorationSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: metrics.padding,
            child: Row(
              spacing: metrics.gap,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardCardHeader(
                        glyph: AppGlyphs.status,
                        title: appLocalizations.status,
                        leading: [
                          DashboardChip(
                            label: chipLabel,
                            tone: chipTone,
                            dot: isStart,
                          ),
                        ],
                      ),
                      if (density.isDesktop)
                        const Spacer()
                      else
                        SizedBox(height: metrics.ipTop),
                      _ExitRow(
                        info: ipInfo,
                        failed: failed,
                        loading: loading,
                        checking: phase == ProbePhase.probing || qualityLoading,
                        onRefresh: () => _refresh(ipInfo?.ip),
                        active: isStart && !suspended,
                        metrics: metrics,
                      ),
                      if (density.isDesktop)
                        const Spacer()
                      else
                        const SizedBox(height: 16),
                      _Cells(
                        quality: quality,
                        loading: loading,
                        active: isStart && !suspended,
                        gap: metrics.cellGap,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: metrics.buttonSlot,
                  child: Center(
                    child: _StartToggle(
                      size: metrics.buttonSize,
                      enabled: hasProfile,
                      running: isStart,
                      suspended: suspended,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutboundMetrics {
  const _OutboundMetrics({
    required this.padding,
    required this.gap,
    required this.ipTop,
    required this.cellGap,
    required this.badgeSize,
    required this.ip,
    required this.buttonSize,
    required this.buttonSlot,
    required this.decorationSize,
    required this.decorationEnd,
  });

  factory _OutboundMetrics.of(DashboardDensity density) => switch (density) {
    DashboardDensity.standard => _OutboundMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      ipTop: 10,
      cellGap: 28,
      badgeSize: 48,
      ip: AppTextStyle.title1,
      buttonSize: 104,
      buttonSlot: 120,
      decorationSize: 268,
      decorationEnd: -52,
    ),
    DashboardDensity.compact => _OutboundMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      ipTop: 8,
      cellGap: 22,
      badgeSize: 40,
      ip: AppTextStyle.title2,
      buttonSize: 84,
      buttonSlot: 100,
      decorationSize: 232,
      decorationEnd: -46,
    ),
    DashboardDensity.mobile => const _OutboundMetrics(
      padding: EdgeInsetsDirectional.fromSTEB(20, 18, 16, 18),
      gap: 10,
      ipTop: 12,
      cellGap: 24,
      badgeSize: 48,
      ip: AppTextStyle.title2,
      buttonSize: 88,
      buttonSlot: 88,
      decorationSize: 216,
      decorationEnd: -48,
    ),
  };

  final EdgeInsetsGeometry padding;
  final double gap;
  final double ipTop;
  final double cellGap;
  final double badgeSize;
  final AppTextStyle ip;
  final double buttonSize;
  final double buttonSlot;
  final double decorationSize;
  final double decorationEnd;

  /// Places the unscaled flower box so that when expanded by [_decorationGrowth],
  /// its lowest lobe rests [_decorationBottomGap] above the card's bottom edge.
  double get decorationBottom =>
      _decorationBottomGap + decorationSize * _decorationGrowth / 2;
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({
    required this.info,
    required this.failed,
    required this.loading,
    required this.checking,
    required this.onRefresh,
    required this.active,
    required this.metrics,
  });

  final IpInfo? info;
  final bool failed;
  final bool loading;
  final bool checking;
  final VoidCallback onRefresh;
  final bool active;
  final _OutboundMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = DashboardText.figure(
      context,
      metrics.ip,
      color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    ).copyWith(letterSpacing: 0, height: 1.15);
    final info = this.info;
    final appLocalizations = context.appLocalizations;
    final Widget ip = info != null
        ? Tooltip(
            message: appLocalizations.details(appLocalizations.outboundIp),
            child: FocusRing(
              shape: AppShape.xs,
              standsOff: true,
              child: PressRegion(
                onTap: () => showIpQualitySheet(context, ip: info.ip),
                shape: AppShape.xs,
                overlay: PressRegion.focusOverlay,
                child: _IpText(ip: info.ip, style: style),
              ),
            ),
          )
        : failed
        ? Text(
            appLocalizations.serviceFailed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: colorScheme.error),
          )
        : SkeletonText(width: 140, style: style);
    final ipHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? metrics.ip.size) * (style.height ?? 1.15));
    return Row(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CountryBadge(
          countryCode: info?.countryCode,
          size: metrics.badgeSize,
          active: active,
          checking: checking,
          onRefresh: onRefresh,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -2.5),
                child: SizedBox(
                  height: ipHeight,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ip,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _ProxyNodeSubText(active: active),
            ],
          ),
        ),
      ],
    );
  }
}

class _IpText extends ConsumerWidget {
  const _IpText({required this.ip, required this.style});

  final String ip;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    if (!hideIp) {
      return DashboardFitText(ip, style: style);
    }
    return DashboardFitText(
      _ipMask,
      style: style.copyWith(
        fontFamily: FontFamily.mapleMono.value,
        color: context.colorScheme.success,
      ),
    );
  }
}

String? _parseNodeFromExit(String? exit) {
  if (exit == null || exit.isEmpty) return null;
  if (exit.startsWith('"')) {
    final buffer = StringBuffer();
    var escaped = false;
    for (var i = 1; i < exit.length; i++) {
      final char = exit[i];
      if (escaped) {
        buffer.write(char);
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        return buffer.toString();
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
  return exit;
}

class _ProxyNodeSubText extends ConsumerWidget {
  const _ProxyNodeSubText({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _cellStyle(context).copyWith(
      fontSize: 14,
      height: 1.1,
      color: active
          ? context.colorScheme.onSurfaceVariant
          : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );
    final subHeight = MediaQuery.textScalerOf(context).scale(18.0);
    return SizedBox(
      height: subHeight,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _buildContent(context, ref, style),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, TextStyle style) {
    if (!active) {
      return Text('—', maxLines: 1, style: style);
    }
    final entry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    if (entry.isLoading) {
      return SkeletonText(width: 80, style: style);
    }
    final hit = entry.stamp?.hits.firstOrNull;
    final nodeName = _parseNodeFromExit(hit?.exit) ??
        (hit?.proxy.isNotEmpty ?? false ? hit?.proxy : null);
    if (nodeName != null && nodeName.isNotEmpty) {
      return _buildNode(context, nodeName, style);
    }
    final groups = ref.watch(currentGroupsStateProvider).value;
    final currentGroupName = ref.watch(
      currentProfileProvider.select((state) => state?.currentGroupName),
    );
    final group = groups.where((g) => g.name == currentGroupName).firstOrNull ??
        groups.firstOrNull;
    if (group != null) {
      final selected = ref.watch(
        realSelectedProxyStateProvider(group.name).select((state) => state.proxyName),
      );
      if (selected.isNotEmpty) {
        return _buildNode(context, selected, style);
      }
    }
    return Text('—', maxLines: 1, style: style);
  }

  Widget _buildNode(BuildContext context, String name, TextStyle style) {
    final nodeStyle = isBuiltinOutbound(name)
        ? style.copyWith(color: context.colorScheme.onSurfaceVariant)
        : style.copyWith(color: context.colorScheme.onSurface);
    return Tooltip(
      message: name,
      child: EmojiText(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nodeStyle,
      ),
    );
  }
}

const _spinPeriod = Duration(milliseconds: 1500);

/// The exit's country on a clover that checks the exit again when tapped and
/// turns while it is being checked.
class _CountryBadge extends StatefulWidget {
  const _CountryBadge({
    required this.countryCode,
    required this.size,
    required this.active,
    required this.checking,
    required this.onRefresh,
  });

  final String? countryCode;
  final double size;
  final bool active;
  final bool checking;
  final VoidCallback onRefresh;

  @override
  State<_CountryBadge> createState() => _CountryBadgeState();
}

class _CountryBadgeState extends State<_CountryBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  );
  var _hovered = false;
  var _focused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spin();
  }

  @override
  void didUpdateWidget(_CountryBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checking != widget.checking) {
      _spin();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  void _spin() {
    if (context.disableAnimations) {
      _turns.value = 0;
    } else if (widget.checking) {
      _turns.repeat();
    } else {
      // A clover looks the same every quarter turn, so it stops on the next.
      final rest = (_turns.value * 4).ceil() / 4;
      _turns.animateTo(rest, duration: _spinPeriod * (rest - _turns.value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foreground = widget.active
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final enabled = !widget.checking;
    final size = widget.size;
    final code = widget.countryCode;
    final tooltip = context.appLocalizations.retry;
    final color = Color.alphaBlend(
      foreground.withValues(alpha: enabled && _hovered ? 0.08 : 0),
      DashboardColors.of(context).tone2,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: PressRegion(
          onTap: enabled ? widget.onRefresh : null,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: ElasticPress(
            enabled: enabled,
            child: AnimatedBuilder(
              animation: _turns,
              builder: (_, child) => ShapeBadge(
                shape: MaterialShapes.clover4Leaf,
                color: color,
                size: size,
                rotation: _turns.value * 2 * math.pi,
                ring: _focused ? focusRingSide(colorScheme) : null,
                child: child,
              ),
              child: code == null || code.isEmpty
                  ? GlyphIcon(
                      AppGlyphs.proxies,
                      size: size * 0.42,
                      color: foreground,
                    )
                  : Text(
                      code.toUpperCase(),
                      maxLines: 1,
                      style: AppTextStyle.footnote
                          .of(context, emphasized: true)
                          .copyWith(
                            color: foreground,
                            letterSpacing: 0.04 * AppTextStyle.footnote.size,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells({
    required this.quality,
    required this.loading,
    required this.active,
    required this.gap,
  });

  final IpQuality? quality;
  final bool loading;
  final bool active;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final typeLabel = quality?.type.label(context);
    final Widget typeValue = typeLabel != null
        ? _CellText(typeLabel)
        : loading
        ? SkeletonText(width: 48, style: _cellStyle(context))
        : const _Placeholder();

    return Row(
      children: [
        _RunTimeCell(active: active),
        SizedBox(width: gap),
        Expanded(
          child: _Cell(
            label: appLocalizations.ipType,
            value: typeValue,
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final cellHeight = MediaQuery.textScalerOf(context).scale(20.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: cellHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: value,
          ),
        ),
      ],
    );
  }
}

TextStyle _cellStyle(BuildContext context) =>
    AppTextStyle.subheadline.of(context, emphasized: true).toTabular;

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _cellStyle(context),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Text('—', maxLines: 1, style: _cellStyle(context));
  }
}

double _measureTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _runTimeSlotWidth(BuildContext context, int hourDigits) {
  final style = _cellStyle(context);
  final labelStyle = DashboardText.label(context);
  final count = math.max(2, hourDigits);
  final template8 = '${'8' * count}:88:88';
  final template0 = '${'0' * count}:00:00';
  final template4 = '${'4' * count}:44:44';
  final template9 = '${'9' * count}:99:99';
  final w8 = _measureTextWidth(context, template8, style);
  final w0 = _measureTextWidth(context, template0, style);
  final w4 = _measureTextWidth(context, template4, style);
  final w9 = _measureTextWidth(context, template9, style);
  final valueWidth = math.max(math.max(w8, w0), math.max(w4, w9));
  final labelWidth = _measureTextWidth(
    context,
    context.appLocalizations.runTime,
    labelStyle,
  );
  return math.max(valueWidth, labelWidth) + 1.0;
}

class _RunTimeCell extends ConsumerWidget {
  const _RunTimeCell({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final String timeText;
    final int hourDigits;
    if (active) {
      timeText = getTimeText(ref.watch(runTimeProvider));
      final colon = timeText.indexOf(':');
      hourDigits = colon == -1 ? 2 : math.max(2, colon);
    } else {
      timeText = '00:00:00';
      hourDigits = 2;
    }
    final slotWidth = _runTimeSlotWidth(context, hourDigits);

    return SizedBox(
      width: slotWidth,
      child: _Cell(
        label: appLocalizations.runTime,
        value: _CellText(timeText),
      ),
    );
  }
}

const _morphDuration = Duration(milliseconds: 450);
const _stateDuration = Duration(milliseconds: 150);

final _startMorph = Morph(MaterialShapes.circle, MaterialShapes.cookie9Sided);

Path _morphPath(double progress) => _startMorph.toPath(progress: progress);

double _morphTurn(double progress) => progress * 2 * math.pi / 9;

/// A circle with a play glyph while stopped that grows the cookie-9 of a
/// running tunnel, the way the M3 Expressive loader morphs between shapes.
class _StartToggle extends ConsumerStatefulWidget {
  const _StartToggle({
    required this.size,
    required this.enabled,
    required this.running,
    required this.suspended,
  });

  final double size;
  final bool enabled;
  final bool running;
  final bool suspended;

  @override
  ConsumerState<_StartToggle> createState() => _StartToggleState();
}

class _StartToggleState extends ConsumerState<_StartToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _morphDuration,
    value: widget.running ? 1 : 0,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  var _hovered = false;
  var _pressed = false;
  var _focused = false;

  /// The M3 state layer, painted inside the shape: the card's decoration
  /// covers the button, so ink on the card would never show.
  double get _overlay => !widget.enabled
      ? 0
      : _focused
      ? 0.1
      : _hovered
      ? 0.08
      : 0;

  @override
  void didUpdateWidget(_StartToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      widget.running ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final glass = LiquidGlassScope.of(context);
    final size = widget.size;
    final enabled = widget.enabled;
    final fill = enabled
        ? colorScheme.primary
        : DashboardColors.of(context).tone2;
    final ink = enabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final tooltip = widget.suspended
        ? appLocalizations.suspended
        : widget.running
        ? appLocalizations.stop
        : appLocalizations.start;
    final stateDuration = context.motionDuration(_stateDuration);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: PressRegion(
          onTap: enabled ? _toggle : null,
          onHover: (value) => setState(() => _hovered = value),
          onPressedChanged: (value) => setState(() => _pressed = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: ElasticPress(
            enabled: enabled,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _overlay),
              duration: stateDuration,
              builder: (_, overlay, child) => AnimatedBuilder(
                animation: _progress,
                builder: (_, child) {
                  final progress = _progress.value;
                  final color = Color.alphaBlend(
                    ink.withValues(alpha: overlay),
                    fill,
                  );
                  return CustomPaint(
                    painter: _MorphPainter(
                      progress: progress,
                      color: glass ? null : color,
                      shadow: enabled
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                      ring: _focused
                          ? focusRingSide(colorScheme, standsOff: true)
                          : null,
                    ),
                    child: glass
                        ? LiquidGlass(
                            style: LiquidGlassStyle.tinted(colorScheme, color),
                            clipper: _MorphClipper(progress),
                            pressed: _pressed,
                            child: child,
                          )
                        : child,
                  );
                },
                child: child,
              ),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: widget.suspended
                      ? GlyphIcon(
                          AppGlyphs.wifiOff,
                          size: size * 0.34,
                          color: ink,
                          fill: 1,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: widget.running ? 1 : 0),
                          duration: _morphDuration,
                          curve: Curves.easeOutBack,
                          builder: (_, progress, _) => GlyphIcon(
                            AppGlyphs.playPause(progress),
                            size: size * 0.34,
                            color: ink,
                            fill: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fills the morph, or with no [color] leaves its inside to glass and casts
/// [shadow] only outside it, as one under glass would show through.
class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.progress,
    required this.color,
    required this.shadow,
    required this.ring,
  });

  static const _shadowOffset = Offset(0, 6);
  static const _shadowBlur = 14.0;

  final double progress;
  final Color? color;
  final Color shadow;
  final BorderSide? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _morphPath(progress);
    final color = this.color;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(_morphTurn(progress))
      ..scale(size.width, size.height)
      ..translate(-0.5, -0.5);
    if (shadow.a > 0) {
      canvas.save();
      if (color == null) {
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(const Rect.fromLTRB(-1, -1, 2, 2))
            ..addPath(path, Offset.zero),
        );
      }
      canvas
        ..translate(
          _shadowOffset.dx / size.width,
          _shadowOffset.dy / size.height,
        )
        ..drawPath(
          path,
          Paint()
            ..color = shadow
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _shadowBlur / 2 / size.width,
            ),
        )
        ..restore();
    }
    if (color != null) {
      canvas.drawPath(path, Paint()..color = color);
    }
    if (ring case final ring?) {
      strokeUnitShape(canvas, path, size.width, ring);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.shadow != shadow ||
      oldDelegate.ring != ring;
}

class _MorphClipper extends CustomClipper<Path> {
  const _MorphClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final transform =
        Matrix4.translationValues(size.width / 2, size.height / 2, 0)
          ..rotateZ(_morphTurn(progress))
          ..scaleByDouble(size.width, size.height, 1, 1)
          ..translateByDouble(-0.5, -0.5, 0, 1);
    return _morphPath(progress).transform(transform.storage);
  }

  @override
  bool shouldReclip(_MorphClipper oldClipper) =>
      oldClipper.progress != progress;
}
