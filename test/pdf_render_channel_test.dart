import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/core/pdf/pdf_render_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('zaker/pdf_render');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('open returns the handle, page count and page sizes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'open');
      return {
        'handle': 3,
        'pageCount': 2,
        'pages': [
          {'width': 595.0, 'height': 842.0},
          {'width': 612.0, 'height': 792.0},
        ],
      };
    });

    final handle = await const PdfRenderChannel().open('/docs/a.pdf');

    expect(handle.id, 3);
    expect(handle.pageCount, 2);
    expect(handle.pages.first.widthPoints, 595.0);
    expect(handle.pages.last.heightPoints, 792.0);
  });

  test('a null password is omitted from the open call', () async {
    Map<Object?, Object?>? arguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      arguments = call.arguments as Map<Object?, Object?>?;
      return {'handle': 1, 'pageCount': 1, 'pages': []};
    });

    await const PdfRenderChannel().open('/docs/a.pdf');

    expect(arguments?.containsKey('password'), isFalse);
  });

  test('a password-required platform error becomes a typed failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'passwordRequired');
    });

    await expectLater(
      const PdfRenderChannel().open('/docs/locked.pdf'),
      throwsA(
        isA<PdfRenderException>().having(
          (error) => error.failure,
          'failure',
          PdfRenderFailure.passwordRequired,
        ),
      ),
    );
  });

  test(
    'a password this Android version cannot use is a typed failure',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'passwordUnsupported');
      });

      await expectLater(
        const PdfRenderChannel().open('/docs/locked.pdf', password: 'secret'),
        throwsA(
          isA<PdfRenderException>().having(
            (error) => error.failure,
            'failure',
            PdfRenderFailure.passwordUnsupported,
          ),
        ),
      );
    },
  );

  test('a missing plugin becomes unavailable', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });

    await expectLater(
      const PdfRenderChannel().open('/docs/a.pdf'),
      throwsA(
        isA<PdfRenderException>().having(
          (error) => error.failure,
          'failure',
          PdfRenderFailure.unavailable,
        ),
      ),
    );
  });

  test('render forwards the tile request and returns bytes', () async {
    Map<Object?, Object?>? arguments;
    final png = Uint8List.fromList([1, 2, 3, 4]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      arguments = call.arguments as Map<Object?, Object?>?;
      return png;
    });

    final bytes = await const PdfRenderChannel().render(
      handle: 1,
      pageIndex: 0,
      scale: 2,
      source: const NormalizedRect(0.1, 0.2, 0.5, 0.6),
    );

    expect(bytes, png);
    expect(arguments?['handle'], 1);
    expect(arguments?['page'], 0);
    expect(arguments?['scale'], 2.0);
    expect(arguments?['left'], 0.1);
    expect(arguments?['top'], 0.2);
    expect(arguments?['width'], 0.5);
    expect(arguments?['height'], 0.6);
    expect(arguments?['maxPixels'], 4096);
  });

  test('close swallows platform errors', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'renderFailed');
    });

    await const PdfRenderChannel().close(9);
  });
}
