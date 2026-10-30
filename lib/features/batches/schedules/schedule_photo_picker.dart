/// The system picker for a timetable photo.
///
/// Widget tests override [schedulePhotoPickerProvider] so no camera, gallery
/// or platform channel runs inside the fake-async zone.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where the photo comes from.
enum SchedulePhotoSource { camera, gallery }

typedef SchedulePhotoPicker = Future<String?> Function(
  SchedulePhotoSource source,
);

final schedulePhotoPickerProvider = Provider<SchedulePhotoPicker>(
  (ref) => pickSchedulePhoto,
);

/// Opens the camera or gallery and returns the picked file's path.
///
/// A cancelled picker returns null. Failures are left to the caller so it can
/// show one honest message instead of a fake success.
Future<String?> pickSchedulePhoto(SchedulePhotoSource source) async {
  final picker = ImagePicker();
  final shot = await picker.pickImage(
    source: source == SchedulePhotoSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    imageQuality: 90,
    maxWidth: 2600,
  );
  return shot?.path;
}
