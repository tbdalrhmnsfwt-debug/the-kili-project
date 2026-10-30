import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/appearance.dart';
import 'package:zaker_ai/core/theme.dart';

void main() {
  test('a saved layout that has no code behind it falls back to calm', () {
    final settings = AppearanceSettings.fromJson({'layout': 'zakerly_1'});
    expect(settings.homeLayout, ZakerHomeLayout.calm);
  });

  test('the active layout survives a save and reload', () {
    const saved = AppearanceSettings(
      themeStyle: ZakerThemeStyle.dark,
      homeLayout: ZakerHomeLayout.calm,
    );
    final reloaded = AppearanceSettings.fromJson(saved.toJson());
    expect(reloaded.homeLayout, ZakerHomeLayout.calm);
    expect(reloaded.themeStyle, ZakerThemeStyle.dark);
  });

  test('an unknown layout id never becomes selectable', () {
    for (final layout in ZakerHomeLayout.values) {
      if (layout.available) continue;
      expect(ZakerHomeLayout.fromId(layout.id), ZakerHomeLayout.calm);
    }
  });
}
