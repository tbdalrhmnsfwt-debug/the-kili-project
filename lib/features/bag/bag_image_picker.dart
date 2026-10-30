/// The camera/gallery seam the boards pocket picks images through.
///
/// The interface holds no platform calls, so tests use a fake picker and no
/// picker plugin ever runs inside a widget test.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum BagImageSource { camera, gallery }

class BagPickedImage {
  const BagPickedImage({
    required this.path,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final String path;
  final Uint8List bytes;
  final int width;
  final int height;
}

abstract interface class BagImagePicker {
  Future<List<BagPickedImage>> pick({required BagImageSource source});
}

class SystemBagImagePicker implements BagImagePicker {
  const SystemBagImagePicker();

  @override
  Future<List<BagPickedImage>> pick({required BagImageSource source}) async {
    final picker = ImagePicker();
    final files = switch (source) {
      BagImageSource.camera => [
          if (await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 2200,
            maxHeight: 2200,
            imageQuality: 88,
          )
              case final file?)
            file,
        ],
      BagImageSource.gallery => await picker.pickMultiImage(
          maxWidth: 2200,
          maxHeight: 2200,
          imageQuality: 88,
        ),
    };
    final picked = <BagPickedImage>[];
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      picked.add(
        BagPickedImage(
          path: file.path,
          bytes: bytes,
          width: frame.image.width,
          height: frame.image.height,
        ),
      );
      frame.image.dispose();
      codec.dispose();
    }
    return picked;
  }
}

final bagImagePickerProvider = Provider<BagImagePicker>(
  (ref) => const SystemBagImagePicker(),
);
