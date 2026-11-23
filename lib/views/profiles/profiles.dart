import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'boarding_pass.dart';
import 'profile_icon.dart';

const _infoGap = 3.0;
const _cardVerticalPadding = 13.0;
const _wideBoardingPassBreakpoint = 720.0;

double get _profileItemHeight {
  final measure = globalState.measure;
  final textColumnHeight =
      measure.textHeight(AppTextStyle.headline) +
      _infoGap +
      measure.textHeight(AppTextStyle.footnote);
  return math.max(42.0, textColumnHeight) + 2 * _cardVerticalPadding;
}

class ProfilesView extends ConsumerStatefulWidget {
  const ProfilesView({super.key, this.picker = false});

  /// Clears the bar and opens at the top, for switching profiles from a sheet.
  final bool picker;

  @override
  ConsumerState<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends ConsumerState<ProfilesView> {
  bool _isUpdating = false;

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating == true) {
      return;
    }
    _isUpdating = true;
    final appLocalizations = context.appLocalizations;
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final List<UpdatingMessage> messages = [];
    final updateProfiles = profiles.map<Future>((profile) async {
      if (profile.type != ProfileType.url) return;
      try {
        await profilesAction.updateProfile(profile, showLoading: true);
      } catch (e) {
        messages.add(
          UpdatingMessage(
            label: profile.realLabel,
            message: userFacingErrorMessage(e, appLocalizations),
          ),
        );
      }
    });
    await Future.wait(updateProfiles);
    dialogs.showFailures(messages);
    _isUpdating = false;
  }

  List<IconButtonData> _buildActions(List<Profile> profiles) {
    return profiles.isNotEmpty
        ? [
            IconButtonData(
              glyph: AppGlyphs.sync,
              onPressed: () {
                _updateProfiles(profiles);
              },
              tooltip: context.appLocalizations.update,
            ),
            IconButtonData(
              glyph: AppGlyphs.sort,
              onPressed: () {
                showNestedSheet(
                  context,
                  builder: (_) {
                    return ReorderableProfilesSheet(profiles: profiles);
                  },
                );
              },
              tooltip: context.appLocalizations.profilesSort,
            ),
          ]
        : [];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final appLocalizations = context.appLocalizations;
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);
        final spacing = cardSpacingOf(context, ref.watch(viewModeProvider));
        final picker = widget.picker;
        return Scaffold(
          isLoading: isLoading,
          title: appLocalizations.profiles,
          iconActions: picker ? const [] : _buildActions(state.profiles),
          actions: state.profiles.isEmpty || picker
              ? null
              : [
                  AddProfileMenu(
                    builder: (open) => IconButton(
                      tooltip: appLocalizations.addProfile,
                      onPressed: open,
                      icon: const GlyphIcon(AppGlyphs.addCircle),
                    ),
                  ),
                ],
          body: NullStatusSwitcher(
            isEmpty: state.profiles.isEmpty,
            nullStatus: NullStatus(
              label: appLocalizations.nullTip(appLocalizations.profiles),
              description: appLocalizations.nullProfileDesc,
              illustration: NullStatusIllustration.profile,
              action: AddProfileMenu(
                builder: (open) => TonalButton(
                  size: TonalButtonSize.bar,
                  glyph: AppGlyphs.addCircle,
                  label: appLocalizations.addProfile,
                  onPressed: open,
                ),
              ),
            ),
            child: _ProfilesContent(
              profiles: state.profiles,
              currentProfileId: state.currentProfileId,
              spacing: spacing,
              picker: picker,
            ),
          ),
        );
      },
    );
  }
}

class _ProfilesContent extends ConsumerStatefulWidget {
  const _ProfilesContent({
    required this.profiles,
    required this.currentProfileId,
    required this.spacing,
    required this.picker,
  });

  final List<Profile> profiles;
  final int? currentProfileId;
  final double spacing;
  final bool picker;

  @override
  ConsumerState<_ProfilesContent> createState() => _ProfilesContentState();
}

class _ProfileSwapSnapshot {
  const _ProfileSwapSnapshot({
    required this.oldProfile,
    required this.newProfileId,
    required this.clickedRect,
    required this.oldHeroLeftRect,
    required this.oldHeroRightRect,
    required this.oldOtherIds,
    required this.oldItemRects,
    required this.scrollOffset,
    required this.duration,
    required this.layoutWidth,
    required this.columns,
    required this.isWide,
    required this.textDirection,
  });

