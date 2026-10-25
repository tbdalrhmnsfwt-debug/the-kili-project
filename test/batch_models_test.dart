import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_chat.dart';
import 'package:zaker_ai/models/batch_exam.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/models/batch_schedule.dart';
import 'package:zaker_ai/models/batch_update.dart';
import 'package:zaker_ai/models/exam.dart';

Map<String, dynamic> _roundTrip(Map<String, dynamic> json) {
  return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}

final DateTime _at = DateTime.utc(2026, 10, 25, 9, 30);

void main() {
  group('Batch family', () {
    test('round-trips settings, subjects, code and membership', () {
      final batch = Batch(
        id: 'batch-1',
        name: 'دفعة تالتة ثانوي',
        ownerUid: 'uid-1',
        createdAt: _at,
        settings: const BatchSettings(
          uploadsAdminOnly: false,
          requireApproval: false,
          allowMemberReminders: false,
          notificationDetail: BatchNotificationDetail.titled,
        ),
        subjects: [
          BatchSubject(id: 'sub-1', name: 'رياضيات', order: 0, createdAt: _at),
          BatchSubject(id: 'sub-2', name: 'فيزياء', order: 1, createdAt: _at),
        ],
        codeState: InviteCodeState(
          code: '01234567',
          createdAt: _at,
          rotatedAt: _at.add(const Duration(minutes: 1)),
          rotationCount: 2,
        ),
        lastActivityAt: _at.add(const Duration(hours: 1)),
      );
      final restored = Batch.fromJson(_roundTrip(batch.toJson()));

      expect(restored.id, batch.id);
      expect(restored.name, batch.name);
      expect(restored.ownerUid, batch.ownerUid);
      expect(restored.settings.uploadsAdminOnly, isFalse);
      expect(restored.settings.requireApproval, isFalse);
      expect(restored.settings.allowMemberReminders, isFalse);
      expect(
        restored.settings.notificationDetail,
        BatchNotificationDetail.titled,
      );
      expect(restored.subjects.map((s) => s.name), ['رياضيات', 'فيزياء']);
      // The leading zero survives a round trip; the code is not an integer.
      expect(restored.codeState.code, '01234567');
      expect(restored.codeState.isActive, isTrue);
      expect(restored.codeState.rotationCount, 2);
      expect(restored.lastActivityAt, batch.lastActivityAt);
    });

    test('a revoked code is inactive and round-trips', () {
      final state = InviteCodeState(
        code: '00000042',
        createdAt: _at,
        revokedAt: _at,
      );
      final restored = InviteCodeState.fromJson(_roundTrip(state.toJson()));
      expect(restored.code, '00000042');
      expect(restored.isActive, isFalse);
    });

    test('membership and audit entries round-trip', () {
      final membership = Membership(
        batchId: 'batch-1',
        uid: 'uid-1',
        displayName: 'طالب',
        role: BatchRole.admin,
        joinedAt: _at,
      );
      final member = Membership.fromJson(_roundTrip(membership.toJson()));
      expect(member.role, BatchRole.admin);
      expect(member.joinedAt, _at);

      final audit = AuditEntry(
        id: 'a1',
        batchId: 'batch-1',
        actorUid: 'uid-1',
        action: 'codeRotated',
        at: _at,
      );
      final restored = AuditEntry.fromJson(_roundTrip(audit.toJson()));
      expect(restored.action, 'codeRotated');
      expect(restored.detail, isEmpty);
    });
  });

  group('BatchResource', () {
    test('round-trips a PDF with a week label and stars', () {
      final resource = BatchResource(
        id: 'r1',
        batchId: 'batch-1',
        subjectId: 'sub-1',
        weekDay: const WeekDay(week: 2, day: 3),
        kind: ResourceKind.pdf,
        title: 'ملزمة',
        fileName: 'r1.pdf',
        mime: 'application/pdf',
        sizeBytes: 1234,
        uploaderUid: 'uid-1',
        createdAt: _at,
        starredBy: {'uid-1'},
        sha256: 'abc',
        processingState: ResourceProcessingState.ready,
      );
      final restored = BatchResource.fromJson(_roundTrip(resource.toJson()));
      expect(restored.kind, ResourceKind.pdf);
      expect(restored.subjectId, 'sub-1');
      expect(restored.weekDay, const WeekDay(week: 2, day: 3));
      expect(restored.starredBy, {'uid-1'});
      expect(restored.processingState, ResourceProcessingState.ready);
      expect(restored.transcriptionState, TranscriptionState.unavailable);
      expect(restored.sizeBytes, 1234);
    });

    test('a note keeps its body', () {
      final note = BatchResource(
        id: 'n1',
        batchId: 'b',
        subjectId: 's',
        kind: ResourceKind.note,
        title: 'ملاحظة',
        uploaderUid: 'u',
        createdAt: _at,
        note: 'نص الملاحظة',
      );
      expect(note.note, 'نص الملاحظة');
    });
  });

  group('ChatMessage', () {
    test('round-trips reactions as uid sets without duplicates', () {
      final message = ChatMessage(
        id: 'm1',
        batchId: 'batch-1',
        channelId: 'main',
        authorUid: 'uid-1',
        authorName: 'طالب',
        kind: ChatMessageKind.text,
        text: 'السلام عليكم',
        createdAt: _at,
        replyToId: 'm0',
        reactions: const {
          '👍': {'uid-1', 'uid-2'},
          '❤️': {'uid-2'},
        },
        pinned: true,
        clientKey: 'client-1',
      );
      final restored = ChatMessage.fromJson(_roundTrip(message.toJson()));
      expect(restored.text, 'السلام عليكم');
      expect(restored.replyToId, 'm0');
      expect(restored.reactions['👍'], containsAll(['uid-1', 'uid-2']));
      expect(restored.reactions['👍']!.length, 2);
      expect(restored.pinned, isTrue);
      expect(restored.clientKey, 'client-1');
      expect(restored.isDeleted, isFalse);
    });
  });

  group('Timetable', () {
    test('round-trips a weekly entry and its uncertainty', () {
      final draft = TimetableDraft(
        id: 'd1',
        batchId: 'batch-1',
        sourceImageFileName: 'schedules/d1-source.jpg',
        createdAt: _at,
        updatedAt: _at,
        entries: [
          TimetableEntry(
            id: 'e1',
            dayOfWeek: 3,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60 + 30,
            title: 'رياضيات',
            subjectId: 'sub-1',
            room: 'قاعة 4',
            confidence: 0.62,
            uncertainFields: const ['dayOfWeek', 'startMinutes'],
            recurrence: TimetableRecurrence.weekly,
            weekAnchorDate: DateTime.utc(2026, 10, 25),
            timeZoneId: 'Africa/Cairo',
            reminderEnabled: true,
          ),
        ],
        warnings: const ['الصورة فيها سطرين متداخلين'],
      );
      final restored = TimetableDraft.fromJson(_roundTrip(draft.toJson()));
      expect(restored.status, TimetableDraftStatus.draft);
      expect(restored.entries.single.dayOfWeek, 3);
      expect(restored.entries.single.startMinutes, 480);
      expect(restored.entries.single.uncertainFields, [
        'dayOfWeek',
        'startMinutes',
      ]);
      expect(restored.entries.single.recurrence, TimetableRecurrence.weekly);
      expect(restored.entries.single.hasTimeBasis, isTrue);
      expect(restored.entries.single.isComplete, isTrue);
      expect(restored.warnings.single, contains('سطرين'));
    });

    test('an entry without a time basis is not reminder-ready', () {
      const entry = TimetableEntry(
        id: 'e2',
        dayOfWeek: 1,
        startMinutes: 540,
        endMinutes: 600,
        title: 'لغة عربية',
      );
      expect(entry.isComplete, isTrue);
      expect(entry.hasTimeBasis, isFalse);
      expect(
        entry.copyWith(recurrence: TimetableRecurrence.weekly).hasTimeBasis,
        isFalse,
      );
    });
  });

  group('BatchUpdate', () {
    test('round-trips read state per uid', () {
      final update = BatchUpdate(
        id: 'u1',
        batchId: 'batch-1',
        authorUid: 'uid-1',
        authorName: 'المسؤول',
        title: 'امتحان بكرة',
        body: 'الامتحان الساعة 9',
        createdAt: _at,
        kind: BatchUpdateKind.announcement,
        pinned: true,
        readBy: const {'uid-2'},
      );
      final restored = BatchUpdate.fromJson(_roundTrip(update.toJson()));
      expect(restored.title, 'امتحان بكرة');
      expect(restored.isReadBy('uid-2'), isTrue);
      expect(restored.isReadBy('uid-1'), isFalse);
      expect(restored.kind, BatchUpdateKind.announcement);
      expect(restored.pinned, isTrue);
    });
  });

  group('BatchExam and attempts', () {
    BatchExam exam({
      DateTime? opensAt,
      DateTime? closesAt,
      BatchExamResultsMode mode = BatchExamResultsMode.afterClose,
    }) =>
        BatchExam(
          id: 'exam-1',
          batchId: 'batch-1',
          subjectId: 'sub-1',
          title: 'امتحان الوحدة',
          durationMinutes: 30,
          questions: const [
            ExamQuestion(
              id: 'q1',
              prompt: '2 + 2 = ؟',
              answerKind: AnswerKind.multipleChoice,
              options: ['3', '4', '5'],
              correctIndex: 1,
            ),
          ],
          createdBy: 'uid-1',
          createdAt: _at,
          updatedAt: _at,
          opensAt: opensAt,
          closesAt: closesAt,
          publishedAt: _at,
          resultsMode: mode,
        );

    test('round-trips questions and the window', () {
      final source = exam(
        opensAt: _at.add(const Duration(hours: 1)),
        closesAt: _at.add(const Duration(hours: 3)),
      );
      final restored = BatchExam.fromJson(_roundTrip(source.toJson()));
      expect(restored.questions.single.correctIndex, 1);
      expect(restored.questions.single.options, ['3', '4', '5']);
      expect(restored.opensAt, source.opensAt);
      expect(restored.closesAt, source.closesAt);
      expect(restored.statusAt(_at), BatchExamStatus.scheduled);
      expect(
        restored.statusAt(_at.add(const Duration(hours: 2))),
        BatchExamStatus.open,
      );
      expect(
        restored.statusAt(_at.add(const Duration(hours: 4))),
        BatchExamStatus.closed,
      );
    });

    test('afterClose without a close time is invalid', () {
      final source = exam(closesAt: null);
      expect(source.hasValidWindow, isFalse);
      expect(
        source.statusAt(_at.add(const Duration(days: 1))),
        BatchExamStatus.draft,
      );
    });

    test('the attempt deadline is capped by the close time', () {
      final source = exam(closesAt: _at.add(const Duration(minutes: 10)));
      expect(source.deadlineFor(_at), _at.add(const Duration(minutes: 10)));
      final noCap = exam(closesAt: _at.add(const Duration(hours: 2)));
      expect(noCap.deadlineFor(_at), _at.add(const Duration(minutes: 30)));
    });

    test('attempt answers and score round-trip', () {
      final attempt = ExamAttempt(
        id: 'at1',
        examId: 'exam-1',
        batchId: 'batch-1',
        uid: 'uid-1',
        startedAt: _at,
        deadlineAt: _at.add(const Duration(minutes: 30)),
        submittedAt: _at.add(const Duration(minutes: 20)),
        answers: const {'q1': 1},
        correctCount: 1,
        total: 1,
        scorePercent: 100,
      );
      final restored = ExamAttempt.fromJson(_roundTrip(attempt.toJson()));
      expect(restored.answers['q1'], 1);
      expect(restored.isSubmitted, isTrue);
      expect(restored.scorePercent, 100);
      expect(restored.isExpired(_at.add(const Duration(minutes: 20))), isFalse);
      expect(restored.isExpired(_at.add(const Duration(minutes: 31))), isTrue);
    });
  });

  group('OcrDocument', () {
    test('round-trips words with boxes', () {
      const doc = OcrDocument(
        width: 1000,
        height: 700,
        lines: [
          OcrLine(
            id: 'l1',
            words: [
              OcrWord(
                text: 'الأحد',
                left: 10,
                top: 20,
                right: 60,
                bottom: 40,
                confidence: 88,
                lineId: 'l1',
              ),
            ],
          ),
        ],
      );
      final restored = OcrDocument.fromJson(_roundTrip(doc.toJson()));
      expect(restored.lines.single.text, 'الأحد');
      expect(restored.words.single.confidence, 88);
      expect(restored.words.single.centerX, 35);
    });
  });
}
