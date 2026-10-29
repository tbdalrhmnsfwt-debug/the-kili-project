import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/features/prayer/adhan_models.dart';
import 'package:zaker_ai/features/prayer/adhan_providers.dart';

void main() {
  test('the status bar is on by default', () {
    expect(const AdhanSettings().statusBarEnabled, isTrue);
    expect(
      AdhanSettings.fromJson(const <String, dynamic>{}).statusBarEnabled,
      isTrue,
    );
  });

  test('an explicit off survives a JSON round trip', () {
    final json =
        const AdhanSettings().copyWith(statusBarEnabled: false).toJson();
    expect(json['statusBar'], isFalse);
    expect(AdhanSettings.fromJson(json).statusBarEnabled, isFalse);
    expect(
      const AdhanSettings(),
      isNot(const AdhanSettings(statusBarEnabled: false)),
    );
  });

  test('the controller persists the switch', () async {
    final store = LocalStore.memory();
    final controller = AdhanSettingsController(store);
    controller.setStatusBarEnabled(false);
    expect(controller.state.statusBarEnabled, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(AdhanSettingsController(store).state.statusBarEnabled, isFalse);
  });
}
