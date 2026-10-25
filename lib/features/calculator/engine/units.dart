/// Offline unit converter spanning the categories students actually use:
/// length, area, volume, mass, speed, pressure, energy, power, temperature,
/// time, angle and digital storage.
///
/// Every unit stores a linear mapping to the category's base unit:
/// `base = (value + offset) × factor`. Only temperature needs a non-zero
/// offset, which is why offsets are part of the model rather than a special
/// case in the UI.
library;

import 'calculator_error.dart';
import 'number_format.dart';

class UnitDefinition {
  const UnitDefinition({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.nameEn,
    required this.symbol,
    required this.factor,
    this.offset = 0,
  });

  final String id;
  final String categoryId;
  final String nameAr;
  final String nameEn;
  final String symbol;
  final double factor;
  final double offset;

  double toBase(double value) => (value + offset) * factor;

  double fromBase(double baseValue) => baseValue / factor - offset;
}

class UnitCategory {
  const UnitCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.baseSymbol,
    required this.units,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String baseSymbol;
  final List<UnitDefinition> units;

  UnitDefinition? unit(String id) {
    for (final unit in units) {
      if (unit.id == id) return unit;
    }
    return null;
  }
}

final List<UnitCategory> unitCategories = <UnitCategory>[
  UnitCategory(
    id: 'length',
    nameAr: 'الطول',
    nameEn: 'Length',
    baseSymbol: 'm',
    units: <UnitDefinition>[
      _unit('length', 'meter', 'متر', 'Meter', 'm', 1),
      _unit('length', 'kilometer', 'كيلومتر', 'Kilometer', 'km', 1000),
      _unit('length', 'centimeter', 'سنتيمتر', 'Centimeter', 'cm', 0.01),
      _unit('length', 'millimeter', 'مليمتر', 'Millimeter', 'mm', 0.001),
      _unit('length', 'micrometer', 'ميكرومتر', 'Micrometer', 'µm', 1e-6),
      _unit('length', 'inch', 'بوصة', 'Inch', 'in', 0.0254),
      _unit('length', 'foot', 'قدم', 'Foot', 'ft', 0.3048),
      _unit('length', 'yard', 'ياردة', 'Yard', 'yd', 0.9144),
      _unit('length', 'mile', 'ميل', 'Mile', 'mi', 1609.344),
      _unit('length', 'nautical_mile', 'ميل بحري', 'Nautical mile', 'nmi', 1852),
    ],
  ),
  UnitCategory(
    id: 'area',
    nameAr: 'المساحة',
    nameEn: 'Area',
    baseSymbol: 'm²',
    units: <UnitDefinition>[
      _unit('area', 'square_meter', 'متر مربع', 'Square metre', 'm²', 1),
      _unit('area', 'square_kilometer', 'كيلومتر مربع', 'Square kilometre', 'km²', 1e6),
      _unit('area', 'square_centimeter', 'سنتيمتر مربع', 'Square centimetre', 'cm²', 1e-4),
      _unit('area', 'hectare', 'هكتار', 'Hectare', 'ha', 1e4),
      _unit('area', 'acre', 'فدان', 'Acre', 'ac', 4046.8564224),
      _unit('area', 'square_foot', 'قدم مربع', 'Square foot', 'ft²', 0.09290304),
      _unit('area', 'square_inch', 'بوصة مربعة', 'Square inch', 'in²', 0.00064516),
    ],
  ),
  UnitCategory(
    id: 'volume',
    nameAr: 'الحجم',
    nameEn: 'Volume',
    baseSymbol: 'L',
    units: <UnitDefinition>[
      _unit('volume', 'liter', 'لتر', 'Litre', 'L', 1),
      _unit('volume', 'milliliter', 'مليلتر', 'Millilitre', 'mL', 0.001),
      _unit('volume', 'cubic_meter', 'متر مكعب', 'Cubic metre', 'm³', 1000),
      _unit('volume', 'cubic_centimeter', 'سنتيمتر مكعب', 'Cubic centimetre', 'cm³', 0.001),
      _unit('volume', 'gallon_us', 'جالون أمريكي', 'US gallon', 'gal', 3.785411784),
      _unit('volume', 'quart_us', 'كوارت', 'US quart', 'qt', 0.946352946),
      _unit('volume', 'pint_us', 'باينت', 'US pint', 'pt', 0.473176473),
      _unit('volume', 'fluid_ounce_us', 'أونصة سائلة', 'US fluid ounce', 'fl oz', 0.0295735295625),
      _unit('volume', 'cup_us', 'كوب أمريكي', 'US cup', 'cup', 0.2365882365),
    ],
  ),
  UnitCategory(
    id: 'mass',
    nameAr: 'الكتلة',
    nameEn: 'Mass',
    baseSymbol: 'kg',
    units: <UnitDefinition>[
      _unit('mass', 'kilogram', 'كيلوجرام', 'Kilogram', 'kg', 1),
      _unit('mass', 'gram', 'جرام', 'Gram', 'g', 0.001),
      _unit('mass', 'milligram', 'مليجرام', 'Milligram', 'mg', 1e-6),
      _unit('mass', 'tonne', 'طن', 'Tonne', 't', 1000),
      _unit('mass', 'pound', 'رطل', 'Pound', 'lb', 0.45359237),
      _unit('mass', 'ounce', 'أونصة', 'Ounce', 'oz', 0.028349523125),
      _unit('mass', 'stone', 'ستون', 'Stone', 'st', 6.35029318),
    ],
  ),
  UnitCategory(
    id: 'speed',
    nameAr: 'السرعة',
    nameEn: 'Speed',
    baseSymbol: 'm/s',
    units: <UnitDefinition>[
      _unit('speed', 'meter_per_second', 'متر/ثانية', 'Metre per second', 'm/s', 1),
      _unit('speed', 'kilometer_per_hour', 'كيلومتر/ساعة', 'Kilometre per hour', 'km/h', 1 / 3.6),
      _unit('speed', 'mile_per_hour', 'ميل/ساعة', 'Mile per hour', 'mph', 0.44704),
      _unit('speed', 'knot', 'عقدة', 'Knot', 'kn', 0.5144444444444445),
      _unit('speed', 'foot_per_second', 'قدم/ثانية', 'Foot per second', 'ft/s', 0.3048),
      _unit('speed', 'mach', 'ماخ (تقريبي)', 'Mach (approx.)', 'Mach', 343),
    ],
  ),
  UnitCategory(
    id: 'pressure',
    nameAr: 'الضغط',
    nameEn: 'Pressure',
    baseSymbol: 'Pa',
    units: <UnitDefinition>[
      _unit('pressure', 'pascal', 'باسكال', 'Pascal', 'Pa', 1),
      _unit('pressure', 'kilopascal', 'كيلوباسكال', 'Kilopascal', 'kPa', 1000),
      _unit('pressure', 'megapascal', 'ميجاباسكال', 'Megapascal', 'MPa', 1e6),
      _unit('pressure', 'bar', 'بار', 'Bar', 'bar', 1e5),
      _unit('pressure', 'atmosphere', 'ضغط جوي', 'Atmosphere', 'atm', 101325),
      _unit('pressure', 'psi', 'رطل/بوصة مربعة', 'Pound per square inch', 'psi', 6894.757293168),
      _unit('pressure', 'millimeter_mercury', 'مليمتر زئبق', 'Millimetre of mercury', 'mmHg', 133.322387415),
      _unit('pressure', 'torr', 'تور', 'Torr', 'Torr', 133.32236842105263),
    ],
  ),
  UnitCategory(
    id: 'energy',
    nameAr: 'الطاقة',
    nameEn: 'Energy',
    baseSymbol: 'J',
    units: <UnitDefinition>[
      _unit('energy', 'joule', 'جول', 'Joule', 'J', 1),
      _unit('energy', 'kilojoule', 'كيلوجول', 'Kilojoule', 'kJ', 1000),
      _unit('energy', 'calorie', 'كالوري', 'Calorie', 'cal', 4.184),
      _unit('energy', 'kilocalorie', 'كيلوكالوري', 'Kilocalorie', 'kcal', 4184),
      _unit('energy', 'watt_hour', 'واط/ساعة', 'Watt-hour', 'Wh', 3600),
      _unit('energy', 'kilowatt_hour', 'كيلوواط/ساعة', 'Kilowatt-hour', 'kWh', 3.6e6),
      _unit('energy', 'electronvolt', 'إلكترون فولت', 'Electronvolt', 'eV', 1.602176634e-19),
      _unit('energy', 'btu', 'وحدة حرارية بريطانية', 'British thermal unit', 'BTU', 1055.05585262),
      _unit('energy', 'foot_pound', 'قدم-رطل', 'Foot-pound', 'ft·lb', 1.3558179483314004),
    ],
  ),
  UnitCategory(
    id: 'power',
    nameAr: 'القدرة',
    nameEn: 'Power',
    baseSymbol: 'W',
    units: <UnitDefinition>[
      _unit('power', 'watt', 'واط', 'Watt', 'W', 1),
      _unit('power', 'kilowatt', 'كيلوواط', 'Kilowatt', 'kW', 1000),
      _unit('power', 'megawatt', 'ميجاواط', 'Megawatt', 'MW', 1e6),
      _unit('power', 'horsepower', 'حصان', 'Horsepower', 'hp', 745.6998715822702),
      _unit('power', 'btu_per_hour', 'BTU/ساعة', 'BTU per hour', 'BTU/h', 0.2930710701722222),
    ],
  ),
  UnitCategory(
    id: 'temperature',
    nameAr: 'الحرارة',
    nameEn: 'Temperature',
    baseSymbol: 'K',
    units: <UnitDefinition>[
      const UnitDefinition(
        id: 'celsius',
        categoryId: 'temperature',
        nameAr: 'سيلزيوس',
        nameEn: 'Celsius',
        symbol: '°C',
        factor: 1,
        offset: 273.15,
      ),
      const UnitDefinition(
        id: 'fahrenheit',
        categoryId: 'temperature',
        nameAr: 'فهرنهايت',
        nameEn: 'Fahrenheit',
        symbol: '°F',
        factor: 5 / 9,
        offset: 459.67,
      ),
      const UnitDefinition(
        id: 'kelvin',
        categoryId: 'temperature',
        nameAr: 'كلفن',
        nameEn: 'Kelvin',
        symbol: 'K',
        factor: 1,
      ),
      const UnitDefinition(
        id: 'rankine',
        categoryId: 'temperature',
        nameAr: 'رانكين',
        nameEn: 'Rankine',
        symbol: '°R',
        factor: 5 / 9,
      ),
    ],
  ),
  UnitCategory(
    id: 'time',
    nameAr: 'الزمن',
    nameEn: 'Time',
    baseSymbol: 's',
    units: <UnitDefinition>[
      _unit('time', 'second', 'ثانية', 'Second', 's', 1),
      _unit('time', 'millisecond', 'مليثانية', 'Millisecond', 'ms', 0.001),
      _unit('time', 'minute', 'دقيقة', 'Minute', 'min', 60),
      _unit('time', 'hour', 'ساعة', 'Hour', 'h', 3600),
      _unit('time', 'day', 'يوم', 'Day', 'd', 86400),
      _unit('time', 'week', 'أسبوع', 'Week', 'wk', 604800),
    ],
  ),
  UnitCategory(
    id: 'angle',
    nameAr: 'الزاوية',
    nameEn: 'Angle',
    baseSymbol: 'rad',
    units: <UnitDefinition>[
      _unit('angle', 'radian', 'راديان', 'Radian', 'rad', 1),
      _unit('angle', 'degree', 'درجة', 'Degree', '°', 0.017453292519943295),
      _unit('angle', 'gradian', 'جراديان', 'Gradian', 'grad', 0.015707963267948967),
      _unit('angle', 'turn', 'لفة', 'Turn', 'turn', 6.283185307179586),
      _unit('angle', 'arcminute', 'دقيقة قوسية', 'Arcminute', '′', 0.0002908882086657216),
      _unit('angle', 'arcsecond', 'ثانية قوسية', 'Arcsecond', '″', 4.84813681109536e-6),
    ],
  ),
  UnitCategory(
    id: 'data',
    nameAr: 'البيانات',
    nameEn: 'Data',
    baseSymbol: 'B',
    units: <UnitDefinition>[
      _unit('data', 'byte', 'بايت', 'Byte', 'B', 1),
      _unit('data', 'bit', 'بت', 'Bit', 'bit', 1 / 8),
      _unit('data', 'kilobyte', 'كيلوبايت', 'Kilobyte', 'KB', 1000),
      _unit('data', 'kibibyte', 'كيبي بايت', 'Kibibyte', 'KiB', 1024),
      _unit('data', 'megabyte', 'ميجابايت', 'Megabyte', 'MB', 1e6),
      _unit('data', 'mebibyte', 'ميبي بايت', 'Mebibyte', 'MiB', 1048576),
      _unit('data', 'gigabyte', 'جيجابايت', 'Gigabyte', 'GB', 1e9),
      _unit('data', 'gibibyte', 'جيبي بايت', 'Gibibyte', 'GiB', 1073741824),
      _unit('data', 'terabyte', 'تيرابايت', 'Terabyte', 'TB', 1e12),
      _unit('data', 'tebibyte', 'تيبي بايت', 'Tebibyte', 'TiB', 1099511627776),
    ],
  ),
];

