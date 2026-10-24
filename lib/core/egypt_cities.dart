/// Egyptian governorates and their major cities, with coordinates.
///
/// The prayer feature uses this list when the user cannot — or prefers not to
/// — share the device location.  It is deliberately offline data: the app
/// must be able to fall back to a city without a network round trip.
///
/// The list contains all 27 governorates, each capital, and the larger cities
/// students are likely to pick.  Coordinates are city-centre approximations,
/// which is accurate enough for prayer times (a degree of latitude is roughly
/// 111 km; a few hundred metres changes the time by seconds at most).
library;

import 'dart:math' as math;

/// A city or town the user can choose as their prayer location.
class EgyptCity {
  const EgyptCity({
    required this.name,
    required this.governorate,
    required this.latitude,
    required this.longitude,
  });

  /// Arabic display name, e.g. «الإسكندرية».
  final String name;

  /// Arabic governorate name, e.g. «الإسكندرية».
  final String governorate;

  final double latitude;
  final double longitude;

  /// A compact coordinate label with four decimals (~11 m precision).
  String get coordinates =>
      '${latitude.toStringAsFixed(4)}، ${longitude.toStringAsFixed(4)}';
}

/// Governorates in the order they are shown in the picker: Cairo first, then
/// the Delta, the Canal, Sinai, the coast and Upper Egypt.
const List<String> kEgyptGovernorates = [
  'القاهرة',
  'الجيزة',
  'الإسكندرية',
  'القليوبية',
  'الشرقية',
  'الدقهلية',
  'البحيرة',
  'المنوفية',
  'الغربية',
  'كفر الشيخ',
  'دمياط',
  'بورسعيد',
  'الإسماعيلية',
  'السويس',
  'شمال سيناء',
  'جنوب سيناء',
  'مطروح',
  'الوادي الجديد',
  'بني سويف',
  'الفيوم',
  'المنيا',
  'أسيوط',
  'سوهاج',
  'قنا',
  'الأقصر',
  'أسوان',
  'البحر الأحمر',
];

