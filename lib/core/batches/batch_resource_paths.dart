/// Where each kind of resource stores its private files.
///
/// The repository and the importer both need these names, and they must never
/// disagree: deleting a resource has to remove exactly the files that were
/// written for it.
library;

import '../../models/batch_resource.dart';

class BatchResourcePaths {
  const BatchResourcePaths._();

  /// Audio containers the local importer accepts.
  static const Set<String> audioExtensions = {
    'm4a',
    'aac',
    'mp3',
    'wav',
    'ogg'
  };

  static final RegExp _extensionPattern = RegExp(r'^[a-z0-9]{1,8}$');

  /// The lowercase extension of [fileName], or null when it is unusable.
  static String? extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    final extension = fileName.substring(dot + 1).toLowerCase();
    return _extensionPattern.hasMatch(extension) ? extension : null;
  }

  static bool isAudioExtension(String extension) =>
      audioExtensions.contains(extension);

  /// The private copy of a PDF or audio resource; null for a note.
  static String? filePath(BatchResource resource) {
    if (resource.kind == ResourceKind.note) return null;
    final extension = extensionOf(resource.fileName);
    if (extension == null) return null;
    return 'resources/${resource.id}.$extension';
  }

  static String thumbnailPath(String resourceId) => 'thumbs/$resourceId.png';

  /// Extraction cache keyed by the first 16 hex characters of the file hash.
  static String textCachePath(String sha256) {
    final key = sha256.length >= 16 ? sha256.substring(0, 16) : sha256;
    return 'text/$key.json';
  }
}
