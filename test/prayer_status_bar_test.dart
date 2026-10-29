import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/prayer_status_bar.dart';
import 'package:zaker_ai/features/prayer/prayer_status_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = const MethodChannel(PrayerStatusBar.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    PrayerStatusBar.instance.onOpenRoute = null;
  });

  test('sync sends the city and the boundaries', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return true;
    });

    final ok = await PrayerStatusBar.instance.sync(
      city: 'القاهرة',
      boundaries: [
        PrayerStatusBoundary(
          at: DateTime.fromMillisecondsSinceEpoch(1793350800000),
          name: 'العصر',
          hour: 15,
          minute: 10,
        ),
      ],
    );

    expect(ok, isTrue);
    expect(seen!.method, 'sync');
    final args = seen!.arguments as Map<Object?, Object?>;
    expect(args['enabled'], isTrue);
    expect(args['city'], 'القاهرة');
    expect((args['boundaries'] as List).single, {
      'at': 1793350800000,
      'name': 'العصر',
      'hour': 15,
      'minute': 10,
    });
  });

  test('cancel completes when the platform is missing', () async {
    await expectLater(PrayerStatusBar.instance.cancel(), completes);
  });

  test('a native openRoute reaches onOpenRoute', () async {
    String? route;
    PrayerStatusBar.instance.onOpenRoute = (value) => route = value;
    PrayerStatusBar.instance.attach();
    await messenger.handlePlatformMessage(
      PrayerStatusBar.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openRoute', '/prayer'),
      ),
      (_) {},
    );
    expect(route, '/prayer');
  });

  test('takeLaunchRoute returns the pending route', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'takeLaunchRoute' ? '/prayer' : null,
    );
    expect(await PrayerStatusBar.instance.takeLaunchRoute(), '/prayer');
  });
}