/// Every selectable city.
const List<EgyptCity> kEgyptCities = [
  // القاهرة
  EgyptCity(
    name: 'القاهرة',
    governorate: 'القاهرة',
    latitude: 30.0444,
    longitude: 31.2357,
  ),
  EgyptCity(
    name: 'مدينة نصر',
    governorate: 'القاهرة',
    latitude: 30.0626,
    longitude: 31.3400,
  ),
  EgyptCity(
    name: 'مصر الجديدة',
    governorate: 'القاهرة',
    latitude: 30.0910,
    longitude: 31.3450,
  ),
  EgyptCity(
    name: 'المعادي',
    governorate: 'القاهرة',
    latitude: 29.9602,
    longitude: 31.2569,
  ),
  EgyptCity(
    name: 'حلوان',
    governorate: 'القاهرة',
    latitude: 29.8414,
    longitude: 31.3008,
  ),
  EgyptCity(
    name: 'القاهرة الجديدة',
    governorate: 'القاهرة',
    latitude: 30.0300,
    longitude: 31.4700,
  ),
  EgyptCity(
    name: 'شبرا',
    governorate: 'القاهرة',
    latitude: 30.1100,
    longitude: 31.2450,
  ),
  // الجيزة
  EgyptCity(
    name: 'الجيزة',
    governorate: 'الجيزة',
    latitude: 30.0131,
    longitude: 31.2089,
  ),
  EgyptCity(
    name: '6 أكتوبر',
    governorate: 'الجيزة',
    latitude: 29.9285,
    longitude: 30.9188,
  ),
  EgyptCity(
    name: 'الشيخ زايد',
    governorate: 'الجيزة',
    latitude: 30.0130,
    longitude: 30.9720,
  ),
  EgyptCity(
    name: 'الحوامدية',
    governorate: 'الجيزة',
    latitude: 29.9000,
    longitude: 31.2500,
  ),
  EgyptCity(
    name: 'البدرشين',
    governorate: 'الجيزة',
    latitude: 29.8500,
    longitude: 31.2667,
  ),
  EgyptCity(
    name: 'أوسيم',
    governorate: 'الجيزة',
    latitude: 30.1167,
    longitude: 31.1333,
  ),
  EgyptCity(
    name: 'كرداسة',
    governorate: 'الجيزة',
    latitude: 30.0333,
    longitude: 31.1167,
  ),
  // الإسكندرية
  EgyptCity(
    name: 'الإسكندرية',
    governorate: 'الإسكندرية',
    latitude: 31.2001,
    longitude: 29.9187,
  ),
  EgyptCity(
    name: 'برج العرب',
    governorate: 'الإسكندرية',
    latitude: 30.9180,
    longitude: 29.5400,
  ),
  EgyptCity(
    name: 'أبو قير',
    governorate: 'الإسكندرية',
    latitude: 31.3167,
    longitude: 30.0667,
  ),
  EgyptCity(
    name: 'العامرية',
    governorate: 'الإسكندرية',
    latitude: 31.0333,
    longitude: 29.8000,
  ),
  // القليوبية
  EgyptCity(
    name: 'بنها',
    governorate: 'القليوبية',
    latitude: 30.4660,
    longitude: 31.1848,
  ),
  EgyptCity(
    name: 'شبرا الخيمة',
    governorate: 'القليوبية',
    latitude: 30.1286,
    longitude: 31.2422,
  ),
  EgyptCity(
    name: 'القناطر الخيرية',
    governorate: 'القليوبية',
    latitude: 30.1833,
    longitude: 31.1333,
  ),
  EgyptCity(
    name: 'الخانكة',
    governorate: 'القليوبية',
    latitude: 30.2167,
    longitude: 31.3667,
  ),
  EgyptCity(
    name: 'قليوب',
    governorate: 'القليوبية',
    latitude: 30.1833,
    longitude: 31.2167,
  ),
  EgyptCity(
    name: 'طوخ',
    governorate: 'القليوبية',
    latitude: 30.3500,
    longitude: 31.2000,
  ),
  // الشرقية
  EgyptCity(
    name: 'الزقازيق',
    governorate: 'الشرقية',
    latitude: 30.5877,
    longitude: 31.5020,
  ),
  EgyptCity(
    name: 'العاشر من رمضان',
    governorate: 'الشرقية',
    latitude: 30.2970,
    longitude: 31.7460,
  ),
  EgyptCity(
    name: 'بلبيس',
    governorate: 'الشرقية',
    latitude: 30.4160,
    longitude: 31.5710,
  ),
  EgyptCity(
    name: 'أبو حماد',
    governorate: 'الشرقية',
    latitude: 30.5330,
    longitude: 31.6830,
  ),
  EgyptCity(
    name: 'فاقوس',
    governorate: 'الشرقية',
    latitude: 30.7333,
    longitude: 31.8000,
  ),
  EgyptCity(
    name: 'منيا القمح',
    governorate: 'الشرقية',
    latitude: 30.5167,
    longitude: 31.3500,
  ),
  // الدقهلية
  EgyptCity(
    name: 'المنصورة',
    governorate: 'الدقهلية',
    latitude: 31.0409,
    longitude: 31.3785,
  ),
  EgyptCity(
    name: 'ميت غمر',
    governorate: 'الدقهلية',
    latitude: 30.7180,
    longitude: 31.2590,
  ),
  EgyptCity(
    name: 'طلخا',
    governorate: 'الدقهلية',
    latitude: 31.0500,
    longitude: 31.3667,
  ),
  EgyptCity(
    name: 'دكرنس',
    governorate: 'الدقهلية',
    latitude: 31.0833,
    longitude: 31.6000,
  ),
  EgyptCity(
    name: 'بلقاس',
    governorate: 'الدقهلية',
    latitude: 31.2167,
    longitude: 31.3667,
  ),
  EgyptCity(
    name: 'شربين',
    governorate: 'الدقهلية',
    latitude: 31.2000,
    longitude: 31.4667,
  ),
  EgyptCity(
    name: 'أجا',
    governorate: 'الدقهلية',
    latitude: 30.9333,
    longitude: 31.2833,
  ),
  // البحيرة
  EgyptCity(
    name: 'دمنهور',
    governorate: 'البحيرة',
    latitude: 31.0341,
    longitude: 30.4682,
  ),
  EgyptCity(
    name: 'كفر الدوار',
    governorate: 'البحيرة',
    latitude: 31.1300,
    longitude: 30.1300,
  ),
  EgyptCity(
    name: 'رشيد',
    governorate: 'البحيرة',
    latitude: 31.4000,
    longitude: 30.4167,
  ),
  EgyptCity(
    name: 'إدكو',
    governorate: 'البحيرة',
    latitude: 31.3000,
    longitude: 30.3000,
  ),
  EgyptCity(
    name: 'أبو المطامير',
    governorate: 'البحيرة',
    latitude: 30.9167,
    longitude: 30.1833,
  ),
  EgyptCity(
    name: 'المحمودية',
    governorate: 'البحيرة',
    latitude: 31.1833,
    longitude: 30.5333,
  ),
  EgyptCity(
    name: 'إيتاي البارود',
    governorate: 'البحيرة',
    latitude: 30.8833,
    longitude: 30.6667,
  ),
  // المنوفية
  EgyptCity(
    name: 'شبين الكوم',
    governorate: 'المنوفية',
    latitude: 30.5550,
    longitude: 31.0090,
  ),
  EgyptCity(
    name: 'مدينة السادات',
    governorate: 'المنوفية',
    latitude: 30.3667,
    longitude: 30.5333,
  ),
  EgyptCity(
    name: 'منوف',
    governorate: 'المنوفية',
    latitude: 30.4667,
    longitude: 30.9333,
  ),
  EgyptCity(
    name: 'أشمون',
    governorate: 'المنوفية',
    latitude: 30.3000,
    longitude: 30.9667,
  ),
  EgyptCity(
    name: 'قويسنا',
    governorate: 'المنوفية',
    latitude: 30.5667,
    longitude: 31.1500,
  ),
  EgyptCity(
    name: 'بركة السبع',
    governorate: 'المنوفية',
    latitude: 30.6333,
    longitude: 31.0833,
  ),
  EgyptCity(
    name: 'تلا',
    governorate: 'المنوفية',
    latitude: 30.6833,
    longitude: 30.9500,
  ),
  // الغربية
  EgyptCity(
    name: 'طنطا',
    governorate: 'الغربية',
    latitude: 30.7865,
    longitude: 31.0004,
  ),
  EgyptCity(
    name: 'المحلة الكبرى',
    governorate: 'الغربية',
    latitude: 30.9690,
    longitude: 31.1660,
  ),
  EgyptCity(
    name: 'كفر الزيات',
    governorate: 'الغربية',
    latitude: 30.8167,
    longitude: 30.8167,
  ),
  EgyptCity(
    name: 'زفتى',
    governorate: 'الغربية',
    latitude: 30.7167,
    longitude: 31.2500,
  ),
  EgyptCity(
    name: 'سمنود',
    governorate: 'الغربية',
    latitude: 30.9667,
    longitude: 31.2333,
  ),
  EgyptCity(
    name: 'بسيون',
    governorate: 'الغربية',
    latitude: 30.5333,
    longitude: 30.8000,
  ),
  // كفر الشيخ
  EgyptCity(
    name: 'كفر الشيخ',
    governorate: 'كفر الشيخ',
    latitude: 31.1117,
    longitude: 30.9398,
  ),
  EgyptCity(
    name: 'دسوق',
    governorate: 'كفر الشيخ',
    latitude: 31.1330,
    longitude: 30.6470,
  ),
  EgyptCity(
    name: 'فوه',
    governorate: 'كفر الشيخ',
    latitude: 31.0167,
    longitude: 30.5500,
  ),
  EgyptCity(
    name: 'مطوبس',
    governorate: 'كفر الشيخ',
    latitude: 31.3000,
    longitude: 30.5500,
  ),
  EgyptCity(
    name: 'سيدي سالم',
    governorate: 'كفر الشيخ',
    latitude: 31.2667,
    longitude: 30.7833,
  ),
  EgyptCity(
    name: 'بيلا',
    governorate: 'كفر الشيخ',
    latitude: 31.1667,
    longitude: 31.2167,
  ),
  // دمياط
  EgyptCity(
    name: 'دمياط',
    governorate: 'دمياط',
    latitude: 31.4165,
    longitude: 31.8133,
  ),
  EgyptCity(
    name: 'دمياط الجديدة',
    governorate: 'دمياط',
    latitude: 31.4100,
    longitude: 31.7500,
  ),
  EgyptCity(
    name: 'رأس البر',
    governorate: 'دمياط',
    latitude: 31.5167,
    longitude: 31.8333,
  ),
  EgyptCity(
    name: 'فارسكور',
    governorate: 'دمياط',
    latitude: 31.3333,
    longitude: 31.7500,
  ),
  EgyptCity(
    name: 'كفر سعد',
    governorate: 'دمياط',
    latitude: 31.3167,
    longitude: 31.6500,
  ),
  EgyptCity(
    name: 'الزرقا',
    governorate: 'دمياط',
    latitude: 31.3667,
    longitude: 31.6000,
  ),
  // بورسعيد
  EgyptCity(
    name: 'بورسعيد',
    governorate: 'بورسعيد',
    latitude: 31.2653,
    longitude: 32.3019,
  ),
  EgyptCity(
    name: 'بورفؤاد',
    governorate: 'بورسعيد',
    latitude: 31.2333,
    longitude: 32.3167,
  ),
  // الإسماعيلية
  EgyptCity(
    name: 'الإسماعيلية',
    governorate: 'الإسماعيلية',
    latitude: 30.5852,
    longitude: 32.2654,
  ),
  EgyptCity(
    name: 'فايد',
    governorate: 'الإسماعيلية',
    latitude: 30.3167,
    longitude: 32.3000,
  ),
  EgyptCity(
    name: 'أبو صوير',
    governorate: 'الإسماعيلية',
    latitude: 30.5333,
    longitude: 32.1333,
  ),
  EgyptCity(
    name: 'القنطرة شرق',
    governorate: 'الإسماعيلية',
    latitude: 30.8500,
    longitude: 32.3167,
  ),
  EgyptCity(
    name: 'القنطرة غرب',
    governorate: 'الإسماعيلية',
    latitude: 30.8500,
    longitude: 32.2667,
  ),
  // السويس
  EgyptCity(
    name: 'السويس',
    governorate: 'السويس',
    latitude: 29.9668,
    longitude: 32.5498,
  ),
  EgyptCity(
    name: 'الأربعين',
    governorate: 'السويس',
    latitude: 29.9667,
    longitude: 32.5167,
  ),
  EgyptCity(
    name: 'عتاقة',
    governorate: 'السويس',
    latitude: 29.9667,
    longitude: 32.4833,
  ),
  // شمال سيناء
  EgyptCity(
    name: 'العريش',
    governorate: 'شمال سيناء',
    latitude: 31.1316,
    longitude: 33.7984,
  ),
  EgyptCity(
    name: 'رفح',
    governorate: 'شمال سيناء',
    latitude: 31.2833,
    longitude: 34.2333,
  ),
  EgyptCity(
    name: 'الشيخ زويد',
    governorate: 'شمال سيناء',
    latitude: 31.2833,
    longitude: 34.1167,
  ),
  EgyptCity(
    name: 'بئر العبد',
    governorate: 'شمال سيناء',
    latitude: 31.0333,
    longitude: 33.6167,
  ),
  EgyptCity(
    name: 'الحسنة',
    governorate: 'شمال سيناء',
    latitude: 30.9667,
    longitude: 33.5167,
  ),
  // جنوب سيناء
  EgyptCity(
    name: 'الطور',
    governorate: 'جنوب سيناء',
    latitude: 28.2410,
    longitude: 33.6230,
  ),
  EgyptCity(
    name: 'شرم الشيخ',
    governorate: 'جنوب سيناء',
    latitude: 27.9158,
    longitude: 34.3300,
  ),
  EgyptCity(
    name: 'دهب',
    governorate: 'جنوب سيناء',
    latitude: 28.5090,
    longitude: 34.5130,
  ),
  EgyptCity(
    name: 'نويبع',
    governorate: 'جنوب سيناء',
    latitude: 29.0330,
    longitude: 34.6660,
  ),
  EgyptCity(
    name: 'سانت كاترين',
    governorate: 'جنوب سيناء',
    latitude: 28.5560,
    longitude: 33.9760,
  ),
  EgyptCity(
    name: 'رأس سدر',
    governorate: 'جنوب سيناء',
    latitude: 29.5900,
    longitude: 32.7100,
  ),
  EgyptCity(
    name: 'أبو زنيمة',
    governorate: 'جنوب سيناء',
    latitude: 29.0333,
    longitude: 33.6333,
  ),
  // مطروح
  EgyptCity(
    name: 'مرسى مطروح',
    governorate: 'مطروح',
    latitude: 31.3543,
    longitude: 27.2373,
  ),
  EgyptCity(
    name: 'العلمين',
    governorate: 'مطروح',
    latitude: 30.8333,
    longitude: 28.9500,
  ),
  EgyptCity(
    name: 'سيوة',
    governorate: 'مطروح',
    latitude: 29.2032,
    longitude: 25.5195,
  ),
  EgyptCity(
    name: 'الحمام',
    governorate: 'مطروح',
    latitude: 30.8000,
    longitude: 29.0333,
  ),
  EgyptCity(
    name: 'الضبعة',
    governorate: 'مطروح',
    latitude: 31.0333,
    longitude: 28.4333,
  ),
  EgyptCity(
    name: 'السلوم',
    governorate: 'مطروح',
    latitude: 31.5500,
    longitude: 25.1500,
  ),
  // الوادي الجديد
  EgyptCity(
    name: 'الخارجة',
    governorate: 'الوادي الجديد',
    latitude: 25.4514,
    longitude: 30.5464,
  ),
  EgyptCity(
    name: 'الداخلة',
    governorate: 'الوادي الجديد',
    latitude: 25.5000,
    longitude: 29.1667,
  ),
  EgyptCity(
    name: 'الفرافرة',
    governorate: 'الوادي الجديد',
    latitude: 27.0667,
    longitude: 27.9667,
  ),
  EgyptCity(
    name: 'باريس',
    governorate: 'الوادي الجديد',
    latitude: 24.6667,
    longitude: 30.6167,
  ),
  // بني سويف
  EgyptCity(
    name: 'بني سويف',
    governorate: 'بني سويف',
    latitude: 29.0661,
    longitude: 31.0994,
  ),
  EgyptCity(
    name: 'الواسطى',
    governorate: 'بني سويف',
    latitude: 29.3333,
    longitude: 31.2333,
  ),
  EgyptCity(
    name: 'ناصر',
    governorate: 'بني سويف',
    latitude: 29.1833,
    longitude: 31.0833,
  ),
  EgyptCity(
    name: 'إهناسيا',
    governorate: 'بني سويف',
    latitude: 29.0333,
    longitude: 30.9167,
  ),
  EgyptCity(
    name: 'ببا',
    governorate: 'بني سويف',
    latitude: 28.9167,
    longitude: 30.9833,
  ),
  // الفيوم
  EgyptCity(
    name: 'الفيوم',
    governorate: 'الفيوم',
    latitude: 29.3084,
    longitude: 30.8428,
  ),
  EgyptCity(
    name: 'سنورس',
    governorate: 'الفيوم',
    latitude: 29.4000,
    longitude: 30.8667,
  ),
  EgyptCity(
    name: 'طامية',
    governorate: 'الفيوم',
    latitude: 29.4667,
    longitude: 30.9667,
  ),
  EgyptCity(
    name: 'إبشواي',
    governorate: 'الفيوم',
    latitude: 29.3667,
    longitude: 30.6833,
  ),
  EgyptCity(
    name: 'يوسف الصديق',
    governorate: 'الفيوم',
    latitude: 29.0833,
    longitude: 30.4333,
  ),
  // المنيا
  EgyptCity(
    name: 'المنيا',
    governorate: 'المنيا',
    latitude: 28.1099,
    longitude: 30.7503,
  ),
  EgyptCity(
    name: 'ملوي',
    governorate: 'المنيا',
    latitude: 27.7333,
    longitude: 30.8333,
  ),
  EgyptCity(
    name: 'سمالوط',
    governorate: 'المنيا',
    latitude: 28.3167,
    longitude: 30.8000,
  ),
  EgyptCity(
    name: 'مطاي',
    governorate: 'المنيا',
    latitude: 28.4167,
    longitude: 30.7667,
  ),
  EgyptCity(
    name: 'بني مزار',
    governorate: 'المنيا',
    latitude: 28.5000,
    longitude: 30.8000,
  ),
  EgyptCity(
    name: 'العدوة',
    governorate: 'المنيا',
    latitude: 28.3167,
    longitude: 30.9167,
  ),
  // أسيوط
  EgyptCity(
    name: 'أسيوط',
    governorate: 'أسيوط',
    latitude: 27.1809,
    longitude: 31.1837,
  ),
  EgyptCity(
    name: 'ديروط',
    governorate: 'أسيوط',
    latitude: 27.5500,
    longitude: 30.8167,
  ),
  EgyptCity(
    name: 'منفلوط',
    governorate: 'أسيوط',
    latitude: 27.3167,
    longitude: 30.9667,
  ),
  EgyptCity(
    name: 'القوصية',
    governorate: 'أسيوط',
    latitude: 27.4333,
    longitude: 30.8500,
  ),
  EgyptCity(
    name: 'أبنوب',
    governorate: 'أسيوط',
    latitude: 27.2667,
    longitude: 30.9500,
  ),
  EgyptCity(
    name: 'أبو تيج',
    governorate: 'أسيوط',
    latitude: 27.0333,
    longitude: 31.3167,
  ),
  // سوهاج
  EgyptCity(
    name: 'سوهاج',
    governorate: 'سوهاج',
    latitude: 26.5591,
    longitude: 31.6957,
  ),
  EgyptCity(
    name: 'طهطا',
    governorate: 'سوهاج',
    latitude: 26.7667,
    longitude: 31.5000,
  ),
  EgyptCity(
    name: 'جرجا',
    governorate: 'سوهاج',
    latitude: 26.3380,
    longitude: 31.8920,
  ),
  EgyptCity(
    name: 'أخميم',
    governorate: 'سوهاج',
    latitude: 26.5670,
    longitude: 31.7340,
  ),
  EgyptCity(
    name: 'البلينا',
    governorate: 'سوهاج',
    latitude: 26.2333,
    longitude: 32.0000,
  ),
  EgyptCity(
    name: 'المراغة',
    governorate: 'سوهاج',
    latitude: 26.7000,
    longitude: 31.6000,
  ),
  EgyptCity(
    name: 'ساقلته',
    governorate: 'سوهاج',
    latitude: 26.2167,
    longitude: 31.7833,
  ),
  // قنا
  EgyptCity(
    name: 'قنا',
    governorate: 'قنا',
    latitude: 26.1551,
    longitude: 32.7160,
  ),
  EgyptCity(
    name: 'نجع حمادي',
    governorate: 'قنا',
    latitude: 26.0490,
    longitude: 32.2410,
  ),
  EgyptCity(
    name: 'قوص',
    governorate: 'قنا',
    latitude: 25.9160,
    longitude: 32.7630,
  ),
  EgyptCity(
    name: 'إسنا',
    governorate: 'قنا',
    latitude: 25.2930,
    longitude: 32.5540,
  ),
  EgyptCity(
    name: 'أبو تشت',
    governorate: 'قنا',
    latitude: 26.1167,
    longitude: 32.2833,
  ),
  EgyptCity(
    name: 'دشنا',
    governorate: 'قنا',
    latitude: 26.1333,
    longitude: 32.6333,
  ),
  // الأقصر
  EgyptCity(
    name: 'الأقصر',
    governorate: 'الأقصر',
    latitude: 25.6872,
    longitude: 32.6396,
  ),
  EgyptCity(
    name: 'أرمنت',
    governorate: 'الأقصر',
    latitude: 25.6167,
    longitude: 32.5833,
  ),
  EgyptCity(
    name: 'البياضية',
    governorate: 'الأقصر',
    latitude: 25.6667,
    longitude: 32.6167,
  ),
  // أسوان
  EgyptCity(
    name: 'أسوان',
    governorate: 'أسوان',
    latitude: 24.0889,
    longitude: 32.8998,
  ),
  EgyptCity(
    name: 'كوم أمبو',
    governorate: 'أسوان',
    latitude: 24.4770,
    longitude: 32.9460,
  ),
  EgyptCity(
    name: 'إدفو',
    governorate: 'أسوان',
    latitude: 24.9780,
    longitude: 32.8770,
  ),
  EgyptCity(
    name: 'دراو',
    governorate: 'أسوان',
    latitude: 24.4000,
    longitude: 32.9333,
  ),
  EgyptCity(
    name: 'نصر النوبة',
    governorate: 'أسوان',
    latitude: 24.4667,
    longitude: 32.9000,
  ),
  EgyptCity(
    name: 'أبو سمبل',
    governorate: 'أسوان',
    latitude: 22.3370,
    longitude: 31.6250,
  ),
  // البحر الأحمر
  EgyptCity(
    name: 'الغردقة',
    governorate: 'البحر الأحمر',
    latitude: 27.2579,
    longitude: 33.8116,
  ),
  EgyptCity(
    name: 'سفاجا',
    governorate: 'البحر الأحمر',
    latitude: 26.7490,
    longitude: 33.9380,
  ),
  EgyptCity(
    name: 'مرسى علم',
    governorate: 'البحر الأحمر',
    latitude: 25.0670,
    longitude: 34.9000,
  ),
  EgyptCity(
    name: 'القصير',
    governorate: 'البحر الأحمر',
    latitude: 26.1040,
    longitude: 34.2810,
  ),
  EgyptCity(
    name: 'رأس غارب',
    governorate: 'البحر الأحمر',
    latitude: 28.3600,
    longitude: 33.0800,
  ),
  EgyptCity(
    name: 'شلاتين',
    governorate: 'البحر الأحمر',
    latitude: 23.1333,
    longitude: 35.5833,
  ),
];