  final Profile oldProfile;
  final int newProfileId;
  final Rect clickedRect;
  final Rect oldHeroLeftRect;
  final Rect? oldHeroRightRect;
  final List<int> oldOtherIds;
  final Map<int, Rect> oldItemRects;
  final double scrollOffset;
  final Duration duration;
  final double layoutWidth;
  final int columns;
  final bool isWide;
  final TextDirection textDirection;
}

class _ActiveProfileSwap {
  const _ActiveProfileSwap({
    required this.oldProfile,
    required this.newProfile,
    required this.clickedRect,
    required this.oldHeroLeftRect,
    required this.oldHeroRightRect,
    required this.targetHeroLeftRect,
    required this.targetHeroRightRect,
    required this.itemDeltas,
    required this.demotedProfileId,
    required this.demoteFromHeroOffset,
    required this.ghostDriftOffset,
    required this.layoutWidth,
    required this.columns,
    required this.isWide,
    required this.textDirection,
  });

  final Profile oldProfile;
  final Profile newProfile;
  final Rect clickedRect;
  final Rect oldHeroLeftRect;
  final Rect? oldHeroRightRect;
  final Rect targetHeroLeftRect;
  final Rect? targetHeroRightRect;
  final Map<int, Offset> itemDeltas;
  final int demotedProfileId;
  final Offset demoteFromHeroOffset;
  final Offset ghostDriftOffset;
  final double layoutWidth;
  final int columns;
  final bool isWide;
  final TextDirection textDirection;
}

class _HeroMorphClipper extends CustomClipper<Path> {
  const _HeroMorphClipper({
    required this.startWidth,
    required this.startHeight,
    required this.progress,
    required this.radius,
    required this.textDirection,
  });

  final double startWidth;
  final double startHeight;
  final double progress;
  final double radius;
  final TextDirection textDirection;

  @override
  Path getClip(Size size) {
    final w = (startWidth + (size.width - startWidth) * progress).clamp(
      0.0,
      size.width,
    );
    final h = (startHeight + (size.height - startHeight) * progress).clamp(
      0.0,
      size.height,
    );
    final left = textDirection == TextDirection.rtl ? size.width - w : 0.0;
    return AppShape.all(radius).getOuterPath(Rect.fromLTWH(left, 0, w, h));
  }

  @override
  bool shouldReclip(_HeroMorphClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.startWidth != startWidth ||
      oldClipper.startHeight != startHeight ||
      oldClipper.radius != radius ||
      oldClipper.textDirection != textDirection;
}

class _AnimatedHeroHeightBox extends SingleChildRenderObjectWidget {
  const _AnimatedHeroHeightBox({
    required this.fromHeight,
    required this.animation,
    required this.curve,
    required super.child,
  });

  final double? fromHeight;
  final Animation<double> animation;
  final Curve curve;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAnimatedHeroHeightBox(
        fromHeight: fromHeight,
        animation: animation,
        curve: curve,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnimatedHeroHeightBox renderObject,
  ) {
    renderObject
      ..fromHeight = fromHeight
      ..animation = animation
      ..curve = curve;
  }
}

class _RenderAnimatedHeroHeightBox extends RenderProxyBox {
  _RenderAnimatedHeroHeightBox({
    required double? fromHeight,
    required Animation<double> animation,
    required Curve curve,
  }) : _fromHeight = fromHeight,
       _animation = animation,
       _curve = curve;

  double? _fromHeight;
  double? _lastTargetHeight;
  bool _listening = false;

