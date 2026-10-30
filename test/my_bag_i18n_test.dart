import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every static bag string, exactly as it appears in `TrText` / `trf`.
const List<String> _bagStrings = [
  'شنطتي',
  'كل موادك في شنطة واحدة',
  'المكتبة الدراسية',
  'الصف الحالي',
  'كل الصفوف',
  'مجلداتي',
  'أضف مادة',
  'مادة جديدة',
  'اسم المادة',
  'أضف',
  'حذف المجلد',
  'تغيير اللون',
  'خيارات المجلد',
  'حذف «{0}»؟',
  'التسجيلات وصور البورد والروابط هتتحذف. ملفات PDF هتفضل في المكتبة من غير وسم.',
  'احذف',
  'بحث في شنطتي',
  'نتائج البحث',
  'لسه مفيش مواد في الشنطة',
  'المواد بتتضاف أوتوماتيك من الصف اللي مختاره.',
  'المجلد مش موجود',
  'مفيش ملفات',
  'مفيش تسجيلات',
  'مفيش صور',
  'مفيش روابط',
  'آخر ما أضفت',
  '{0} صورة',
  'لسه مفيش حاجة هنا',
  'ملفات PDF',
  'تسجيلات صوتية',
  'صور بورد',
  'روابط',
  'أضف PDF',
  'ضيف ملزمة أو امتحان من ملفاتك.',
  'صفحة {0} من {1}',
  'صفحة {0}',
  'أزل المرجع',
  'أزل من الشنطة',
  'فتح ملفاتي',
  'افتح',
  'شارك',
  'أعد التسمية',
  'سجّل ملاحظة صوتية',
  'سجّل',
  'إيقاف وحفظ',
  'الميكروفون مرفوض. فعّله من الإعدادات علشان تسجل.',
  'المساحة مش كافية للتسجيل. فضّي مساحة وجرّب تاني.',
  'التسجيل فاضي، جرّب تاني.',
  'حد أقصى 100 تسجيل في المجلد.',
  'تسجيل {0}',
  'تشغيل',
  'إيقاف مؤقت',
  'شريط الصوت',
  'أضف صور',
  'كاميرا',
  'المعرض',
  'كوّن PDF',
  'تم تكوين ملف PDF',
  'أقصى 25 صورة في المرة.',
  'حد أقصى 200 صورة في المجلد.',
  'أضف رابط',
  'رابط جديد',
  'تعديل الرابط',
  'ضيف رابط محاضرة أو مراجعة هنا.',
  'خيارات',
  'مقدرناش نفتح الرابط.',
  'الرابط فاضي.',
  'الرابط لازم يبدأ بـ http أو https.',
  'الرابط مش كامل.',
  'الرابط فيه مسافة.',
  'حد أقصى 100 رابط في المجلد.',
  'ملف PDF',
  'تسجيل',
  'صورة بورد',
  'رابط',
  'افتح الإعدادات',
  'جرّب تاني',
  // The bag's PDF pocket renders these from the shared document card.
  'الملف مش موجود في المكتبة.',
  'شيل من المكتبة',
];

void main() {
  late Map<String, dynamic> english;

  setUpAll(() {
    final base = jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>;
    final extra =
        jsonDecode(File('assets/i18n/en_extra.json').readAsStringSync())
            as Map<String, dynamic>;
    english = {...base, ...extra};
  });

  test('every bag string has English copy', () {
    final missing = [
      for (final key in _bagStrings)
        if (!english.containsKey(key)) key,
    ];
    expect(missing, isEmpty, reason: 'Missing English: $missing');
  });

  test('every bag English value is non-empty and differs from the key', () {
    for (final key in _bagStrings) {
      final value = english[key];
      if (value == null) continue;
      expect('$value'.trim(), isNotEmpty, reason: key);
      expect(value, isNot(key), reason: key);
    }
  });
}
