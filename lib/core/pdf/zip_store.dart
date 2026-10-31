/// A tiny, dependency-free ZIP writer and reader.
///
/// PDF Studio's project packages are ordinary ZIP files with stored (not
/// deflated) entries: `manifest.json`, `source.pdf` and the original media.
/// Using the store method keeps the implementation small and makes the
/// package readable by every unzip tool, while media and PDFs are already
/// compressed so deflating them again would buy little.
///
/// Only what this app writes is supported on read: no encryption, no ZIP64,
/// no data descriptors and no deflate. A foreign archive fails with a clear
/// [FormatException] instead of quietly producing damaged annotations.
library;

import 'dart:convert';
import 'dart:typed_data';

/// One file going into a package.
class ZipArchiveEntry {
  const ZipArchiveEntry(this.name, this.bytes);

  /// A forward-slash path inside the archive, never absolute and never `..`.
  final String name;
  final List<int> bytes;
}

/// Builds a ZIP archive with [entries] in order.
Uint8List buildStoredZip(
  List<ZipArchiveEntry> entries, {
  DateTime? modified,
}) {
  final when = modified ?? DateTime.now();
  final locals = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  var offset = 0;

  for (final entry in entries) {
    final name = _checkedName(entry.name);
    final nameBytes = utf8.encode(name);
    final data = entry.bytes is Uint8List
        ? entry.bytes as Uint8List
        : Uint8List.fromList(entry.bytes);
    final crc = crc32(data);
    final time = _dosTime(when);
    final date = _dosDate(when);

    final local = ByteData(30);
    local.setUint32(0, 0x04034b50, Endian.little);
    local.setUint16(4, 20, Endian.little); // version needed
    local.setUint16(6, 0x0800, Endian.little); // UTF-8 names
    local.setUint16(8, 0, Endian.little); // stored
    local.setUint16(10, time, Endian.little);
    local.setUint16(12, date, Endian.little);
    local.setUint32(14, crc, Endian.little);
    local.setUint32(18, data.length, Endian.little);
    local.setUint32(22, data.length, Endian.little);
    local.setUint16(26, nameBytes.length, Endian.little);
    local.setUint16(28, 0, Endian.little);
    locals.add(local.buffer.asUint8List());
    locals.add(nameBytes);
    locals.add(data);

    final directory = ByteData(46);
    directory.setUint32(0, 0x02014b50, Endian.little);
    directory.setUint16(4, 20, Endian.little); // version made by
    directory.setUint16(6, 20, Endian.little); // version needed
    directory.setUint16(8, 0x0800, Endian.little);
    directory.setUint16(10, 0, Endian.little);
    directory.setUint16(12, time, Endian.little);
    directory.setUint16(14, date, Endian.little);
    directory.setUint32(16, crc, Endian.little);
    directory.setUint32(20, data.length, Endian.little);
    directory.setUint32(24, data.length, Endian.little);
    directory.setUint16(28, nameBytes.length, Endian.little);
    directory.setUint16(30, 0, Endian.little);
    directory.setUint16(32, 0, Endian.little);
    directory.setUint16(34, 0, Endian.little);
    directory.setUint16(36, 0, Endian.little);
    directory.setUint32(38, 0, Endian.little);
    directory.setUint32(42, offset, Endian.little);
    central.add(directory.buffer.asUint8List());
    central.add(nameBytes);

    offset += 30 + nameBytes.length + data.length;
  }

  final centralBytes = central.takeBytes();
  final end = ByteData(22);
  end.setUint32(0, 0x06054b50, Endian.little);
  end.setUint16(4, 0, Endian.little);
  end.setUint16(6, 0, Endian.little);
  final count = entries.length.clamp(0, 0xffff);
  end.setUint16(8, count, Endian.little);
  end.setUint16(10, count, Endian.little);
  end.setUint32(12, centralBytes.length, Endian.little);
  end.setUint32(16, offset, Endian.little);
  end.setUint16(20, 0, Endian.little);

  final output = BytesBuilder(copy: false)
    ..add(locals.takeBytes())
    ..add(centralBytes)
    ..add(end.buffer.asUint8List());
  return output.takeBytes();
}