  set fromHeight(double? value) {
    if (_fromHeight == value) return;
    _fromHeight = value;
    _lastTargetHeight = null;
    _syncListener();
    markNeedsLayout();
  }

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(_animation, value)) return;
    if (attached && _listening) {
      _animation.removeListener(_onTick);
    }
    _animation = value;
    if (attached && _listening) {
      _animation.addListener(_onTick);
    }
    markNeedsLayout();
  }

  Curve _curve;
  set curve(Curve value) {
    if (_curve == value) return;
    _curve = value;
    markNeedsLayout();
  }

  void _syncListener() {
    final shouldListen = attached && _fromHeight != null;
    if (shouldListen == _listening) return;
    if (shouldListen) {
      _animation.addListener(_onTick);
    } else {
      _animation.removeListener(_onTick);
    }
    _listening = shouldListen;
  }

  void _onTick() {
    final from = _fromHeight;
    final target = _lastTargetHeight;
    if (from != null && target != null && (from - target).abs() < 0.5) {
      return;
    }
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncListener();
  }

  @override
  void detach() {
    if (_listening) {
      _animation.removeListener(_onTick);
      _listening = false;
    }
    super.detach();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final targetHeight = child.size.height;
    _lastTargetHeight = targetHeight;
    final from = _fromHeight;
    final currentHeight = from == null
        ? targetHeight
        : from + (targetHeight - from) * _curve.transform(_animation.value);
    size = constraints.constrain(Size(child.size.width, currentHeight));
  }
}

class _FlyingShadowPainter extends CustomPainter {
  const _FlyingShadowPainter({
    required this.startWidth,
    required this.startHeight,
    required this.progress,
    required this.radius,
    required this.textDirection,
    required this.shadowColor,
    required this.isDark,
  });

  final double startWidth;
  final double startHeight;
  final double progress;
  final double radius;
  final TextDirection textDirection;
  final Color shadowColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = (1 - progress).clamp(0.0, 1.0);
    if (strength <= 0.005) return;
    final w = (startWidth + (size.width - startWidth) * progress).clamp(
      0.0,
      size.width,
    );
    final h = (startHeight + (size.height - startHeight) * progress).clamp(
      0.0,
      size.height,
    );
    final left = textDirection == TextDirection.rtl ? size.width - w : 0.0;
    final rect = Rect.fromLTWH(left, 0, w, h);
    final shadow = BoxShadow(
      color: shadowColor.withValues(
        alpha: (isDark ? 0.34 : 0.14) * strength,
      ),
      blurRadius: 24 * strength + 4,
      offset: Offset(0, 10 * strength),
    );
    final path = AppShape.all(radius).getOuterPath(rect.shift(shadow.offset));
    canvas.drawPath(path, shadow.toPaint());
  }

  @override
  bool shouldRepaint(_FlyingShadowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.startWidth != startWidth ||
      oldDelegate.startHeight != startHeight ||
      oldDelegate.radius != radius ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.isDark != isDark;
}