UnitDefinition _unit(
  String category,
  String id,
  String nameAr,
  String nameEn,
  String symbol,
  double factor,
) => UnitDefinition(
  id: id,
  categoryId: category,
  nameAr: nameAr,
  nameEn: nameEn,
  symbol: symbol,
  factor: factor,
);

UnitCategory? unitCategory(String id) {
  for (final category in unitCategories) {
    if (category.id == id) return category;
  }
  return null;
}

UnitDefinition? findUnit(String id) {
  for (final category in unitCategories) {
    final unit = category.unit(id);
    if (unit != null) return unit;
  }
  return null;
}

double convertUnit(double value, UnitDefinition from, UnitDefinition to) {
  if (from.categoryId != to.categoryId) {
    throw const CalcError(
      CalcErrorKind.dimension,
      detail: 'الوحدتين من فئتين مختلفتين.',
    );
  }
  if (!value.isFinite) {
    throw const CalcError(CalcErrorKind.math);
  }
  return to.fromBase(from.toBase(value));
}

String formatUnitResult(
  double value,
  UnitDefinition unit, {
  int significant = 12,
}) {
  final number = formatReal(value, significant: significant);
  return '$number ${unit.symbol}';
}

/// Case-insensitive search across Arabic and English unit names.
List<UnitDefinition> searchUnits(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const <UnitDefinition>[];
  final result = <UnitDefinition>[];
  for (final category in unitCategories) {
    for (final unit in category.units) {
      if (unit.nameAr.contains(query.trim()) ||
          unit.nameEn.toLowerCase().contains(needle) ||
          unit.symbol.toLowerCase().contains(needle) ||
          category.nameAr.contains(query.trim()) ||
          category.nameEn.toLowerCase().contains(needle)) {
        result.add(unit);
      }
    }
  }
  return result;
}