/// Reads a ZIP written by [buildStoredZip].
Map<String, Uint8List> readStoredZip(Uint8List bytes) {
  final end = _endRecord(bytes);
  final count = end.count;
  var cursor = end.centralOffset;
  final result = <String, Uint8List>{};

  for (var i = 0; i < count; i++) {
    _need(bytes, cursor, 46);
    final header = ByteData.sublistView(bytes, cursor, cursor + 46);
    if (header.getUint32(0, Endian.little) != 0x02014b50) {
      throw const FormatException('invalid zip central directory');
    }
    final flags = header.getUint16(8, Endian.little);
    final method = header.getUint16(10, Endian.little);
    final crc = header.getUint32(16, Endian.little);
    final compressed = header.getUint32(20, Endian.little);
    final uncompressed = header.getUint32(24, Endian.little);
    final nameLength = header.getUint16(28, Endian.little);
    final extraLength = header.getUint16(30, Endian.little);
    final commentLength = header.getUint16(32, Endian.little);
    final localOffset = header.getUint32(42, Endian.little);
    if (flags & 1 != 0) {
      throw const FormatException('encrypted zip entries are not supported');
    }
    if (method != 0) {
      throw const FormatException('compressed zip entries are not supported');
    }
    if (compressed == 0xFFFFFFFF || uncompressed == 0xFFFFFFFF) {
      throw const FormatException('zip64 archives are not supported');
    }
    _need(bytes, cursor + 46, nameLength);
    final name = _checkedName(
      utf8.decode(
        bytes.sublist(cursor + 46, cursor + 46 + nameLength),
        allowMalformed: true,
      ),
    );
    cursor += 46 + nameLength + extraLength + commentLength;

    _need(bytes, localOffset, 30);
    final local = ByteData.sublistView(bytes, localOffset, localOffset + 30);
    if (local.getUint32(0, Endian.little) != 0x04034b50) {
      throw const FormatException('invalid zip local header');
    }
    final localNameLength = local.getUint16(26, Endian.little);
    final localExtraLength = local.getUint16(28, Endian.little);
    final dataStart = localOffset + 30 + localNameLength + localExtraLength;
    _need(bytes, dataStart, compressed);
    final data = Uint8List.fromList(
      bytes.sublist(dataStart, dataStart + compressed),
    );
    if (crc32(data) != crc) {
      throw FormatException('zip entry "$name" is damaged');
    }
    result[name] = data;
  }
  return result;
}

class _EndRecord {
  const _EndRecord({
    required this.count,
    required this.centralOffset,
    required this.centralSize,
  });

  final int count;
  final int centralOffset;
  final int centralSize;
}

_EndRecord _endRecord(Uint8List bytes) {
  if (bytes.length < 22) throw const FormatException('not a zip archive');
  final stop = bytes.length - 22;
  final start = stop - 0xffff < 0 ? 0 : stop - 0xffff;
  for (var cursor = stop; cursor >= start; cursor--) {
    if (bytes[cursor] != 0x50 ||
        bytes[cursor + 1] != 0x4b ||
        bytes[cursor + 2] != 0x05 ||
        bytes[cursor + 3] != 0x06) {
      continue;
    }
    final end = ByteData.sublistView(bytes, cursor, cursor + 22);
    final count = end.getUint16(10, Endian.little);
    final size = end.getUint32(12, Endian.little);
    final offset = end.getUint32(16, Endian.little);
    if (offset + size > bytes.length) continue;
    return _EndRecord(count: count, centralOffset: offset, centralSize: size);
  }
  throw const FormatException('zip end record is missing');
}

String _checkedName(String raw) {
  final name = raw.replaceAll('\\', '/');
  if (name.isEmpty ||
      name.startsWith('/') ||
      name.contains('\u0000') ||
      name.split('/').any((part) => part == '..' || part.isEmpty)) {
    throw FormatException('unsafe zip entry name: "$raw"');
  }
  return name;
}

void _need(Uint8List bytes, int start, int length) {
  if (start < 0 || length < 0 || start + length > bytes.length) {
    throw const FormatException('zip archive is truncated');
  }
}

int _dosTime(DateTime value) {
  final local = value.toLocal();
  return (local.hour << 11) | (local.minute << 5) | (local.second ~/ 2);
}

int _dosDate(DateTime value) {
  final local = value.toLocal();
  final year = local.year.clamp(1980, 2107);
  return ((year - 1980) << 9) | (local.month << 5) | local.day;
}

/// CRC-32 (IEEE 802.3), the checksum stored in a ZIP central directory.
int crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

final List<int> _crcTable = List<int>.generate(256, (index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = (value & 1) != 0 ? 0xedb88320 ^ (value >> 1) : value >> 1;
  }
  return value;
}, growable: false);