class _ProfilesContentState extends ConsumerState<_ProfilesContent>
    with SingleTickerProviderStateMixin {
  static const _horizontalPadding = 16.0;
  static const _swapDuration = Duration(milliseconds: 380);
  static const _flipCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const _metricsRevealCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  ScrollController? _controller;
  late final AnimationController _swapController;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _heroLeftKey = GlobalKey();
  final GlobalKey _heroRightKey = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = {};

  _ProfileSwapSnapshot? _pendingSwap;
  _ActiveProfileSwap? _activeSwap;

  double _layoutWidth = 0;
  int _layoutColumns = 1;
  bool _layoutIsWide = false;
  TextDirection _layoutTextDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _swapController = AnimationController(vsync: this, duration: _swapDuration)
      ..addStatusListener(_onSwapStatus);
  }

  void _onSwapStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_activeSwap != null && mounted) {
        setState(() {
          _activeSwap = null;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ProfilesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validIds = {for (final profile in widget.profiles) profile.id};
    _itemKeys.removeWhere((id, _) => !validIds.contains(id));

    if (widget.picker) {
      _pendingSwap = null;
      _cancelSwap();
      return;
    }

    if (widget.currentProfileId != oldWidget.currentProfileId) {
      final snapshot = _pendingSwap;
      _pendingSwap = null;
      if (snapshot != null &&
          snapshot.newProfileId == widget.currentProfileId &&
          snapshot.oldProfile.id == oldWidget.currentProfileId) {
        _startSwap(snapshot);
      } else {
        _cancelSwap();
      }
    }
  }

  void _cancelSwap() {
    if (_swapController.isAnimating) {
      _swapController.stop();
    }
    _activeSwap = null;
  }

  @override
  void dispose() {
    _swapController.removeStatusListener(_onSwapStatus);
    _swapController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  GlobalKey _keyForItem(int id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  Rect? _rectOf(GlobalKey? key) {
    if (key == null) return null;
    final root = _stackKey.currentContext?.findRenderObject();
    final box = key.currentContext?.findRenderObject();
    if (root is! RenderBox || box is! RenderBox || !box.hasSize) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: root);
    return origin & box.size;
  }

  int _columnsFor(double width) {
    final contentWidth = width - _horizontalPadding * 2;
    if (width < _wideBoardingPassBreakpoint) {
      return 1;
    }
    return getProfilesColumns(
      contentWidth,
      spacing: widget.spacing,
      minItemWidth: profileItemMinWidth.ap(context),
    ).clamp(1, 3);
  }

  void _selectProfile(int? profileId) {
    if (widget.picker ||
        profileId == null ||
        profileId == widget.currentProfileId) {
      ref.read(currentProfileIdProvider.notifier).value = profileId;
      return;
    }

    final duration = context.motionDuration(_swapDuration);
    final oldProfile = widget.profiles.getProfile(widget.currentProfileId);
    final clickedRect = _rectOf(_itemKeys[profileId]);
    final heroLeftRect = _rectOf(_heroLeftKey);
    final heroRightRect = _layoutIsWide ? _rectOf(_heroRightKey) : null;

    if (duration > Duration.zero &&
        oldProfile != null &&
        clickedRect != null &&
        heroLeftRect != null) {
      final scrollOffset = (_controller != null && _controller!.hasClients)
          ? _controller!.offset
          : 0.0;
      final oldOtherIds = [
        for (final p in widget.profiles)
          if (p.id != oldProfile.id) p.id,
      ];
      final oldItemRects = <int, Rect>{};
      for (final id in oldOtherIds) {
        final rect = _rectOf(_itemKeys[id]);
        if (rect != null) {
          oldItemRects[id] = rect;
        }
      }
      _pendingSwap = _ProfileSwapSnapshot(
        oldProfile: oldProfile,
        newProfileId: profileId,
        clickedRect: clickedRect,
        oldHeroLeftRect: heroLeftRect,
        oldHeroRightRect: heroRightRect,
        oldOtherIds: oldOtherIds,
        oldItemRects: oldItemRects,
        scrollOffset: scrollOffset,
        duration: duration,
        layoutWidth: _layoutWidth,
        columns: _layoutColumns,
        isWide: _layoutIsWide,
        textDirection: _layoutTextDirection,
      );
      if (scrollOffset > 4 && _controller != null && _controller!.hasClients) {
        unawaited(
          _controller!.animateTo(0, duration: duration, curve: _flipCurve),
        );
      }
    } else {
      _pendingSwap = null;
    }

    ref.read(currentProfileIdProvider.notifier).value = profileId;
  }

  void _startSwap(_ProfileSwapSnapshot snapshot) {
    final newProfile = widget.profiles.getProfile(snapshot.newProfileId);
    if (newProfile == null) {
      _cancelSwap();
      return;
    }

    final newOtherIds = [
      for (final p in widget.profiles)
        if (p.id != newProfile.id) p.id,
    ];

    final columns = snapshot.columns;
    final spacing = widget.spacing;
    final contentWidth = math.max(
      0.0,
      snapshot.layoutWidth - _horizontalPadding * 2,
    );
    final cellWidth = columns > 0
        ? math.max(0.0, (contentWidth - (columns - 1) * spacing) / columns)
        : contentWidth;
    final colStride = cellWidth + spacing;
    final rowStride = _profileItemHeight + spacing;
    final rtlSign = snapshot.textDirection == TextDirection.rtl ? -1.0 : 1.0;

    final oldIndexById = <int, int>{
      for (var i = 0; i < snapshot.oldOtherIds.length; i++)
        snapshot.oldOtherIds[i]: i,
    };

    final itemDeltas = <int, Offset>{};
    for (var newIdx = 0; newIdx < newOtherIds.length; newIdx++) {
      final id = newOtherIds[newIdx];
      final oldIdx = oldIndexById[id];
      if (oldIdx == null || oldIdx == newIdx) continue;
      final oldCol = oldIdx % columns;
      final oldRow = oldIdx ~/ columns;
      final newCol = newIdx % columns;
      final newRow = newIdx ~/ columns;
      final dx = (oldCol - newCol) * colStride * rtlSign;
      final dy = (oldRow - newRow) * rowStride;
      if (dx != 0 || dy != 0) {
        itemDeltas[id] = Offset(dx, dy);
      }
    }

    final scrollShift = Offset(0, snapshot.scrollOffset);
    final targetHeroLeftRect = snapshot.oldHeroLeftRect.shift(scrollShift);
    final targetHeroRightRect = snapshot.oldHeroRightRect?.shift(scrollShift);

    final oldProfileNewIdx = newOtherIds.indexOf(snapshot.oldProfile.id);
    var demoteFromHeroOffset = const Offset(0, -32);
    var ghostDriftOffset = const Offset(0, 26);
    if (oldProfileNewIdx >= 0) {
      Offset? gridOrigin;
      for (var i = 0; i < snapshot.oldOtherIds.length; i++) {
        final rect = snapshot.oldItemRects[snapshot.oldOtherIds[i]];
        if (rect != null) {
          final col = i % columns;
          final row = i ~/ columns;
          gridOrigin = Offset(
            rect.left - col * colStride * rtlSign,
            rect.top - row * rowStride,
          ) + scrollShift;
          break;
        }
      }
      final newCol = oldProfileNewIdx % columns;
      final newRow = oldProfileNewIdx ~/ columns;
      final slotTopLeft = gridOrigin != null
          ? Offset(
              gridOrigin.dx + newCol * colStride * rtlSign,
              gridOrigin.dy + newRow * rowStride,
            )
          : Offset(
              targetHeroLeftRect.left + newCol * colStride * rtlSign,
              targetHeroLeftRect.bottom + 44 + newRow * rowStride,
            );
      final heroToSlot = slotTopLeft - snapshot.oldHeroLeftRect.topLeft;
      ghostDriftOffset = heroToSlot * 0.35;
      demoteFromHeroOffset = -heroToSlot * 0.45;
    }

    _activeSwap = _ActiveProfileSwap(
      oldProfile: snapshot.oldProfile,
      newProfile: newProfile,
      clickedRect: snapshot.clickedRect,
      oldHeroLeftRect: snapshot.oldHeroLeftRect,
      oldHeroRightRect: snapshot.oldHeroRightRect,
      targetHeroLeftRect: targetHeroLeftRect,
      targetHeroRightRect: targetHeroRightRect,
      itemDeltas: itemDeltas,
      demotedProfileId: snapshot.oldProfile.id,
      demoteFromHeroOffset: demoteFromHeroOffset,
      ghostDriftOffset: ghostDriftOffset,
      layoutWidth: snapshot.layoutWidth,
      columns: columns,
      isWide: snapshot.isWide,
      textDirection: snapshot.textDirection,
    );

    _swapController.duration = snapshot.duration;
    _swapController.forward(from: 0);
  }

  Widget _wrapAnimatedGridItem(
    Profile profile,
    Widget item,
    _ActiveProfileSwap? swap,
  ) {
    if (swap == null) return item;

    if (profile.id == swap.demotedProfileId) {
      const enterInterval = Interval(45 / 380, 1.0, curve: _flipCurve);
      return AnimatedBuilder(
        animation: _swapController,
        child: item,
        builder: (context, child) {
          final t = enterInterval.transform(_swapController.value);
          final offset = Offset.lerp(swap.demoteFromHeroOffset, Offset.zero, t)!;
          final scale = 0.96 + 0.04 * t;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: offset,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          );
        },
      );
    }

    final delta = swap.itemDeltas[profile.id];
    if (delta == null) return item;

    return AnimatedBuilder(
      animation: _swapController,
      child: item,
      builder: (context, child) {
        final t = _flipCurve.transform(_swapController.value);
        final offset = Offset.lerp(delta, Offset.zero, t)!;
        return Transform.translate(offset: offset, child: child);
      },
    );
  }

  double? _liveHeightOf(GlobalKey key) {
    if (_swapController.value <= 0.0) return null;
    final obj = key.currentContext?.findRenderObject();
    if (obj is RenderBox && obj.hasSize) {
      return obj.size.height;
    }
    return null;
  }

  Widget _buildSwapOverlay(BuildContext context, _ActiveProfileSwap swap) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final isRtl = swap.textDirection == TextDirection.rtl;

    const oldPrimaryOut = Interval(0.0, 220 / 380, curve: Curves.easeOut);
    const oldActionsOut = Interval(0.0, 150 / 380, curve: Curves.easeOut);
    const newActionsIn = Interval(45 / 380, 355 / 380, curve: _flipCurve);
    const metricsReveal = Interval(
      110 / 380,
      350 / 380,
      curve: _metricsRevealCurve,
    );

    final oldPrimaryGhost = ProfileBoardingPass(
      profile: swap.oldProfile,
      isWide: swap.isWide,
      spacing: widget.spacing,
      part: HeroCardPart.primaryOnly,
    );

    final oldActionsGhost = swap.isWide && swap.oldHeroRightRect != null
        ? ProfileBoardingPass(
            profile: swap.oldProfile,
            isWide: true,
            spacing: widget.spacing,
            part: HeroCardPart.actionsOnly,
          )
        : null;

    final newActionsCard = swap.isWide && swap.targetHeroRightRect != null
        ? ProfileBoardingPass(
            profile: swap.newProfile,
            isWide: true,
            spacing: widget.spacing,
            part: HeroCardPart.actionsOnly,
          )
        : null;

    final startDelta = isRtl
        ? swap.clickedRect.topRight - swap.targetHeroLeftRect.topRight
        : swap.clickedRect.topLeft - swap.targetHeroLeftRect.topLeft;

    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Layer 1: Retreating old hero primary card ghost.
              Positioned.fromRect(
                rect: swap.oldHeroLeftRect,
                child: AnimatedBuilder(
                  animation: _swapController,
                  child: oldPrimaryGhost,
                  builder: (context, child) {
                    final t = oldPrimaryOut.transform(_swapController.value);
                    final offset = Offset.lerp(
                      Offset.zero,
                      swap.ghostDriftOffset,
                      t,
                    )!;
                    final scale = 1.0 - 0.05 * t;
                    return Opacity(
                      opacity: (1.0 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: offset,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Layer 1b: Retreating old landscape right action card ghost.
              if (oldActionsGhost != null && swap.oldHeroRightRect != null)
                Positioned.fromRect(
                  rect: swap.oldHeroRightRect!,
                  child: AnimatedBuilder(
                    animation: _swapController,
                    child: oldActionsGhost,
                    builder: (context, child) {
                      final t = oldActionsOut.transform(_swapController.value);
                      final scale = 1.0 - 0.03 * t;
                      return Opacity(
                        opacity: (1.0 - t).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              // Layer 2: Staggered entering new landscape right action card.
              // Tracks the real new right card height (from IntrinsicHeight) so
              // switching between different profile heights (e.g. URL <-> YAML)
              // settles with 0px snap.
              if (newActionsCard != null && swap.targetHeroRightRect != null)
                Positioned(
                  left: swap.targetHeroRightRect!.left,
                  top: swap.targetHeroRightRect!.top,
                  width: swap.targetHeroRightRect!.width,
                  child: AnimatedBuilder(
                    animation: _swapController,
                    child: newActionsCard,
                    builder: (context, child) {
                      final t = newActionsIn.transform(_swapController.value);
                      final scale = 0.975 + 0.025 * t;
                      final targetHeight = _liveHeightOf(_heroRightKey);
                      return SizedBox(
                        height: targetHeight,
                        child: Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - t)),
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.center,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Layer 3 (top): Flying promoted card gliding & unfolding into hero.
              // Tracks the real new left card height so remote/YAML/custom cards
              // of differing heights unfold cleanly to their exact landing size.
              Positioned(
                left: swap.targetHeroLeftRect.left,
                top: swap.targetHeroLeftRect.top,
                width: swap.targetHeroLeftRect.width,
                child: AnimatedBuilder(
                  animation: _swapController,
                  builder: (context, _) {
                    final raw = _swapController.value;
                    final t = _flipCurve.transform(raw);
                    final reveal = metricsReveal.transform(raw);
                    final offset = Offset.lerp(startDelta, Offset.zero, t)!;
                    final targetHeight = _liveHeightOf(_heroLeftKey);
                    return Transform.translate(
                      offset: offset,
                      child: SizedBox(
                        height: targetHeight,
                        child: CustomPaint(
                          painter: _FlyingShadowPainter(
                            startWidth: swap.clickedRect.width,
                            startHeight: swap.clickedRect.height,
                            progress: t,
                            radius: AppCorner.xl,
                            textDirection: swap.textDirection,
                            shadowColor: colorScheme.shadow,
                            isDark: isDark,
                          ),
                          child: ClipPath(
                            clipper: _HeroMorphClipper(
                              startWidth: swap.clickedRect.width,
                              startHeight: swap.clickedRect.height,
                              progress: t,
                              radius: AppCorner.xl,
                              textDirection: swap.textDirection,
                            ),
                            child: ProfileBoardingPass(
                              profile: swap.newProfile,
                              isWide: swap.isWide,
                              spacing: widget.spacing,
                              part: HeroCardPart.primaryOnly,
                              metricsReveal: reveal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
    final profiles = widget.profiles;
    final topPadding = context.contentTopPadding;
    final bottomPadding = 16 + context.bottomInset;
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _controller ??= sheetScrollController(context);
        final width = constraints.maxWidth;
        final isWide = width >= _wideBoardingPassBreakpoint;
        final columns = _columnsFor(width);
        _layoutWidth = width;
        _layoutColumns = columns;
        _layoutIsWide = isWide;
        _layoutTextDirection = textDirection;

        if (_activeSwap != null &&
            ((width - _activeSwap!.layoutWidth).abs() > 1.0 ||
                isWide != _activeSwap!.isWide ||
                columns != _activeSwap!.columns)) {
          _cancelSwap();
        }

        if (widget.picker) {
          return GridView.builder(
            key: profilesStoreKey,
            controller: _controller,
            padding: EdgeInsets.fromLTRB(
              _horizontalPadding,
              topPadding,
              _horizontalPadding,
              bottomPadding,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: widget.spacing,
              crossAxisSpacing: widget.spacing,
              mainAxisExtent: _profileItemHeight,
            ),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return ProfileItem(
                key: ValueKey(profile.id),
                profile: profile,
                groupValue: widget.currentProfileId,
                showSelectionBadge: true,
                onChanged: _selectProfile,
              );
            },
          );
        }

        final activeProfile = profiles.getProfile(widget.currentProfileId);
        final otherProfiles = activeProfile == null
            ? profiles
            : [
                for (final profile in profiles)
                  if (profile.id != activeProfile.id) profile,
              ];
        final activeSwap = _activeSwap;
        final isSwapping = activeSwap != null;

        return Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            CustomScrollView(
              key: profilesStoreKey,
              controller: _controller,
              slivers: [
                if (activeProfile != null)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      _horizontalPadding,
                      topPadding,
                      _horizontalPadding,
                      otherProfiles.isEmpty ? bottomPadding : 0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _AnimatedHeroHeightBox(
                        fromHeight: activeSwap?.oldHeroLeftRect.height,
                        animation: _swapController,
                        curve: _flipCurve,
                        child: ProfileBoardingPass(
                          key: ValueKey('hero-${activeProfile.id}'),
                          profile: activeProfile,
                          isWide: isWide,
                          spacing: widget.spacing,
                          primaryCardKey: _heroLeftKey,
                          actionsCardKey: _heroRightKey,
                          hidePrimary: isSwapping,
                          hideActions: isSwapping && isWide,
                        ),
                      ),
                    ),
                  ),
                if (otherProfiles.isNotEmpty) ...[
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: _horizontalPadding,
                      right: _horizontalPadding,
                      top: activeProfile != null ? 0 : topPadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: ListHeader(
                        title: context.appLocalizations.otherProfiles,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      _horizontalPadding,
                      0,
                      _horizontalPadding,
                      bottomPadding,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: widget.spacing,
                        crossAxisSpacing: widget.spacing,
                        mainAxisExtent: _profileItemHeight,
                      ),
                      itemCount: otherProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = otherProfiles[index];
                        final item = KeyedSubtree(
                          key: _keyForItem(profile.id),
                          child: ProfileItem(
                            key: ValueKey(profile.id),
                            profile: profile,
                            groupValue: widget.currentProfileId,
                            onChanged: _selectProfile,
                          ),
                        );
                        return _wrapAnimatedGridItem(profile, item, activeSwap);
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (activeSwap != null) _buildSwapOverlay(context, activeSwap),
          ],
        );
      },
    );
  }
}

class ProfileItem extends ConsumerWidget {
  final Profile profile;
  final int? groupValue;
  final void Function(int? value) onChanged;
  final bool showSelectionBadge;

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
    this.showSelectionBadge = false,
  });

  Widget _buildRightAnchor(
    BuildContext context, {
    required bool isUpdating,
    required int? customCount,
  }) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    if (isUpdating) {
      return const ActivityIndicator(size: 22);
    }

    final expired = profileIsExpired(profile);
    if (expired) {
      return TitleChip(label: l.expired, color: colorScheme.error);
    }

    final primaryStyle = AppTextStyle.footnote
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: colorScheme.onSurface, height: 1.15);
    final secondaryStyle = AppTextStyle.caption2
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant, height: 1.15);

    Widget labeledAnchor({
      required String top,
      required String bottom,
      required Widget graphic,
      String? tooltip,
    }) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(top, maxLines: 1, style: primaryStyle),
              const SizedBox(height: 2),
              Text(bottom, maxLines: 1, style: secondaryStyle),
            ],
          ),
          graphic,
        ],
      );
      return tooltip == null ? row : Tooltip(message: tooltip, child: row);
    }

    final usage = profileUsageOf(profile);
    if (usage != null) {
      return labeledAnchor(
        top: dashboardTraffic(usage.remaining),
        bottom: l.remainingShort,
        graphic: ProfileTrafficRing(share: usage.share, size: 28),
      );
    }

    return switch (profile.type) {
      ProfileType.url => labeledAnchor(
        top: l.infiniteTime,
        bottom: l.remote,
        graphic: const ProfileTypeBadgeCircle(type: ProfileType.url, size: 28),
      ),
      ProfileType.file => labeledAnchor(
        top: 'YAML',
        bottom: l.local,
        graphic: const ProfileTypeBadgeCircle(type: ProfileType.file, size: 28),
      ),
      ProfileType.custom => labeledAnchor(
        top: customCount != null ? l.groupCount(customCount) : l.custom,
        bottom: l.custom,
        tooltip: customCount != null
            ? l.proxyGroupsCount(customCount, customCount.compact)
            : null,
        graphic: const ProfileTypeBadgeCircle(
          type: ProfileType.custom,
          size: 28,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdating = ref.watch(isUpdatingProvider(profile.updatingKey));
    final customCount = profile.type == ProfileType.custom
        ? ref.watch(profileGroupsCountProvider(profile.id)).value
        : null;
    final isSelected = profile.id == groupValue;
    final expired = profileIsExpired(profile);
    final colorScheme = context.colorScheme;
    final menuItems = buildProfileMenuItems(context, ref, profile);

    return ContextMenuRegion(
      menuItems: isUpdating ? null : menuItems,
      child: Card(
        enterActionsOnRight: true,
        radius: AppCorner.xl,
        isSelected: isSelected,
        onPressed: () {
          onChanged(profile.id);
        },
        child: Padding(
          key: Key(profile.id.toString()),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: _cardVerticalPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileIconBadge(profile: profile, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmojiText(
                      profile.realLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline.of(context),
                    ),
                    const SizedBox(height: _infoGap),
                    Text(
                      profileSubtitleText(context, profile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: expired
                          ? AppTextStyle.footnote
                                .of(context, emphasized: true)
                                .copyWith(color: colorScheme.error)
                          : AppTextStyle.footnote.of(context).toLighter,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  _buildRightAnchor(
                    context,
                    isUpdating: isUpdating,
                    customCount: customCount,
                  ),
                  if (showSelectionBadge && isSelected)
                    const SelectionBadge(size: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReorderableProfilesSheet extends ConsumerStatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  ConsumerState<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState
    extends ConsumerState<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ReorderDragStartListener(
      key: Key(profile.id.toString()),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: DecorationListItem(
          contentPadding: const EdgeInsets.only(left: 16),
          trailing: SortHandle(index: index),
          title: Text(profile.realLabel),
        ),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    final latest = ref.read(profilesProvider);
    final ids = {for (final profile in profiles) profile.id};
    ref.read(profilesProvider.notifier).reorder([
      for (final profile in profiles) ?latest.getProfile(profile.id),
      for (final profile in latest)
        if (!ids.contains(profile.id)) profile,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        onPressed: _handleSave,
        tooltip: context.appLocalizations.save,
      ),
      body: PrismReorderableListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.contentTopPadding,
          bottom: 32 + context.bottomInset,
        ),
        proxyDecorator: (child, index, animation) {
          return commonProxyDecorator(_buildItem(index), index, animation);
        },
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            profiles = profiles.copyAndReorder(oldIndex, newIndex);
          });
        },
        itemBuilder: (_, index) {
          return _buildItem(index);
        },
        itemCount: profiles.length,
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
