import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The English table is loaded from assets at runtime; a malformed or empty
/// entry would silently fall back to Arabic, so keep the file honest here.
void main() {
  late Map<String, String> table;

  setUpAll(() {
    final raw = File('assets/i18n/en_extra.json').readAsStringSync();
    table = (jsonDecode(raw) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value.toString()),
    );
  });

  test('the English additions load with a value for every key', () {
    expect(table, isNotEmpty);
    expect(table.values.every((value) => value.trim().isNotEmpty), isTrue);
    expect(table.entries.where((entry) => entry.key == entry.value), isEmpty);
  });

  test('blocked batch states have English copy', () {
    expect(
      table,
      contains('التفريغ السحابي محتاج موافقة صريحة منك ومفتاح مزوّد محفوظ في '
          'سيرفر. مفيش سيرفر ولا مزوّد متظبط، ومفيش صوت بيتبعت بره الجهاز.'),
    );
    expect(
      table,
      contains('الموافقة والرفض بين الأجهزة محتاجين سيرفر، فمفيش أزرار '
          'موافقة وهمية هنا.'),
    );
    expect(
      table,
      contains('التحدي المباشر محتاج سيرفر.'),
    );
  });

  test('the tutorial and admin surfaces have English copy', () {
    expect(table['الجولة الكاملة'], 'Full tour');
    expect(table['البداية السريعة'], 'Quick start');
    expect(table['إدارة الدفعة'], 'Batch administration');
    expect(table['السجل المحلي'], 'Local log');
  });
}
