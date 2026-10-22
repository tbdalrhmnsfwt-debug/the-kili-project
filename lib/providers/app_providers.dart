import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai_service.dart';
import '../core/api_client.dart';
import '../core/asset_service.dart';
import '../core/quiz_generator.dart';
import '../models/ai.dart';
import '../models/arena.dart';
import '../models/exam.dart';
import '../models/focus.dart';
import '../models/games.dart';
import '../models/leaderboard.dart';
import '../models/manhaji.dart';
import '../models/mistakes.dart';
import '../models/notebook.dart';
import '../models/planner.dart';
import '../models/recall.dart';
import '../models/schedule.dart';
import '../models/wallet.dart';
import '../models/weekly.dart';
import '../models/words.dart';

/// The API client.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// The bundled-asset loader.
final assetServiceProvider = Provider<AssetService>((ref) => AssetService());

/// The AI service backing the chat and the study tools.
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(api: ref.watch(apiClientProvider));
});

/// Which backend the AI service will use.
final aiBackendProvider = Provider<AiBackend>((ref) {
  return ref.watch(aiServiceProvider).backend;
});

/// All grade indexes, loaded once and cached.
final gradesProvider = FutureProvider<List<Grade>>((ref) async {
  return ref.watch(assetServiceProvider).loadAllGrades();
});

/// A single grade index.
final gradeProvider = FutureProvider.family<Grade, String>((ref, gradeId) {
  return ref.watch(assetServiceProvider).loadGrade(gradeId);
});

/// Books for a grade, filtered by subject when [subject] is non-null.
final booksProvider = FutureProvider.family<List<Book>, GradeFilter>((
  ref,
  filter,
) async {
  final grade = await ref.watch(gradeProvider(filter.gradeId).future);
  if (filter.subject == null) return grade.books;
  return grade.books.where((b) => b.subject == filter.subject).toList();
});

/// Filter for [booksProvider].
class GradeFilter {
  const GradeFilter(this.gradeId, [this.subject]);

  final String gradeId;
  final String? subject;

  @override
  bool operator ==(Object other) =>
      other is GradeFilter &&
      other.gradeId == gradeId &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(gradeId, subject);
}

/// The lessons of a book.
final lessonsProvider = FutureProvider.family<List<Lesson>, Book>((
  ref,
  book,
) async {
  final service = ref.watch(assetServiceProvider);
  final json = await service.loadBook(book);
  return service.parseLessons(json);
});

/// The currently selected grade.
final selectedGradeProvider = StateProvider<String>((ref) => 'sec1');

/// The currently selected subject within a grade.
final selectedSubjectProvider = StateProvider<String?>((ref) => null);

/// The exam session in progress, if any.
final examSessionProvider = StateProvider<ExamSession?>((ref) => null);

/// The questions shown by the quiz runner.
///
/// An explicit exam session wins. Otherwise the questions are derived from
/// the first readable book, preferring the selected grade and Arabic books,
/// so the quiz always reflects real textbook content when any is available.
final quizQuestionsProvider = FutureProvider<List<ExamQuestion>>((ref) async {
  final session = ref.watch(examSessionProvider);
  final sessionQuestions = session?.questions ?? const <ExamQuestion>[];
  if (sessionQuestions.isNotEmpty) return sessionQuestions;

  final service = ref.watch(assetServiceProvider);
  final grades = await ref.watch(gradesProvider.future);
  final preferredGrade = ref.watch(selectedGradeProvider);

  final orderedGrades = [
    ...grades.where((g) => g.id == preferredGrade),
    ...grades.where((g) => g.id != preferredGrade),
  ];

  for (final grade in orderedGrades) {
    final books = [
      ...grade.books.where((b) => b.lang == 'ar'),
      ...grade.books.where((b) => b.lang != 'ar'),
    ];
    for (final book in books) {
      try {
        final json = await service.loadBook(book);
        final lessons = service.parseLessons(json);
        final questions = generateClozeQuestions(
          book: book,
          lessons: lessons,
        );
        if (questions.isNotEmpty) return questions;
      } catch (_) {
        // Encrypted or unreadable book — move on to the next one.
      }
    }
  }

  return demoExamQuestions();
});

/// The user's task list.
final taskListProvider = StateProvider<TaskList>(
  (ref) => TaskList(title: 'قائمة المهام'),
);

/// The focus session in progress.
final focusSessionProvider = StateProvider<FocusSession?>((ref) => null);

/// The remote app settings.
final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.guard(
    () => api.fetchAppSettings(),
    fallback: const <String, dynamic>{},
  );
});

/// The active-recall card queue.
final reviewQueueProvider = StateProvider<ReviewQueue>((ref) => ReviewQueue());

/// The cards waiting for review right now.
final dueCardsProvider = Provider<List<RecallCard>>((ref) {
  return ref.watch(reviewQueueProvider).due();
});

/// The user's daily goals.
final goalsProvider = StateProvider<List<Goal>>((ref) => const []);

/// The achievements the user has unlocked.
final achievementsProvider = StateProvider<List<Achievement>>(
  (ref) => const [],
);

/// The user's referral record.
final referralProvider = StateProvider<Referral?>((ref) => null);

/// The AI outputs the user has saved ("مخرجاتي").
final aiOutputsProvider = StateProvider<List<AiOutput>>((ref) => const []);

/// The current chat thread.
final chatThreadProvider = StateProvider<ChatThread>((ref) {
  return ChatThread(
    id: 'chat-${DateTime.now().millisecondsSinceEpoch}',
    title: 'محادثة جديدة',
  );
});

/// The daily task list.
final taskScheduleProvider = StateProvider<TaskSchedule>(
  (ref) => TaskSchedule(title: 'قائمة المهام'),
);

/// The wallet: monthly allowance, commitments and expenses.
final walletProvider = StateProvider<Wallet>((ref) {
  final now = DateTime.now();
  return Wallet(month: '${now.year}-${now.month.toString().padLeft(2, '0')}');
});

/// The weekly leaderboard snapshot.
final leaderboardProvider = StateProvider<LeaderboardWeek>((ref) {
  final now = DateTime.now();
  return LeaderboardWeek(
    weekStart: now.subtract(Duration(days: now.weekday % 7)),
    rows: const <LeaderboardRow>[],
  );
});

/// The garden, which grows with each studied day.
final gardenProvider = StateProvider<Garden>((ref) => const Garden());

/// The mistakes notebook.
final mistakesProvider = StateProvider<MistakeNotebook>(
  (ref) => const MistakeNotebook(),
);

/// The per-subject notebooks.
final notebooksProvider = StateProvider<List<Notebook>>(
  (ref) => const <Notebook>[],
);

/// The user's English vocabulary lists.
final wordListsProvider = StateProvider<List<WordList>>(
  (ref) => const <WordList>[],
);

/// The challenges the user can play.
final challengesProvider = StateProvider<List<Challenge>>(
  (ref) => const <Challenge>[],
);

/// The results of the challenges the user has finished.
final challengeResultsProvider = StateProvider<List<ChallengeResult>>(
  (ref) => const <ChallengeResult>[],
);

/// The player's stars, coins and level in the study games.
final gameProfileProvider = StateProvider<GameProfile>((ref) {
  return const GameProfile();
});

/// The question banks the games draw their questions from.
final questionBanksProvider = StateProvider<List<QuestionBank>>(
  (ref) => const <QuestionBank>[],
);

/// The weekly report shown on the weekly screen and the home screen.
final weeklyReportProvider = StateProvider<WeeklyReport>((ref) {
  return WeeklyReport.forWeek(DateTime.now());
});
