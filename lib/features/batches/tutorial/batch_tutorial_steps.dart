/// The local tours: a full 13-step walkthrough and a 7-step start.
///
/// Steps are plain data. The overlay presents them as cards; a step whose
/// screen is reachable opens it on request, and steps that need a batch pause
/// when none is available instead of pointing at another batch.
library;

/// Which tour is running.
enum BatchTutorialMode { gettingStarted, full }

/// The destination a step can open, when that screen exists.
enum BatchTutorialTarget {
  none,
  batches,
  createBatch,
  joinBatch,
  hub,
  subjects,
  schedules,
  updates,
  exams,
  admin,
}

class BatchTutorialStep {
  const BatchTutorialStep({
    required this.number,
    required this.target,
    required this.title,
    required this.body,
  });

  final int number;
  final BatchTutorialTarget target;
  final String title;
  final String body;
}

/// The getting-started tour stops before anything needs a batch.
const int gettingStartedStepCount = 7;

const List<BatchTutorialStep> fullTutorialSteps = [
  BatchTutorialStep(
    number: 1,
    target: BatchTutorialTarget.batches,
    title: 'تبويب الدفعات',
    body: 'من هنا بتشوف دفعاتك. كل الدفعات وملفاتها متخزنة على الجهاز ده، '
        'ومفيش مزامنة مع أجهزة تانية.',
  ),
  BatchTutorialStep(
    number: 2,
    target: BatchTutorialTarget.createBatch,
    title: 'إنشاء دفعة',
    body: 'اضغط «دفعة جديدة» واكتب اسم واضح للدفعة. الاسم والمواد هما أول '
        'خطوتين في الإنشاء.',
  ),
  BatchTutorialStep(
    number: 3,
    target: BatchTutorialTarget.createBatch,
    title: 'الاسم والمواد',
    body: 'ضيف المواد اللي بتدرّسها. تقدر تسيبها فاضية وتضيفها بعدين من '
        'داخل الدفعة.',
  ),
  BatchTutorialStep(
    number: 4,
    target: BatchTutorialTarget.createBatch,
    title: 'صلاحيات الرفع والانضمام',
    body: 'اختار مين يقدر يرفع ملفات، وهل الانضمام محتاج موافقة. الموافقة '
        'بين الأجهزة محتاجة سيرفر، والاختيار هنا بيتحفظ للمستقبل.',
  ),
  BatchTutorialStep(
    number: 5,
    target: BatchTutorialTarget.createBatch,
    title: 'المراجعة',
    body: 'راجع الاسم والمواد والصلاحيات قبل الإنشاء. الإنشاء بيحفظ الدفعة '
        'على الجهاز وبيولّد كود دعوة.',
  ),
  BatchTutorialStep(
    number: 6,
    target: BatchTutorialTarget.hub,
    title: 'كود الدعوة',
    body: 'الكود بيلاقي الدفعة على الجهاز ده بس. هو invitation mechanism '
        'مش تسجيل دخول، ومش بيشتغل على جهاز تاني.',
  ),
  BatchTutorialStep(
    number: 7,
    target: BatchTutorialTarget.joinBatch,
    title: 'الدخول بكود',
    body: 'لو عندك كود على الجهاز ده، اكتبه في شاشة الدخول. كود جهاز تاني '
        'مش هيتلاقى محليًا، والبحث بين الأجهزة محتاج سيرفر. بعد ما تعمل '
        'دفعة، كمّل الجولة من شاشة الإنشاء.',
  ),
  BatchTutorialStep(
    number: 8,
    target: BatchTutorialTarget.hub,
    title: 'هيدر الدفعة',
    body: 'ده هيدر الدفعة: الاسم والدور والكود لصاحب الدفعة. العدد مكتوب '
        'بصدق إنك لوحدك على الجهاز.',
  ),
  BatchTutorialStep(
    number: 9,
    target: BatchTutorialTarget.subjects,
    title: 'المواد',
    body: 'المواد فيها الملفات والملاحظات. الملفات بتتنسخ لمساحة خاصة '
        'بالدفعة، والأصل مش بيتغير.',
  ),
  BatchTutorialStep(
    number: 10,
    target: BatchTutorialTarget.schedules,
    title: 'المواعيد',
    body: 'المواعيد بتتخزن على الجهاز، والتذكيرات بتتجدول على الجهاز ده. '
        'مفيش مواعيد بتتخمّن من صورة.',
  ),
  BatchTutorialStep(
    number: 11,
    target: BatchTutorialTarget.updates,
    title: 'المستجدات',
    body: 'المستجدات إعلانات من صاحب الدفعة أو المسؤول. إشعار باقي الأعضاء '
        'محتاج سيرفر.',
  ),
  BatchTutorialStep(
    number: 12,
    target: BatchTutorialTarget.exams,
    title: 'الامتحانات',
    body: 'الامتحانات بتتصحح على الجهاز، والوقت من ساعة الجهاز. الترتيب '
        'المباشر والتحدي محتاجين سيرفر.',
  ),
  BatchTutorialStep(
    number: 13,
    target: BatchTutorialTarget.admin,
    title: 'الإدارة والمساعدة',
    body: 'الإدارة فيها الكود والإعدادات والسجل المحلي. تقدر تعيد الجولة من '
        'أيقونة المساعدة في أي وقت.',
  ),
];

List<BatchTutorialStep> tutorialStepsFor(BatchTutorialMode mode) {
  if (mode == BatchTutorialMode.full) return fullTutorialSteps;
  return fullTutorialSteps.take(gettingStartedStepCount).toList();
}

/// The batch-less steps 1–7, used when no batch exists yet.
List<BatchTutorialStep> gettingStartedSteps() =>
    tutorialStepsFor(BatchTutorialMode.gettingStarted);
