import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/profiles.dart';
import 'package:fl_clash/views/profiles/boarding_pass.dart';
import 'package:fl_clash/views/profiles/profile_icon.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../helpers/context_menu.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

final _futureExpire =
    DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;

Profile urlProfile(String label, {int? expire}) =>
    Profile.normal(label: label, url: 'https://example.com/sub').copyWith(
      subscriptionInfo: SubscriptionInfo(
        upload: 1024,
        download: 2048,
        total: 4096,
        expire: expire ?? _futureExpire,
      ),
    );

class _RecordingProfilesAction extends ProfilesAction {
  final List<Profile> users;
  final deleted = <int>[];

  _RecordingProfilesAction(this.users);

  @override
  Future<List<Profile>> providerUsers(Profile profile) async => users;

  @override
  Future<void> deleteProfile(int id) async => deleted.add(id);
}

Future<ProviderContainer> pumpProfiles(
  WidgetTester tester, {
  required List<Profile> profiles,
  int? currentProfileId,
  ValueListenable<bool>? isActive,
  bool picker = false,
  bool firstFrameOnly = false,
  Size size = const Size(900, 800),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(() => TestProfiles(profiles)),
      currentProfileIdProvider.overrideWithBuild(
        (_, _) => currentProfileId ?? profiles.first.id,
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).value = size;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: HostApp(
        navigatorKey: globalState.navigatorKey,
        builder: (context, child) {
          return wrapAppScopes(context, child!);
        },
        home: isActive == null
            ? ProfilesView(picker: picker)
            : ValueListenableBuilder(
                valueListenable: isActive,
                builder: (_, isActive, child) =>
                    PageActivityScope(isActive: isActive, child: child!),
                child: ProfilesView(picker: picker),
              ),
      ),
    ),
  );
  if (!firstFrameOnly) {
    await tester.pump();
  }
  return container;
}

