/// Offline, searchable formula reference with live evaluation.
///
/// The expressions use the calculator's own parser, so every formula can be
/// evaluated after the user fills its variables. Constants such as `pi` and
/// `e` are understood. This is a study reference, not an official curriculum
/// list; the UI labels it accordingly.
library;

import 'evaluator.dart';
import 'math_value.dart';
import 'parser.dart';

class FormulaVariable {
  const FormulaVariable(this.symbol, this.nameAr, {this.unit = ''});

  final String symbol;
  final String nameAr;
  final String unit;
}

class FormulaEntry {
  const FormulaEntry({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    required this.expression,
    required this.variables,
    this.noteAr = '',
    this.constants = const <String, double>{},
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String category;
  final String expression;
  final List<FormulaVariable> variables;
  final String noteAr;
  final Map<String, double> constants;

  EvalValue evaluate(
    Map<String, double> values, {
    AngleUnit angleUnit = AngleUnit.degrees,
    bool allowComplex = false,
  }) {
    final context = EvalContext(angleUnit: angleUnit, allowComplex: allowComplex);
    for (final variable in variables) {
      context.variables[variable.symbol] = EvalValue.real(values[variable.symbol] ?? 0);
    }
    for (final entry in constants.entries) {
      context.variables[entry.key] = EvalValue.real(entry.value);
    }
    return Evaluator(context).evaluate(parseExpression(expression));
  }
}

const List<FormulaEntry> formulaLibrary = <FormulaEntry>[
  FormulaEntry(
    id: 'quadratic_plus',
    nameAr: 'حل المعادلة التربيعية (+الجذر)',
    nameEn: 'Quadratic formula (plus root)',
    category: 'الجبر',
    expression: '(-b + sqrt(b^2 - 4*a*c)) / (2*a)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'معامل x²'),
      FormulaVariable('b', 'معامل x'),
      FormulaVariable('c', 'الحد الثابت'),
    ],
    noteAr: 'الجذر التاني هو نفس التعبير بعلامة − قبل الجذر.',
  ),
  FormulaEntry(
    id: 'quadratic_minus',
    nameAr: 'حل المعادلة التربيعية (−الجذر)',
    nameEn: 'Quadratic formula (minus root)',
    category: 'الجبر',
    expression: '(-b - sqrt(b^2 - 4*a*c)) / (2*a)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'معامل x²'),
      FormulaVariable('b', 'معامل x'),
      FormulaVariable('c', 'الحد الثابت'),
    ],
  ),
  FormulaEntry(
    id: 'pythagoras',
    nameAr: 'نظرية فيثاغورس',
    nameEn: 'Pythagorean theorem',
    category: 'الهندسة',
    expression: 'sqrt(a^2 + b^2)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الضلع الأول'),
      FormulaVariable('b', 'الضلع الثاني'),
    ],
    noteAr: 'النتيجة طول الوتر.',
  ),
  FormulaEntry(
    id: 'distance',
    nameAr: 'المسافة بين نقطتين',
    nameEn: 'Distance between two points',
    category: 'الهندسة',
    expression: 'sqrt((c - a)^2 + (d - b)^2)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'x₁'),
      FormulaVariable('b', 'y₁'),
      FormulaVariable('c', 'x₂'),
      FormulaVariable('d', 'y₂'),
    ],
  ),
  FormulaEntry(
    id: 'slope',
    nameAr: 'ميل الخط المستقيم',
    nameEn: 'Slope',
    category: 'الهندسة',
    expression: '(d - b) / (c - a)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'x₁'),
      FormulaVariable('b', 'y₁'),
      FormulaVariable('c', 'x₂'),
      FormulaVariable('d', 'y₂'),
    ],
  ),
  FormulaEntry(
    id: 'circle_area',
    nameAr: 'مساحة الدائرة',
    nameEn: 'Area of a circle',
    category: 'الهندسة',
    expression: 'pi*r^2',
    variables: <FormulaVariable>[FormulaVariable('r', 'نصف القطر')],
  ),
  FormulaEntry(
    id: 'circle_circumference',
    nameAr: 'محيط الدائرة',
    nameEn: 'Circumference',
    category: 'الهندسة',
    expression: '2*pi*r',
    variables: <FormulaVariable>[FormulaVariable('r', 'نصف القطر')],
  ),
  FormulaEntry(
    id: 'sphere_volume',
    nameAr: 'حجم الكرة',
    nameEn: 'Volume of a sphere',
    category: 'الهندسة',
    expression: '(4/3)*pi*r^3',
    variables: <FormulaVariable>[FormulaVariable('r', 'نصف القطر')],
  ),
  FormulaEntry(
    id: 'cylinder_volume',
    nameAr: 'حجم الأسطوانة',
    nameEn: 'Volume of a cylinder',
    category: 'الهندسة',
    expression: 'pi*r^2*h',
    variables: <FormulaVariable>[
      FormulaVariable('r', 'نصف القطر'),
      FormulaVariable('h', 'الارتفاع'),
    ],
  ),
  FormulaEntry(
    id: 'cone_volume',
    nameAr: 'حجم المخروط',
    nameEn: 'Volume of a cone',
    category: 'الهندسة',
    expression: '(1/3)*pi*r^2*h',
    variables: <FormulaVariable>[
      FormulaVariable('r', 'نصف القطر'),
      FormulaVariable('h', 'الارتفاع'),
    ],
  ),
  FormulaEntry(
    id: 'triangle_area',
    nameAr: 'مساحة المثلث',
    nameEn: 'Area of a triangle',
    category: 'الهندسة',
    expression: '(1/2)*b*h',
    variables: <FormulaVariable>[
      FormulaVariable('b', 'القاعدة'),
      FormulaVariable('h', 'الارتفاع'),
    ],
  ),
  FormulaEntry(
    id: 'sine_rule',
    nameAr: 'قانون الجيوب',
    nameEn: 'Law of sines',
    category: 'حساب المثلثات',
    expression: 'a / sin(A)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الضلع a'),
      FormulaVariable('A', 'الزاوية A'),
    ],
    noteAr: 'النتيجة تساوي b/sin(B) وتساوي c/sin(C).',
  ),
  FormulaEntry(
    id: 'cosine_rule',
    nameAr: 'قانون الجيوب التمام',
    nameEn: 'Law of cosines',
    category: 'حساب المثلثات',
    expression: 'sqrt(a^2 + b^2 - 2*a*b*cos(C))',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الضلع a'),
      FormulaVariable('b', 'الضلع b'),
      FormulaVariable('C', 'الزاوية C'),
    ],
  ),
  FormulaEntry(
    id: 'trig_identity',
    nameAr: 'المتطابقة الفيثاغورسية',
    nameEn: 'Pythagorean identity',
    category: 'حساب المثلثات',
    expression: 'sin(theta)^2 + cos(theta)^2',
    variables: <FormulaVariable>[FormulaVariable('θ', 'الزاوية')],
    noteAr: 'النتيجة لازم تكون 1 لأي زاوية.',
  ),
  FormulaEntry(
    id: 'arithmetic_term',
    nameAr: 'الحد النوني في المتتابعة الحسابية',
    nameEn: 'Arithmetic sequence term',
    category: 'المتتابعات',
    expression: 'a + (n - 1)*d',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الحد الأول'),
      FormulaVariable('d', 'الفرق المشترك'),
      FormulaVariable('n', 'رقم الحد'),
    ],
  ),
  FormulaEntry(
    id: 'arithmetic_sum',
    nameAr: 'مجموع المتتابعة الحسابية',
    nameEn: 'Arithmetic series sum',
    category: 'المتتابعات',
    expression: '(n/2)*(2*a + (n - 1)*d)',
    variables: <FormulaVariable>[
      FormulaVariable('n', 'عدد الحدود'),
      FormulaVariable('a', 'الحد الأول'),
      FormulaVariable('d', 'الفرق المشترك'),
    ],
  ),
  FormulaEntry(
    id: 'geometric_term',
    nameAr: 'الحد النوني في المتتابعة الهندسية',
    nameEn: 'Geometric sequence term',
    category: 'المتتابعات',
    expression: 'a*r^(n - 1)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الحد الأول'),
      FormulaVariable('r', 'الأساس'),
      FormulaVariable('n', 'رقم الحد'),
    ],
  ),
  FormulaEntry(
    id: 'geometric_sum',
    nameAr: 'مجموع المتتابعة الهندسية',
    nameEn: 'Geometric series sum',
    category: 'المتتابعات',
    expression: 'a*(1 - r^n)/(1 - r)',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الحد الأول'),
      FormulaVariable('r', 'الأساس'),
      FormulaVariable('n', 'عدد الحدود'),
    ],
    noteAr: 'غير صالحة عندما r = 1.',
  ),
  FormulaEntry(
    id: 'compound_interest',
    nameAr: 'الفائدة المركبة',
    nameEn: 'Compound interest',
    category: 'المال',
    expression: 'P*(1 + r/n)^(n*t)',
    variables: <FormulaVariable>[
      FormulaVariable('P', 'المبلغ الأساسي'),
      FormulaVariable('r', 'سعر الفائدة العشري'),
      FormulaVariable('n', 'مرات التركيب سنويًا'),
      FormulaVariable('t', 'عدد السنوات'),
    ],
  ),
  FormulaEntry(
    id: 'simple_interest',
    nameAr: 'الفائدة البسيطة',
    nameEn: 'Simple interest',
    category: 'المال',
    expression: 'P*r*t',
    variables: <FormulaVariable>[
      FormulaVariable('P', 'المبلغ الأساسي'),
      FormulaVariable('r', 'سعر الفائدة العشري'),
      FormulaVariable('t', 'عدد السنوات'),
    ],
  ),
  FormulaEntry(
    id: 'percent_change',
    nameAr: 'نسبة التغير',
    nameEn: 'Percentage change',
    category: 'الحساب',
    expression: '((n - o)/o)*100',
    variables: <FormulaVariable>[
      FormulaVariable('o', 'القيمة القديمة'),
      FormulaVariable('n', 'القيمة الجديدة'),
    ],
  ),
  FormulaEntry(
    id: 'speed',
    nameAr: 'السرعة',
    nameEn: 'Speed',
    category: 'الفيزياء',
    expression: 'd/t',
    variables: <FormulaVariable>[
      FormulaVariable('d', 'المسافة', unit: 'm'),
      FormulaVariable('t', 'الزمن', unit: 's'),
    ],
  ),
  FormulaEntry(
    id: 'velocity',
    nameAr: 'السرعة النهائية',
    nameEn: 'Final velocity',
    category: 'الفيزياء',
    expression: 'u + a*t',
    variables: <FormulaVariable>[
      FormulaVariable('u', 'السرعة الابتدائية', unit: 'm/s'),
      FormulaVariable('a', 'التسارع', unit: 'm/s²'),
      FormulaVariable('t', 'الزمن', unit: 's'),
    ],
  ),
  FormulaEntry(
    id: 'displacement',
    nameAr: 'الإزاحة',
    nameEn: 'Displacement',
    category: 'الفيزياء',
    expression: 'u*t + (1/2)*a*t^2',
    variables: <FormulaVariable>[
      FormulaVariable('u', 'السرعة الابتدائية', unit: 'm/s'),
      FormulaVariable('t', 'الزمن', unit: 's'),
      FormulaVariable('a', 'التسارع', unit: 'm/s²'),
    ],
  ),
  FormulaEntry(
    id: 'velocity_squared',
    nameAr: 'معادلة الحركة الثالثة',
    nameEn: 'Third equation of motion',
    category: 'الفيزياء',
    expression: 'sqrt(u^2 + 2*a*s)',
    variables: <FormulaVariable>[
      FormulaVariable('u', 'السرعة الابتدائية', unit: 'm/s'),
      FormulaVariable('a', 'التسارع', unit: 'm/s²'),
      FormulaVariable('s', 'الإزاحة', unit: 'm'),
    ],
  ),
  FormulaEntry(
    id: 'newton_second',
    nameAr: 'قانون نيوتن الثاني',
    nameEn: "Newton's second law",
    category: 'الفيزياء',
    expression: 'm*a',
    variables: <FormulaVariable>[
      FormulaVariable('m', 'الكتلة', unit: 'kg'),
      FormulaVariable('a', 'التسارع', unit: 'm/s²'),
    ],
  ),
  FormulaEntry(
    id: 'kinetic_energy',
    nameAr: 'الطاقة الحركية',
    nameEn: 'Kinetic energy',
    category: 'الفيزياء',
    expression: '(1/2)*m*v^2',
    variables: <FormulaVariable>[
      FormulaVariable('m', 'الكتلة', unit: 'kg'),
      FormulaVariable('v', 'السرعة', unit: 'm/s'),
    ],
  ),
  FormulaEntry(
    id: 'potential_energy',
    nameAr: 'طاقة الوضع',
    nameEn: 'Potential energy',
    category: 'الفيزياء',
    expression: 'm*g*h',
    variables: <FormulaVariable>[
      FormulaVariable('m', 'الكتلة', unit: 'kg'),
      FormulaVariable('h', 'الارتفاع', unit: 'm'),
    ],
    constants: <String, double>{'g': 9.80665},
  ),
  FormulaEntry(
    id: 'density',
    nameAr: 'الكثافة',
    nameEn: 'Density',
    category: 'الفيزياء',
    expression: 'm/V',
    variables: <FormulaVariable>[
      FormulaVariable('m', 'الكتلة', unit: 'kg'),
      FormulaVariable('V', 'الحجم', unit: 'm³'),
    ],
  ),
  FormulaEntry(
    id: 'pressure',
    nameAr: 'الضغط',
    nameEn: 'Pressure',
    category: 'الفيزياء',
    expression: 'F/A',
    variables: <FormulaVariable>[
      FormulaVariable('F', 'القوة', unit: 'N'),
      FormulaVariable('A', 'المساحة', unit: 'm²'),
    ],
  ),
  FormulaEntry(
    id: 'ohms_law',
    nameAr: 'قانون أوم',
    nameEn: "Ohm's law",
    category: 'الفيزياء',
    expression: 'I*R',
    variables: <FormulaVariable>[
      FormulaVariable('I', 'شدة التيار', unit: 'A'),
      FormulaVariable('R', 'المقاومة', unit: 'Ω'),
    ],
    noteAr: 'النتيجة فرق الجهد بالفولت.',
  ),
  FormulaEntry(
    id: 'electric_power',
    nameAr: 'القدرة الكهربائية',
    nameEn: 'Electric power',
    category: 'الفيزياء',
    expression: 'V*I',
    variables: <FormulaVariable>[
      FormulaVariable('V', 'فرق الجهد', unit: 'V'),
      FormulaVariable('I', 'شدة التيار', unit: 'A'),
    ],
  ),
  FormulaEntry(
    id: 'wave_speed',
    nameAr: 'سرعة الموجة',
    nameEn: 'Wave speed',
    category: 'الفيزياء',
    expression: 'f*w',
    variables: <FormulaVariable>[
      FormulaVariable('f', 'التردد', unit: 'Hz'),
      FormulaVariable('w', 'الطول الموجي', unit: 'm'),
    ],
  ),
  FormulaEntry(
    id: 'gravity',
    nameAr: 'قوة الجذب العام',
    nameEn: 'Universal gravitation',
    category: 'الفيزياء',
    expression: 'G*a*b/r^2',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الكتلة الأولى', unit: 'kg'),
      FormulaVariable('b', 'الكتلة الثانية', unit: 'kg'),
      FormulaVariable('r', 'المسافة', unit: 'm'),
    ],
    constants: <String, double>{'G': 6.67430e-11},
  ),
  FormulaEntry(
    id: 'moles',
    nameAr: 'عدد المولات',
    nameEn: 'Number of moles',
    category: 'الكيمياء',
    expression: 'm/M',
    variables: <FormulaVariable>[
      FormulaVariable('m', 'الكتلة', unit: 'g'),
      FormulaVariable('M', 'الكتلة المولية', unit: 'g/mol'),
    ],
  ),
  FormulaEntry(
    id: 'concentration',
    nameAr: 'التركيز المولاري',
    nameEn: 'Molar concentration',
    category: 'الكيمياء',
    expression: 'n/V',
    variables: <FormulaVariable>[
      FormulaVariable('n', 'عدد المولات', unit: 'mol'),
      FormulaVariable('V', 'الحجم', unit: 'L'),
    ],
  ),
  FormulaEntry(
    id: 'ideal_gas',
    nameAr: 'قانون الغاز المثالي',
    nameEn: 'Ideal gas law',
    category: 'الكيمياء',
    expression: 'n*R*T/P',
    variables: <FormulaVariable>[
      FormulaVariable('P', 'الضغط', unit: 'atm'),
      FormulaVariable('n', 'عدد المولات', unit: 'mol'),
      FormulaVariable('T', 'درجة الحرارة المطلقة', unit: 'K'),
    ],
    constants: <String, double>{'R': 0.08205736608096},
    noteAr: 'النتيجة الحجم باللتر عندما يكون الضغط بوحدة atm.',
  ),
  FormulaEntry(
    id: 'dilution',
    nameAr: 'تخفيف المحلول',
    nameEn: 'Dilution',
    category: 'الكيمياء',
    expression: 'c*a/b',
    variables: <FormulaVariable>[
      FormulaVariable('c', 'التركيز الابتدائي'),
      FormulaVariable('a', 'الحجم الابتدائي'),
      FormulaVariable('b', 'الحجم النهائي'),
    ],
  ),
  FormulaEntry(
    id: 'percent_yield',
    nameAr: 'الناتج المئوي',
    nameEn: 'Percentage yield',
    category: 'الكيمياء',
    expression: '(a/t)*100',
    variables: <FormulaVariable>[
      FormulaVariable('a', 'الناتج الفعلي'),
      FormulaVariable('t', 'الناتج النظري'),
    ],
  ),
  FormulaEntry(
    id: 'bmi',
    nameAr: 'مؤشر كتلة الجسم',
    nameEn: 'Body mass index',
    category: 'الصحة',
    expression: 'm/h^2',
    variables: <FormulaVariable>[
      FormulaVariable('m', 'الكتلة', unit: 'kg'),
      FormulaVariable('h', 'الطول', unit: 'm'),
    ],
  ),
];

List<FormulaEntry> searchFormulas(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return formulaLibrary;
  return formulaLibrary.where((formula) {
    return formula.nameAr.contains(query.trim()) ||
        formula.nameEn.toLowerCase().contains(needle) ||
        formula.category.contains(query.trim()) ||
        formula.expression.toLowerCase().contains(needle) ||
        formula.id.contains(needle);
  }).toList(growable: false);
}

FormulaEntry? formulaById(String id) {
  for (final formula in formulaLibrary) {
    if (formula.id == id) return formula;
  }
  return null;
}