/// Normalises Arabic for case- and diacritic-insensitive search.
///
/// Users type «اسكندريه» or «الإسكندرية» interchangeably; the picker should
/// find both.  Latin text is lower-cased as well.
String normalizeArabicSearch(String value) {
  var text = value.trim().toLowerCase();
  text = text.replaceAll(RegExp(r'[ؐ-ًؚ-ٰٟـ]'), '');
  text = text
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Returns the cities matching [query] by city or governorate name.
List<EgyptCity> searchEgyptCities(String query) {
  final needle = normalizeArabicSearch(query);
  if (needle.isEmpty) return kEgyptCities;
  return [
    for (final city in kEgyptCities)
      if (normalizeArabicSearch('${city.name} ${city.governorate}')
          .contains(needle))
        city,
  ];
}

/// Groups [cities] by governorate, preserving [kEgyptGovernorates]' order.
List<MapEntry<String, List<EgyptCity>>> groupEgyptCities(
  List<EgyptCity> cities,
) {
  final result = <MapEntry<String, List<EgyptCity>>>[];
  for (final governorate in kEgyptGovernorates) {
    final matches = [
      for (final city in cities)
        if (city.governorate == governorate) city,
    ];
    if (matches.isNotEmpty) result.add(MapEntry(governorate, matches));
  }
  return result;
}

/// The nearest known city to [latitude]/[longitude], or `null` when the
/// closest one is further than [maxKilometres].
///
/// Used as a friendly fallback when reverse geocoding is unavailable: a label
/// such as «المنصورة» reads better than raw coordinates, and the coordinates
/// themselves remain stored so the calculation is still exact.
EgyptCity? nearestEgyptCity(
  double latitude,
  double longitude, {
  double maxKilometres = 80,
}) {
  EgyptCity? best;
  var bestDistance = double.infinity;
  for (final city in kEgyptCities) {
    final distance = _haversineKilometres(
      latitude,
      longitude,
      city.latitude,
      city.longitude,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      best = city;
    }
  }
  return bestDistance <= maxKilometres ? best : null;
}

double _haversineKilometres(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _radians(double degrees) => degrees * math.pi / 180.0;
