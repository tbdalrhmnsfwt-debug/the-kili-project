/// Arabic copy for batch failures. Screens pass this through `TrText`.
library;

import '../../core/batches/batch_failure.dart';

String batchErrorText(BatchFailure failure) => switch (failure.code) {
      BatchFailureCode.invalidName =>
        'اسم الدفعة لازم يكون من حرفين لـ 60 حرف.',
      BatchFailureCode.invalidSubject => 'اسم المادة مش صح أو مكرر.',
      BatchFailureCode.invalidCode => 'الكود لازم يكون 8 أرقام.',
      BatchFailureCode.codeCooldown => 'حاولت كتير. استنى شوية وجرب تاني.',
      BatchFailureCode.codeNotFound => 'مفيش دفعة بالكود ده على الجهاز.',
      BatchFailureCode.codeRevoked => 'الكود ده اتلغى.',
      BatchFailureCode.alreadyMember => 'انت عضو في الدفعة دي بالفعل.',
      BatchFailureCode.pendingUnsupported =>
        'طلبات الانضمام محتاجة سيرفر ومش متاحة هنا.',
      BatchFailureCode.notAuthorized => 'مش مسموح لك تعمل الحركة دي.',
      BatchFailureCode.claimFailed => 'نقل الدفعات للحساب ما تمّش.',
      BatchFailureCode.missingFile => 'الملف الأصلي مش موجود.',
      BatchFailureCode.unsupportedFile => 'نوع الملف مش مدعوم.',
      BatchFailureCode.fileTooLarge => 'الملف أكبر من الحد المسموح.',
      BatchFailureCode.storageFull => 'مساحة التخزين على الجهاز خلصت.',
      BatchFailureCode.corruptStore => 'بيانات الدفعة اتلفت ومقدرناش نقراها.',
      BatchFailureCode.migrationUnsupported =>
        'الدفعة دي متخزنة بنسخة أحدث من التطبيق.',
      BatchFailureCode.permissionDenied =>
        'التطبيق مش عنده إذن الوصول المطلوب.',
      BatchFailureCode.ocrFailed => 'قراءة الصورة ما نجحتش.',
      BatchFailureCode.ocrLowConfidence => 'الصورة مش واضحة كفاية.',
      BatchFailureCode.extractionFailed => 'استخراج النص من الملف فشل.',
      BatchFailureCode.encryptedSource =>
        'الملف محمي بكلمة سر — أدوات الدراسة مش متاحة',
      BatchFailureCode.tooManyPages =>
        'الملف فيه صفحات أكتر من الحد المسموح لأدوات الدراسة.',
      BatchFailureCode.examNotOpen => 'الامتحان لسه مفتحش.',
      BatchFailureCode.examClosed => 'الامتحان اتقفل.',
      BatchFailureCode.examWindowInvalid => 'ميعاد الامتحان مش صح.',
      BatchFailureCode.transcriptionUnavailable =>
        'تفريغ الصوت محتاج موديل على الجهاز مش متاح في النسخة دي.',
      BatchFailureCode.remoteRequired => 'الحركة دي محتاجة سيرفر ومش متاحة.',
      BatchFailureCode.cancelled => 'العملية اتلغت.',
      BatchFailureCode.validationFailed => 'في بيانات مش صح.',
      BatchFailureCode.notFound => 'مفيش حاجة بالمعرّف ده.',
      BatchFailureCode.conflict => 'حصل تعارض. جرّب تاني.',
    };

/// A one-line explanation for a blocked capability.
String blockedCapabilityText(
  BlockedCapability capability,
) =>
    switch (capability) {
      BlockedCapability.crossDeviceJoin =>
        'الانضمام من جهاز تاني محتاج سيرفر. الكود بيشتغل على الجهاز ده بس.',
      BlockedCapability.joinApproval => 'قبول طلبات الانضمام محتاج سيرفر.',
      BlockedCapability.memberManagement =>
        'إدارة الأعضاء التانيين محتاجة سيرفر.',
      BlockedCapability.moderation => 'الإبلاغ والحظر محتاجين سيرفر.',
      BlockedCapability.realtimeDelivery =>
        'توصيل الرسائل لحظيًا للأعضاء التانيين محتاج سيرفر.',
      BlockedCapability.pushNotifications =>
        'الإشعارات الفورية للأعضاء التانيين محتاجة سيرفر.',
      BlockedCapability.remoteStorage => 'رفع الملفات لمخزن سحابي محتاج سيرفر.',
      BlockedCapability.liveChallenge => 'التحدي المباشر محتاج سيرفر.',
      BlockedCapability.crossMemberRanking =>
        'الترتيب بين الأعضاء محتاج سيرفر.',
      BlockedCapability.serverTime => 'وقت السيرفر المرجعي مش متاح.',
      BlockedCapability.transcription =>
        'تفريغ الصوت محتاج موديل على الجهاز مش متاح في النسخة دي.',
      BlockedCapability.remoteAi =>
        'أدوات الذكاء الاصطناعي السحابية محتاجة سيرفر ومفتاح محفوظ.',
    };
