/// The system picker for batch resources.
///
/// Widget tests override [batchFilePickerProvider] so no platform channel or
/// real file I/O runs inside the fake-async zone.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/batches/resource_store.dart';
import '../../models/batch_resource.dart';

typedef BatchFilePicker = Future<List<PickedResourceFile>> Function(
  ResourceKind kind,
);

final batchFilePickerProvider =
    Provider<BatchFilePicker>((ref) => pickBatchFiles);

/// Opens the picker for [kind] and reports what the user chose.
///
/// A cancelled picker returns an empty list; a picker that cannot open throws
/// so the caller can show one honest message.
Future<List<PickedResourceFile>> pickBatchFiles(ResourceKind kind) async {
  final extensions = kind == ResourceKind.pdf
      ? const ['pdf']
      : const ['m4a', 'aac', 'mp3', 'wav', 'ogg'];
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: kind == ResourceKind.pdf,
    withReadStream: false,
  );
  if (result == null) return const [];
  return [
    for (final file in result.files)
      PickedResourceFile(
        name: file.name,
        path: file.path,
        sizeBytes: file.size,
      ),
  ];
}
