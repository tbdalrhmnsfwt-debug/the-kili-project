/// Where a timetable photo lives inside the batch's private directory.
///
/// The importer writes the photo and the repository later deletes it, so both
/// must agree on the exact relative path. Nothing here is ever a URL.
library;

class SchedulePaths {
  const SchedulePaths._();

  /// Image formats Tesseract reads on both mobile platforms.
  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const String _directory = 'schedules';

  /// `schedules/<draftId>.<extension>` under the batch directory.
  static String imagePath(String draftId, String extension) =>
      '$_directory/$draftId.${extension.toLowerCase()}';

  /// The stored relative path of a draft's photo, or null when the draft has
  /// none or when the value could escape the schedules directory.
  static String? storedImagePath(String sourceImageFileName) {
    if (!sourceImageFileName.startsWith('$_directory/')) return null;
    if (sourceImageFileName.contains(r'\') ||
        sourceImageFileName.contains('..')) {
      return null;
    }
    return sourceImageFileName;
  }
}