void main() {
  testWidgets('focused profile cards in others open their context menu', (
    tester,
  ) async {
    final profiles = [
      urlProfile('url 1'),
      Profile.normal(label: 'file 1'),
      urlProfile('url 2'),
    ];
    await pumpProfiles(tester, profiles: profiles);

    final cards = find
        .byType(Card)
        .evaluate()
        .map((element) => element.widget)
        .toList();
    expect(cards.length, 2);

    Future<void> focusCard(int index) async {
      for (var tab = 0; tab < 60; tab++) {
        final context = FocusManager.instance.primaryFocus?.context;
        final focusedCard = context?.findAncestorWidgetOfExactType<Card>();
        if (identical(focusedCard, cards[index])) {
          return;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      fail('Profile card $index was not reachable');
    }

    for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
      await focusCard(cardIndex);

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(PopupMenu),
          matching: find.text(currentAppLocalizations.delete),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenu), findsNothing);
    }
  });

  testWidgets(
    'portrait boarding pass shows circular morph menu and wavy traffic bar',
    (tester) async {
      final l = currentAppLocalizations;
      final active = urlProfile('Main Sub', expire: 0);
      final local = Profile.normal(label: 'Local YAML');
      await pumpProfiles(
        tester,
        profiles: [active, local],
        size: const Size(430, 840),
      );

      expect(find.byType(ProfileBoardingPass), findsOneWidget);
      expect(find.text('Main Sub'), findsOneWidget);
      expect(find.text(l.infiniteTime), findsOneWidget);
      expect(
        find.text('75% ${l.usedShort}', findRichText: true),
        findsOneWidget,
      );
      final header = find.byType(ListHeader);
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.text(l.otherProfiles)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('1')),
        findsNothing,
      );
      final wavyFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is WavyProgressPainter,
      );
      expect(wavyFinder, findsOneWidget);
      final wavyPainter =
          tester.widget<CustomPaint>(wavyFinder).painter! as WavyProgressPainter;
      expect(
        wavyPainter.track,
        DashboardColors.of(tester.element(wavyFinder)).tone2,
      );
      expect(
        find.byWidgetPredicate((w) => w is GlyphIcon && (w.size ?? 0) >= 80),
        findsNothing,
      );
      expect(find.text(l.lastEdited), findsOneWidget);
      expect(find.byTooltip(l.more), findsOneWidget);
      expect(find.text(l.copyLink), findsNothing);

      await tester.tap(find.byTooltip(l.more));
      await tester.pumpAndSettle();
      final menu = find.byType(PopupMenu);
      expect(find.descendant(of: menu, matching: find.text(l.customIcon)), findsOneWidget);
      expect(find.descendant(of: menu, matching: find.text(l.extend)), findsOneWidget);
      expect(find.descendant(of: menu, matching: find.text(l.delete)), findsOneWidget);
    },
  );

  testWidgets(
    'landscape remote boarding pass fits all actions in two rows',
    (tester) async {
      final l = currentAppLocalizations;
      final active = urlProfile('Wide Sub');
      final other = urlProfile('Other Sub', expire: 0);
      await pumpProfiles(
        tester,
        profiles: [active, other],
        size: const Size(720, 430),
      );

      final pass = find.byType(ProfileBoardingPass);
      expect(pass, findsOneWidget);
      final cloudIcons = find.descendant(
        of: pass,
        matching: find.byWidgetPredicate(
          (w) => w is GlyphIcon && w.glyph == AppGlyphs.cloud,
        ),
      );
      expect(cloudIcons, findsOneWidget);
      expect(tester.widget<GlyphIcon>(cloudIcons).size, lessThan(80));
      expect(
        find.descendant(
          of: pass,
          matching: find.byWidgetPredicate(
            (w) => w is GlyphIcon && (w.size ?? 0) >= 80,
          ),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: pass, matching: find.byTooltip(l.more)),
        findsNothing,
      );
      double labelY(String label) {
        final text = find.descendant(of: pass, matching: find.text(label));
        expect(text, findsOneWidget);
        return tester.getCenter(text).dy;
      }

      final pillY = labelY(l.sync);
      expect(labelY(l.edit), pillY);
      expect(labelY(l.extend), pillY);
      final circleY = labelY(l.icon);
      expect(circleY, greaterThan(pillY));
      for (final label in [
        l.preview,
        l.copyLink,
        l.qrcode,
        l.exportFile,
        l.delete,
      ]) {
        expect(labelY(label), circleY);
      }

      // Landscape renders two equal-width independent cards and aligns top 3
      // primary seams with bottom 6 secondary seams (0px drift).
      Rect tileRect(String label) => tester.getRect(
        find.ancestor(
          of: find.descendant(of: pass, matching: find.text(label)),
          matching: find.byType(PressSurface),
        ),
      );
      expect(tileRect(l.sync).right, moreOrLessEquals(tileRect(l.preview).right, epsilon: 0.5));
      expect(tileRect(l.edit).left, moreOrLessEquals(tileRect(l.copyLink).left, epsilon: 0.5));
      expect(tileRect(l.edit).right, moreOrLessEquals(tileRect(l.qrcode).right, epsilon: 0.5));
      expect(tileRect(l.extend).left, moreOrLessEquals(tileRect(l.exportFile).left, epsilon: 0.5));
      expect(tester.takeException(), isNull);

      // Non-active long-term remote profile still shows traffic progress ring.
      final ring = find.descendant(
        of: find.byType(ProfileTrafficRing),
        matching: find.byType(CustomPaint),
      );
      expect(ring, findsOneWidget);
      expect(
        ring,
        paints..circle(color: DashboardColors.of(tester.element(ring)).tone2),
      );
    },
  );

  for (final (name, profile) in [
    ('local YAML', Profile.normal(label: 'Local YAML')),
    ('custom', Profile.custom(label: 'Custom profile')),
  ]) {
    testWidgets('landscape $name boarding pass omits the watermark', (
      tester,
    ) async {
      await pumpProfiles(
        tester,
        profiles: [profile],
        size: const Size(720, 430),
        overrides: [
          profileGroupsCountProvider.overrideWith((_, _) => Stream.value(6)),
        ],
      );

      final pass = find.byType(ProfileBoardingPass);
      expect(pass, findsOneWidget);
      expect(
        find.descendant(of: pass, matching: find.byType(ProfileIconBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pass,
          matching: find.byWidgetPredicate(
            (widget) => widget is GlyphIcon && (widget.size ?? 0) >= 80,
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'landscape custom boarding pass pairs edit and rename above three tiles and derives accents from theme',
    (tester) async {
      final l = currentAppLocalizations;
      final custom = Profile.custom(label: 'Custom profile');
      await pumpProfiles(
        tester,
        profiles: [custom],
        size: const Size(820, 430),
        overrides: [
          profileGroupsCountProvider.overrideWith((_, _) => Stream.value(6)),
        ],
      );

      final pass = find.byType(ProfileBoardingPass);
      double labelY(String label) {
        final text = find.descendant(of: pass, matching: find.text(label));
        expect(text, findsOneWidget);
        return tester.getCenter(text).dy;
      }

      final topY = labelY(l.edit);
      expect(labelY(l.rename), topY);
      final bottomY = labelY(l.icon);
      expect(bottomY, greaterThan(topY));
      expect(labelY(l.preview), bottomY);
      expect(labelY(l.delete), bottomY);

      Rect tileRect(String label) => tester.getRect(
        find.ancestor(
          of: find.descendant(of: pass, matching: find.text(label)),
          matching: find.byType(PressSurface),
        ),
      );
      // Custom top row uses 2:1 span so edit aligns with preview's right edge
      // and rename aligns with delete.
      expect(tileRect(l.edit).right, moreOrLessEquals(tileRect(l.preview).right, epsilon: 0.5));
      expect(tileRect(l.rename).left, moreOrLessEquals(tileRect(l.delete).left, epsilon: 0.5));
      expect(tileRect(l.rename).right, moreOrLessEquals(tileRect(l.delete).right, epsilon: 0.5));

      final ctx = tester.element(pass);
      expect(
        profileTypeAccent(ctx, ProfileType.url),
        ctx.colorScheme.primary,
      );
      expect(
        profileTypeAccent(ctx, ProfileType.file),
        DashboardColors.of(ctx).complement,
      );
      expect(
        profileTypeAccent(ctx, ProfileType.custom),
        ctx.colorScheme.tertiary,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'other cards show distinct anchors for remote, local YAML, custom, and updating',
    (tester) async {
      final l = currentAppLocalizations;
      final active = Profile.normal(label: 'Active File');
      final remote = urlProfile('Remote Sub', expire: 0).copyWith(
        lastUpdateDate: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final expired = urlProfile('Expired Sub', expire: 1234567890);
      final local = Profile.normal(label: 'Work File');
      final custom = Profile.custom(label: 'My Custom');

      final container = await pumpProfiles(
        tester,
        profiles: [active, remote, expired, local, custom],
        currentProfileId: active.id,
        overrides: [
          profileGroupsCountProvider.overrideWith((_, _) => Stream.value(6)),
        ],
      );
      await tester.pump();

      Finder inCard(String label, Finder matching) => find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(ProfileItem),
        ),
        matching: matching,
      );

      expect(inCard('Remote Sub', find.byType(ProfileTrafficRing)), findsOneWidget);
      expect(inCard('Remote Sub', find.text(l.remainingShort)), findsOneWidget);
      expect(inCard('Expired Sub', find.text(l.expired)), findsAtLeastNWidgets(1));
      expect(inCard('Work File', find.text('YAML')), findsOneWidget);
      expect(inCard('Work File', find.text(l.local)), findsOneWidget);
      expect(
        inCard('Work File', find.byType(ProfileTypeBadgeCircle)),
        findsOneWidget,
      );
      expect(
        inCard('My Custom', find.text(l.groupCount(6))),
        findsOneWidget,
      );
      expect(
        inCard(
          'My Custom',
          find.byTooltip(l.proxyGroupsCount(6, '6')),
        ),
        findsOneWidget,
      );

      container.read(updatingKeysProvider.notifier).start(remote.updatingKey);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(inCard('Remote Sub', find.byType(ActivityIndicator)), findsOneWidget);
    },
  );

  testWidgets('profile icons support 3 distinct defaults and custom icon overrides', (
    tester,
  ) async {
    const sampleDataIcon =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
    final active = urlProfile('Remote');
    final local = Profile.normal(label: 'Local');
    final custom = Profile.custom(label: 'Custom');
    final container = await pumpProfiles(
      tester,
      profiles: [active, local, custom],
    );

    expect(profileDefaultGlyph(active.type), AppGlyphs.cloud);
    expect(AppGlyphs.cloud.shapes.length, 1);
    expect(profileDefaultGlyph(active.type), isNot(profileDefaultGlyph(local.type)));
    expect(profileDefaultGlyph(local.type), isNot(profileDefaultGlyph(custom.type)));
    expect(profileDefaultGlyph(active.type), isNot(profileDefaultGlyph(custom.type)));

    expect(container.read(profileIconProvider(active.id)), isEmpty);
    container
        .read(profileIconsProvider.notifier)
        .setIcon(active.id, sampleDataIcon);
    await tester.pump();
    expect(
      container.read(profileIconProvider(active.id)),
      sampleDataIcon,
    );
    expect(find.byType(CommonTargetIcon), findsOneWidget);

    container.read(profileIconsProvider.notifier).setIcon(active.id, '');
    await tester.pump();
    expect(container.read(profileIconProvider(active.id)), isEmpty);
    expect(find.byType(CommonTargetIcon), findsNothing);
  });

  Future<void> openProfileMenu(WidgetTester tester, String label) async {
    await rightClick(tester, find.text(label));
    await tester.pumpAndSettle();
  }

  Finder inMenu(Finder matching) =>
      find.descendant(of: find.byType(PopupMenu), matching: matching);

  testWidgets('an external profile lists extend, custom icon, and keeps its final config under more', (
    tester,
  ) async {
    final l = currentAppLocalizations;
    final active = Profile.normal(label: 'active');
    final url = urlProfile('url');
    await pumpProfiles(tester, profiles: [active, url]);

    await openProfileMenu(tester, 'url');
    expect(inMenu(find.text(l.extend)), findsOneWidget);
    expect(inMenu(find.text(l.customIcon)), findsOneWidget);
    expect(inMenu(find.text(l.runtimeConfig)), findsNothing);
    expect(inMenu(find.text(l.rename)), findsNothing);

    await tester.tap(inMenu(find.text(l.more)).last);
    await tester.pumpAndSettle();
    expect(inMenu(find.text(l.runtimeConfig)), findsOneWidget);
  });

  testWidgets('a custom profile lists its final config, custom icon, and no extend', (
    tester,
  ) async {
    final l = currentAppLocalizations;
    final active = Profile.normal(label: 'active');
    final mine = Profile.custom(label: 'mine');
    await pumpProfiles(tester, profiles: [active, mine]);

    await openProfileMenu(tester, 'mine');
    expect(inMenu(find.text(l.runtimeConfig)), findsOneWidget);
    expect(inMenu(find.text(l.customIcon)), findsOneWidget);
    expect(inMenu(find.text(l.extend)), findsNothing);
    expect(inMenu(find.text(l.more)), findsNothing);
  });

  testWidgets('a custom profile renames from its menu', (tester) async {
    final l = currentAppLocalizations;
    final active = Profile.normal(label: 'active');
    final mine = Profile.custom(label: 'mine');
    await pumpProfiles(tester, profiles: [active, mine]);

    await openProfileMenu(tester, 'mine');
    await tester.tap(inMenu(find.text(l.rename)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ours');
    await tester.tap(find.text(l.submit));
    await tester.pumpAndSettle();

    expect(find.text('ours'), findsOneWidget);
    expect(find.text('mine'), findsNothing);
  });

  testWidgets('a profile another one uses as a provider is deleted once confirmed', (
    tester,
  ) async {
    final action = _RecordingProfilesAction([Profile.normal(label: 'Work')]);
    final active = Profile.normal(label: 'Active');
    final home = urlProfile('Home');
    await pumpProfiles(
      tester,
      profiles: [active, home],
      overrides: [profilesActionProvider.overrideWith(() => action)],
    );

    await openProfileMenu(tester, 'Home');
    await tester.tap(inMenu(find.text(currentAppLocalizations.delete)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Home is still used'), findsOneWidget);
    expect(find.textContaining('used by Work'), findsOneWidget);
    await tester.tap(find.text(currentAppLocalizations.delete).last);
    await tester.pumpAndSettle();

    expect(action.deleted, [home.id]);
  });

  testWidgets('the selected profile is always visible at top in normal mode, while picker opens flat at top with empty bar', (
    tester,
  ) async {
    final profiles = [
      for (var index = 0; index < 30; index++) urlProfile('profile $index'),
    ];
    final selected = profiles[25];

    await pumpProfiles(
      tester,
      profiles: profiles,
      currentProfileId: selected.id,
      firstFrameOnly: true,
    );
    expect(find.byType(ProfileBoardingPass), findsOneWidget);
    expect(find.text(selected.label), findsOneWidget);

    await pumpProfiles(
      tester,
      profiles: profiles,
      currentProfileId: selected.id,
      picker: true,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileBoardingPass), findsNothing);
    expect(find.text(profiles.first.label), findsOneWidget);
    expect(find.byType(AppBarActionButton), findsNothing);
  });

  testWidgets(
    'switching profiles in landscape runs spatial FLIP animation repeatedly with unified hero height',
    (tester) async {
      final first = urlProfile('Main Sub');
      final second = Profile.normal(label: 'Local YAML');
      final third = Profile.custom(label: 'Custom Rules');
      final fourth = urlProfile('Backup Sub');
      await pumpProfiles(
        tester,
        profiles: [first, second, third, fourth],
        currentProfileId: first.id,
        size: const Size(900, 800),
        overrides: [
          profileGroupsCountProvider.overrideWith((_, _) => Stream.value(5)),
        ],
      );

      final urlHeroHeight = tester.getSize(find.byType(ProfileBoardingPass)).height;

      // Swap 1: Remote URL -> Custom.
      await tester.tap(find.text('Custom Rules'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProfileBoardingPass).evaluate().length,
        greaterThan(1),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileBoardingPass), findsOneWidget);
      final customHeroHeight =
          tester.getSize(find.byType(ProfileBoardingPass)).height;
      expect(customHeroHeight, moreOrLessEquals(urlHeroHeight, epsilon: 0.5));
      expect(
        find.descendant(
          of: find.byType(ProfileBoardingPass),
          matching: find.text('Custom Rules'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileItem),
          matching: find.text('Main Sub'),
        ),
        findsOneWidget,
      );

      // Swap 2: Custom -> Local YAML (must animate again, not just first swap).
      await tester.tap(find.text('Local YAML'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProfileBoardingPass).evaluate().length,
        greaterThan(1),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileBoardingPass), findsOneWidget);
      final yamlHeroHeight =
          tester.getSize(find.byType(ProfileBoardingPass)).height;
      expect(yamlHeroHeight, moreOrLessEquals(urlHeroHeight, epsilon: 0.5));

      // Swap 3: Local YAML -> Remote URL.
      await tester.tap(find.text('Main Sub'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProfileBoardingPass).evaluate().length,
        greaterThan(1),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileBoardingPass), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileBoardingPass),
          matching: find.text('Main Sub'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'switching profiles in portrait runs spatial FLIP animation repeatedly with unified hero height',
    (tester) async {
      final first = urlProfile('Main Sub');
      final second = Profile.normal(label: 'Local YAML');
      final third = Profile.custom(label: 'Custom Rules');
      await pumpProfiles(
        tester,
        profiles: [first, second, third],
        currentProfileId: first.id,
        size: const Size(430, 840),
        overrides: [
          profileGroupsCountProvider.overrideWith((_, _) => Stream.value(5)),
        ],
      );

      final urlHeroHeight = tester.getSize(find.byType(ProfileBoardingPass)).height;

      // Swap 1: Remote URL -> Local YAML.
      await tester.tap(find.text('Local YAML'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProfileBoardingPass).evaluate().length,
        greaterThan(1),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileBoardingPass), findsOneWidget);
      final yamlHeroHeight =
          tester.getSize(find.byType(ProfileBoardingPass)).height;
      expect(yamlHeroHeight, moreOrLessEquals(urlHeroHeight, epsilon: 0.5));
      expect(
        find.descendant(
          of: find.byType(ProfileBoardingPass),
          matching: find.text('Local YAML'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileItem),
          matching: find.text('Main Sub'),
        ),
        findsOneWidget,
      );

      // Swap 2: Local YAML -> Custom Rules (must animate again).
      await tester.tap(find.text('Custom Rules'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProfileBoardingPass).evaluate().length,
        greaterThan(1),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileBoardingPass), findsOneWidget);
      final customHeroHeight =
          tester.getSize(find.byType(ProfileBoardingPass)).height;
      expect(customHeroHeight, moreOrLessEquals(urlHeroHeight, epsilon: 0.5));
      expect(
        find.descendant(
          of: find.byType(ProfileBoardingPass),
          matching: find.text('Custom Rules'),
        ),
        findsOneWidget,
      );
    },
  );
}
