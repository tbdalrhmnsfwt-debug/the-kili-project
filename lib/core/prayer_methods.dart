/// Calculation methods and Asr madhabs offered by the prayer feature.
///
/// The default is the Egyptian General Authority of Survey, which is what most
/// Egyptian mosques follow.  The labels are Arabic so they can be rendered
/// directly in the settings sheet; [id] values are what gets persisted.
library;

import 'package:adhan_dart/adhan_dart.dart';

/// One selectable calculation method.
class PrayerMethodOption {
  const PrayerMethodOption({
    required this.id,
    required this.label,
    this.description = '',
  });

  /// Stable identifier, stored in [LocalStore].
  final String id;

  /// Arabic name shown in the picker.
  final String label;

  /// Optional Arabic hint (region, authority, …).
  final String description;
}

/// Every method `adhan_dart` supports, ordered with the locally relevant ones
/// first.
const List<PrayerMethodOption> kPrayerMethods = [
  PrayerMethodOption(
    id: 'egyptian',
    label: 'الهيئة المصرية العامة للمساحة',
    description: 'الطريقة الافتراضية في مصر',
  ),
  PrayerMethodOption(
    id: 'ummAlQura',
    label: 'أم القرى',
    description: 'السعودية',
  ),
  PrayerMethodOption(id: 'muslimWorldLeague', label: 'رابطة العالم الإسلامي'),
  PrayerMethodOption(
    id: 'gulfRegion',
    label: 'دول الخليج',
    description: 'العشاء بعد المغرب بـ 90 دقيقة',
  ),
  PrayerMethodOption(id: 'karachi', label: 'جامعة العلوم الإسلامية — كراتشي'),
  PrayerMethodOption(id: 'northAmerica', label: 'أمريكا الشمالية (ISNA)'),
  PrayerMethodOption(id: 'kuwait', label: 'الكويت'),
  PrayerMethodOption(id: 'qatar', label: 'قطر'),
  PrayerMethodOption(id: 'dubai', label: 'دبي'),
  PrayerMethodOption(id: 'turkiye', label: 'تركيا (ديانت)'),
  PrayerMethodOption(id: 'jordan', label: 'الأردن'),
  PrayerMethodOption(id: 'morocco', label: 'المغرب'),
  PrayerMethodOption(id: 'algerian', label: 'الجزائر'),
  PrayerMethodOption(id: 'tunisia', label: 'تونس'),
  PrayerMethodOption(id: 'singapore', label: 'سنغافورة'),
  PrayerMethodOption(id: 'indonesian', label: 'إندونيسيا (كمناج)'),
  PrayerMethodOption(id: 'france', label: 'فرنسا (UOIF)'),
  PrayerMethodOption(id: 'russia', label: 'روسيا'),
  PrayerMethodOption(id: 'portugal', label: 'البرتغال'),
  PrayerMethodOption(id: 'moonsightingCommittee', label: 'لجنة رؤية الهلال'),
  PrayerMethodOption(id: 'jafari', label: 'الجعفري (الشيعة الإثنا عشرية)'),
  PrayerMethodOption(id: 'tehran', label: 'طهران'),
  PrayerMethodOption(id: 'other', label: 'أخرى'),
];

/// Looks up a method, falling back to the Egyptian default for unknown ids
/// (for example a value written by a future version of the app).
PrayerMethodOption prayerMethodById(String id) {
  for (final method in kPrayerMethods) {
    if (method.id == id) return method;
  }
  return kPrayerMethods.first;
}

/// The Asr madhab choices.
class PrayerMadhabOption {
  const PrayerMadhabOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

const List<PrayerMadhabOption> kPrayerMadhabs = [
  PrayerMadhabOption(
    id: 'shafi',
    label: 'الشافعي',
    description: 'وقت العصر عندما يصبح ظل الشيء مثل طوله',
  ),
  PrayerMadhabOption(
    id: 'hanafi',
    label: 'الحنفي',
    description: 'وقت العصر عندما يصبح ظل الشيء ضعف طوله',
  ),
];

/// Looks up a madhab, defaulting to Shafi.
PrayerMadhabOption prayerMadhabById(String id) {
  for (final madhab in kPrayerMadhabs) {
    if (madhab.id == id) return madhab;
  }
  return kPrayerMadhabs.first;
}

/// Builds the parameters handed to `adhan_dart`.
///
/// The method factories already carry the authority's Fajr/Isha angles and
/// minute adjustments; only the Asr madhab has to be applied separately.
CalculationParameters prayerParameters({
  String methodId = 'egyptian',
  String madhabId = 'shafi',
}) {
  final base = _methodParameters(methodId);
  base.madhab = madhabId == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
  return base;
}

CalculationParameters _methodParameters(String id) {
  switch (id) {
    case 'ummAlQura':
      return CalculationMethodParameters.ummAlQura();
    case 'muslimWorldLeague':
      return CalculationMethodParameters.muslimWorldLeague();
    case 'gulfRegion':
      return CalculationMethodParameters.gulfRegion();
    case 'karachi':
      return CalculationMethodParameters.karachi();
    case 'northAmerica':
      return CalculationMethodParameters.northAmerica();
    case 'kuwait':
      return CalculationMethodParameters.kuwait();
    case 'qatar':
      return CalculationMethodParameters.qatar();
    case 'dubai':
      return CalculationMethodParameters.dubai();
    case 'turkiye':
      return CalculationMethodParameters.turkiye();
    case 'jordan':
      return CalculationMethodParameters.jordan();
    case 'morocco':
      return CalculationMethodParameters.morocco();
    case 'algerian':
      return CalculationMethodParameters.algerian();
    case 'tunisia':
      return CalculationMethodParameters.tunisia();
    case 'singapore':
      return CalculationMethodParameters.singapore();
    case 'indonesian':
      return CalculationMethodParameters.indonesian();
    case 'france':
      return CalculationMethodParameters.france();
    case 'russia':
      return CalculationMethodParameters.russia();
    case 'portugal':
      return CalculationMethodParameters.portugal();
    case 'moonsightingCommittee':
      return CalculationMethodParameters.moonsightingCommittee();
    case 'jafari':
      return CalculationMethodParameters.jafari();
    case 'tehran':
      return CalculationMethodParameters.tehran();
    case 'other':
      return CalculationMethodParameters.other();
    case 'egyptian':
    default:
      return CalculationMethodParameters.egyptian();
  }
}
