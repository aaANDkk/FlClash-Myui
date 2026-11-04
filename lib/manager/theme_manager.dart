import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/state.dart';

/// A rebuilt ThemeData never equals the last, and ThemeCrossFade fades on that.
final _appThemes = <Brightness, ({Object inputs, ThemeData theme})>{};

ThemeData watchAppTheme(WidgetRef ref, Brightness brightness) {
  final locale = ref.watch(appSettingProvider.select((state) => state.locale));
  final themeSetting = ref.watch(
    themeSettingProvider.select(
      (state) => (fontFamily: state.fontFamily, pureBlack: state.pureBlack),
    ),
  );
  final colorScheme = ref.watch(genColorSchemeProvider(brightness));
  final plainDark = brightness == Brightness.dark && themeSetting.pureBlack
      ? ref.watch(genColorSchemeProvider(brightness, pureBlack: false))
      : null;
  final locales = [
    ?getLocaleForString(locale),
    ...WidgetsBinding.instance.platformDispatcher.locales,
  ];
  final customFont = FontManager.customFontFamily;
  final configuredFont = themeSetting.fontFamily;
  // A family an older build wrote for a custom font is dead once that font is
  // registered under a fresh name: an unknown family makes every style fall
  // through to its fallback list, which is where wide spaces and missing digits
  // came from.
  final systemFont = configuredFont == null ||
          configuredFont.isEmpty ||
          configuredFont.startsWith('CustomUserFont_')
      ? null
      : configuredFont;
  final effectiveFontFamily = (customFont != null && customFont.isNotEmpty)
      ? customFont
      : systemFont;
  final currentEmojiStyle = EmojiManager.currentStyle;

  final inputs = (
    platform: defaultTargetPlatform,
    themeSetting: themeSetting,
    customFont: customFont,
    emojiStyle: currentEmojiStyle.name,
    colorScheme: colorScheme,
    plainDark: plainDark,
    locales: locales.join(','),
  );
  if (_appThemes[brightness] case (
    inputs: final cached,
    :final theme,
  ) when cached == inputs) {
    return theme;
  }
  final theme = ThemeData(
    colorScheme: colorScheme,
    fontFamily: effectiveFontFamily,
    fontFamilyFallback: appFontFamilyFallback(
      platform: defaultTargetPlatform,
      locales: locales,
      fontFamily: effectiveFontFamily,
      emojiFamily: currentEmojiStyle.family,
    ),
    elevatedColorScheme: brightness == Brightness.dark
        ? (plainDark ?? colorScheme.elevated)
        : null,
  );
  _appThemes[brightness] = (inputs: inputs, theme: theme);
  return theme;
}

class ThemeManager extends ConsumerWidget {
  final Widget child;

  const ThemeManager({super.key, required this.child});

  Widget _buildSystemUi(Widget child) {
    if (!system.isAndroid) {
      return child;
    }
    return Consumer(
      builder: (context, ref, _) {
        final brightness = ref.watch(currentBrightnessProvider);
        final iconBrightness = brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarIconBrightness: iconBrightness,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            // Pages scroll under the navigation bar. Keep contrast enforcement
            // disabled so Android does not draw a translucent scrim in landscape.
            systemNavigationBarContrastEnforced: false,
          ),
          sized: false,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    globalState.measure = MeasureScope.of(context);
    return AppViewScope(
      child: _AppMediaQuery(
        // Every rebuild outside a nearer LayoutBuilder, a route transition's
        // on each of its frames, relays this one out; the boundaries keep
        // that from repainting the app from the root.
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (_, constraints) {
              ref
                  .read(themeActionProvider.notifier)
                  .updateViewSize(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
              return RepaintBoundary(child: _buildSystemUi(child));
            },
          ),
        ),
      ),
    );
  }
}

class AppViewScope extends ConsumerWidget {
  const AppViewScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ref.watch(isMobileViewProvider);
    return ViewScope(
      size: ref.watch(viewSizeProvider),
      isMobile: isMobile,
      windowControls: windowControlsOverPage(
        isMacOS: system.isMacOS,
        version: ref.watch(versionProvider),
        isMobileView: isMobile,
      ),
      child: child,
    );
  }
}

class _AppMediaQuery extends StatelessWidget {
  const _AppMediaQuery({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final padding = data.padding;
    return MediaQuery(
      data: data.copyWith(
        padding: padding.copyWith(
          top: padding.top > data.size.height * 0.3 ? 20.0 : padding.top,
        ),
      ),
      child: child,
    );
  }
}
