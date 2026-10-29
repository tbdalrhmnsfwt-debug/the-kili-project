/// The persisted appearance choice: one of four palettes and the home layout.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'local_store.dart';
import 'theme.dart';

/// Store key for the appearance choice.
const String kAppearanceStoreKey = 'appearance';

/// Home layouts. Only [calm] exists today; the others are listed so the
/// selector can show them as "قريبًا" instead of inventing a layout.
enum ZakerHomeLayout {
  calm('calm', 'هادي', available: true),
  zakerly1('zakerly_1', 'ذاكرلي ١', available: false),
  zakerly2('zakerly_2', 'ذاكرلي ٢', available: false),
  zakerly3('zakerly_3', 'ذاكرلي ٣', available: false);

  const ZakerHomeLayout(this.id, this.label, {required this.available});

  final String id;
  final String label;
  final bool available;

  /// The layout stored under [id], falling back to [calm] for ids this build
  /// has no layout for — a save from a later version must not put the home
  /// screen in a state it cannot render.
  static ZakerHomeLayout fromId(String? id) {
    for (final layout in values) {
      if (layout.id == id && layout.available) return layout;
    }
    return calm;
  }
}

/// The saved appearance settings.
class AppearanceSettings {
  const AppearanceSettings({
    this.themeStyle = ZakerThemeStyle.light,
    this.homeLayout = ZakerHomeLayout.calm,
  });

  final ZakerThemeStyle themeStyle;
  final ZakerHomeLayout homeLayout;

  AppearanceSettings copyWith({
    ZakerThemeStyle? themeStyle,
    ZakerHomeLayout? homeLayout,
  }) {
    return AppearanceSettings(
      themeStyle: themeStyle ?? this.themeStyle,
      homeLayout: homeLayout ?? this.homeLayout,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': themeStyle.id,
    'layout': homeLayout.id,
  };

  factory AppearanceSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppearanceSettings();
    return AppearanceSettings(
      themeStyle: ZakerThemeStyle.fromId('${json['theme'] ?? ''}'),
      homeLayout: ZakerHomeLayout.fromId('${json['layout'] ?? ''}'),
    );
  }
}

final appearanceProvider =
    StateNotifierProvider<AppearanceController, AppearanceSettings>((ref) {
      return AppearanceController(ref.watch(localStoreProvider));
    });

class AppearanceController extends StateNotifier<AppearanceSettings> {
  AppearanceController(this._store)
    : super(AppearanceSettings.fromJson(_store.getJson(kAppearanceStoreKey)));

  final LocalStore _store;

  void _commit(AppearanceSettings next) {
    state = next;
    _store.setJson(kAppearanceStoreKey, next.toJson());
  }

  void setTheme(ZakerThemeStyle style) {
    if (style == state.themeStyle) return;
    _commit(state.copyWith(themeStyle: style));
  }

  /// Only layouts that exist in code can be selected.
  void setHomeLayout(ZakerHomeLayout layout) {
    if (!layout.available || layout == state.homeLayout) return;
    _commit(state.copyWith(homeLayout: layout));
  }
}
