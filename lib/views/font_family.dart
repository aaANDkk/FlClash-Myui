import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/manager/font_manager.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

class FontFamilyView extends StatefulWidget {
  const FontFamilyView({super.key});

  @override
  State<FontFamilyView> createState() => _FontFamilyViewState();
}

class _FontFamilyViewState extends State<FontFamilyView> {
  Future<void> _handlePickFont() async {
    final imported = await FontManager.importAndSelect(context);
    if (!mounted || !imported) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleDeleteFont(CustomFont font) async {
    final appLocalizations = context.appLocalizations;
    final result = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.deleteTip(font.name)),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (result != true || !mounted) {
      return;
    }
    await FontManager.delete(font);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// What the app paints with when no custom font is picked. The theme carries
  /// the selected custom family, so a bare `Text` here would preview that font
  /// under the "default" entry instead of the real default.
  TextStyle _defaultStyle() {
    final platform = defaultTargetPlatform;
    final base = Typography.material2021(platform: platform).black.bodyMedium!;
    return TextStyle(
      fontFamily: base.fontFamily,
      fontFamilyFallback: appFontFamilyFallback(
        platform: platform,
        locales: WidgetsBinding.instance.platformDispatcher.locales,
        fontFamily: base.fontFamily,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final fonts = FontManager.fonts;
    return SelectionSheet<CustomFont?>(
      title: appLocalizations.fontFamily,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.addCircle,
          tooltip: appLocalizations.add,
          onPressed: _handlePickFont,
        ),
      ],
      sections: [
        const SelectionSection<CustomFont?>(items: [null]),
        if (fonts.isNotEmpty)
          SelectionSection<CustomFont?>(
            label: appLocalizations.customFont,
            items: fonts,
          ),
      ],
      labelBuilder: (font) => font?.name ?? appLocalizations.defaultText,
      titleBuilder: (font, title) {
        if (font == null) {
          return Text(
            appLocalizations.defaultText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _defaultStyle(),
          );
        }
        final family = FontManager.familyOf(font);
        if (family == null) {
          return title;
        }
        return Text(
          font.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: family),
        );
      },
      selectedOf: (_) => FontManager.selectedFont,
      onLongPressed: (font) async {
        if (font == null) {
          return;
        }
        await _handleDeleteFont(font);
      },
      onSelected: (font) async {
        if (font == null) {
          await FontManager.selectDefault();
        } else {
          await FontManager.select(font);
        }
        if (!mounted) {
          return;
        }
        setState(() {});
      },
    );
  }
}
