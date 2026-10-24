import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ai_service.dart';
import '../core/api_client.dart';
import '../core/asset_service.dart';
import '../core/auth_service.dart';
import '../core/curriculum_search.dart';
import '../core/live_service.dart';
import '../core/local_store.dart';
import '../core/notification_service.dart';
import '../core/quiz_generator.dart';
import '../models/ai.dart';
import '../models/arena.dart';
import '../models/exam.dart';
import '../models/focus.dart';
import '../models/games.dart';
import '../models/leaderboard.dart';
import '../models/manhaji.dart';
import '../models/mistakes.dart';
import '../models/official_book.dart';
import '../models/notebook.dart';
import '../models/planner.dart';
import '../models/recall.dart';
import '../models/schedule.dart';
import '../models/study_stats.dart';
import '../models/wallet.dart';
import '../models/weekly.dart';
import '../models/words.dart';

/// The API client.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// The bundled-asset loader.
final assetServiceProvider = Provider<AssetService>((ref) => AssetService());

/// The on-device store holding the user's study data.
///
/// `main` overrides this with an opened [LocalStore]; the default keeps
/// everything in memory so tests and previews run without a platform channel.
final localStoreProvider = Provider<LocalStore>((ref) => LocalStore.memory());

/// The interface language. Arabic is the source language and the default;
/// English is rendered from `assets/i18n/en.json` plus the replica's extra
/// translations.
final localeProvider = StateProvider<Locale>((ref) {
  final stored = ref.watch(localStoreProvider).getString('locale');
  return Locale(stored == 'en' ? 'en' : 'ar');
});

/// Accounts and the Firebase token.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(api: ref.watch(apiClientProvider));
});

/// Restores the saved profile, or creates the local guest identity once.
final authBootstrapProvider = Provider<AuthUser>((ref) {
  final store = ref.watch(localStoreProvider);
  final service = ref.watch(authServiceProvider);

  AuthUser? user;
  final raw = store.getString('auth_user');
  if (raw != null && raw.isNotEmpty) {
    try {
      user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('auth: ignoring a corrupt profile ($e)');
    }
  }
  if (user == null || user.uid.isEmpty) {
    user = AuthUser(uid: newGuestUid());
    store.setString('auth_user', jsonEncode(user.toJson()));
  }
  if (user.isAnonymous) {
    service.startGuest(uid: user.uid, displayName: user.displayName);
  }
  return user;
});

/// The account currently in use (guest until the user signs in).
final authUserProvider = StateProvider<AuthUser?>((ref) {
  return ref.watch(authBootstrapProvider);
});

/// Whether the app may read and write the shared live backend.
///
/// Off by default: the replica never contacts the vendor's Realtime Database
/// until the user explicitly turns the live features on.
final liveEnabledProvider = StateProvider<bool>((ref) {
  return _restoreBool(ref, 'live_enabled', false);
});

/// The Realtime Database URL used for live sync.
final liveDatabaseUrlProvider = StateProvider<String>((ref) {
  final stored = ref.watch(localStoreProvider).getString('live_url');
  return stored == null || stored.isEmpty ? kFirebaseRtdbUrl : stored;
});

/// The connection settings derived from the account and the settings.
final liveConfigProvider = Provider<LiveConfig>((ref) {
  final user = ref.watch(authUserProvider);
  return LiveConfig(
    enabled: ref.watch(liveEnabledProvider),
    databaseUrl: ref.watch(liveDatabaseUrlProvider),
    idToken: user?.idToken,
  );
});

/// REST client for the live leaderboard and challenges.
final liveServiceProvider = Provider<LiveService>((ref) {
  return LiveService(ref.watch(apiClientProvider));
});

/// Reads and decodes a persisted value, falling back when it is missing or
/// corrupt.
T _restore<T>(Ref ref, String key, T Function(String raw) decode, T fallback) {
  final raw = ref.watch(localStoreProvider).getString(key);
  if (raw == null) return fallback;
  try {
    return decode(raw);
  } catch (e) {
    debugPrint('local_store: ignoring $key ($e)');
    return fallback;
  }
}

/// Reads a persisted boolean, accepting both real booleans and the `1`/`0`
/// strings written by earlier versions of the app.
bool _restoreBool(Ref ref, String key, bool fallback) {
  final store = ref.watch(localStoreProvider);
  try {
    final value = store.getBool(key);
    if (value != null) return value;
  } catch (e) {
    debugPrint('local_store: ignoring non-boolean $key ($e)');
  }
  final raw = store.getString(key);
  if (raw == null) return fallback;
  return raw == '1' || raw.toLowerCase() == 'true';
}

/// Offline search over the readable bundled textbooks.
final curriculumSearchProvider = Provider<CurriculumSearch>((ref) {
  return CurriculumSearch(ref.watch(assetServiceProvider));
});

/// The AI service backing the chat and the study tools.
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(
    api: ref.watch(apiClientProvider),
    knowledge: ref.watch(curriculumSearchProvider),
  );
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

/// Optional links to the official textbook editions.
final officialBooksProvider = FutureProvider<OfficialBookCatalog>((ref) async {
  return ref.watch(assetServiceProvider).loadOfficialBooks();
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
final selectedGradeProvider = StateProvider<String>((ref) {
  return ref.watch(localStoreProvider).getString('selected_grade') ?? 'sec1';
});

/// The currently selected subject within a grade.
final selectedSubjectProvider = StateProvider<String?>((ref) => null);

/// Lessons the student marked as read, keyed `gradeId/bookId/lessonNumber`.
final readLessonsProvider = StateProvider<Set<String>>((ref) {
  return _restore(ref, 'read_lessons', _decodeReadLessons, const <String>{});
});

Set<String> _decodeReadLessons(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) throw const FormatException('not a list');
  return decoded.map((value) => '$value').toSet();
}

String _encodeReadLessons(Set<String> value) => jsonEncode(value.toList());

/// Whether study reminders are enabled in settings.
final notificationsEnabledProvider = StateProvider<bool>((ref) {
  return _restoreBool(ref, 'notifications', true);
});

/// The hour of the daily study reminder (24-hour clock).
final reminderHourProvider = StateProvider<int>((ref) {
  final raw = ref.watch(localStoreProvider).getString('reminder_hour');
  return (int.tryParse(raw ?? '') ?? 19).clamp(0, 23);
});

/// The minute of the daily study reminder.
final reminderMinuteProvider = StateProvider<int>((ref) {
  final raw = ref.watch(localStoreProvider).getString('reminder_minute');
  return (int.tryParse(raw ?? '') ?? 0).clamp(0, 59);
});

/// Whether feedback sounds and clicks are enabled in settings.
final soundsEnabledProvider = StateProvider<bool>((ref) {
  return _restoreBool(ref, 'sounds', true);
});

/// The exam session in progress, if any.
final examSessionProvider = StateProvider<ExamSession?>((ref) => null);

/// The challenge the quiz was opened for, when it was opened from the
/// challenges screen. The quiz records the real result against it.
final activeChallengeProvider = StateProvider<Challenge?>((ref) => null);

/// Seconds allowed for the current quiz run, or `null` for no limit.
final quizTimeLimitProvider = StateProvider<int?>((ref) => null);

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
        final questions = generateClozeQuestions(book: book, lessons: lessons);
        if (questions.isNotEmpty) return questions;
      } catch (_) {
        // Encrypted or unreadable book — move on to the next one.
      }
    }
  }

  return demoExamQuestions();
});

/// The user's task list.
final taskListProvider = StateProvider<TaskList>((ref) {
  return _restore(
    ref,
    'tasks',
    decodeTaskList,
    TaskList(title: 'قائمة المهام'),
  );
});

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
final reviewQueueProvider = StateProvider<ReviewQueue>((ref) {
  return _restore(ref, 'recall', decodeReviewQueue, ReviewQueue());
});

/// The cards waiting for review right now.
final dueCardsProvider = Provider<List<RecallCard>>((ref) {
  return ref.watch(reviewQueueProvider).due();
});

/// The user's daily goals.
final goalsProvider = StateProvider<List<Goal>>((ref) {
  return _restore(ref, 'goals', decodeGoals, const <Goal>[]);
});

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
final taskScheduleProvider = StateProvider<TaskSchedule>((ref) {
  return _restore(
    ref,
    'schedule',
    decodeTaskSchedule,
    TaskSchedule(title: 'قائمة المهام'),
  );
});

/// The wallet: monthly allowance, commitments and expenses.
final walletProvider = StateProvider<Wallet>((ref) {
  final now = DateTime.now();
  return _restore(
    ref,
    'wallet',
    decodeWallet,
    Wallet(month: '${now.year}-${now.month.toString().padLeft(2, '0')}'),
  );
});

/// The weekly leaderboard snapshot.
///
/// The player's own row is always derived locally from real activity: focus
/// minutes this week, points and solved challenges, and the study streak.
/// Server rows are merged by [liveLeaderboardProvider] when live sync is on.
final leaderboardProvider = StateProvider<LeaderboardWeek>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: (today.weekday + 1) % 7));
  final stats = ref.watch(studyStatsProvider);
  final results = ref.watch(challengeResultsProvider);
  final user = ref.watch(authUserProvider);

  var focusSeconds = 0;
  for (var i = 0; i < 7; i++) {
    focusSeconds += stats.minutesOn(start.add(Duration(days: i))) * 60;
  }
  final weekResults = results
      .where((r) {
        final at = r.finishedAt;
        return at != null && !at.isBefore(start);
      })
      .toList(growable: false);
  final points = weekResults.fold<int>(0, (sum, r) => sum + r.score);

  final rows = <LeaderboardRow>[];
  if (user != null) {
    rows.add(
      LeaderboardRow(
        userId: user.uid,
        displayName: user.displayName,
        points: points,
        focusSeconds: focusSeconds,
        solved: weekResults.length,
        streak: stats.streakDays,
        isMe: true,
      ),
    );
  }
  return LeaderboardWeek(weekStart: start, rows: rows);
});

/// Rows published by the shared backend, or an empty list when live sync is
/// off, the account is a guest, or the network is unavailable.
final liveLeaderboardProvider = FutureProvider<List<LeaderboardRow>>((
  ref,
) async {
  final config = ref.watch(liveConfigProvider);
  if (!LiveService.canSync(config)) return const <LeaderboardRow>[];
  final week = ref.watch(leaderboardProvider).weekStart;
  final uid = ref.watch(authUserProvider)?.uid;
  final rows = await ref
      .watch(liveServiceProvider)
      .fetchLeaderboard(week, config, myUid: uid);
  return rows ?? const <LeaderboardRow>[];
});

/// The garden, which grows with each studied day.
final gardenProvider = StateProvider<Garden>((ref) {
  return _restore(ref, 'garden', decodeGarden, const Garden());
});

/// The mistakes notebook.
final mistakesProvider = StateProvider<MistakeNotebook>((ref) {
  return _restore(
    ref,
    'mistakes',
    decodeMistakeNotebook,
    const MistakeNotebook(),
  );
});

/// The per-subject notebooks.
final notebooksProvider = StateProvider<List<Notebook>>((ref) {
  return _restore(ref, 'notebooks', decodeNotebooks, const <Notebook>[]);
});

/// The user's English vocabulary lists.
final wordListsProvider = StateProvider<List<WordList>>((ref) {
  return _restore(ref, 'word_lists', decodeWordLists, const <WordList>[]);
});

/// The challenges the user can play.
///
/// The daily challenge is always available locally. Live direct challenges
/// are added by [liveChallengesProvider] when sync is enabled.
final challengesProvider = StateProvider<List<Challenge>>((ref) {
  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day);
  final key =
      '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return [
    Challenge(
      id: 'daily-$key',
      title: 'تحدي النهارده',
      kind: ChallengeKind.daily,
      questionCount: 10,
      points: 8,
      createdAt: date,
    ),
  ];
});

/// Direct challenges shared by other players, when live sync is enabled.
final liveChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  final config = ref.watch(liveConfigProvider);
  if (!LiveService.canSync(config)) return const <Challenge>[];
  final challenges = await ref
      .watch(liveServiceProvider)
      .fetchChallenges(config);
  return challenges ?? const <Challenge>[];
});

/// The results of the challenges the user has finished.
final challengeResultsProvider = StateProvider<List<ChallengeResult>>((ref) {
  return _restore(
    ref,
    'challenge_results',
    decodeChallengeResults,
    const <ChallengeResult>[],
  );
});

/// The player's stars, coins and level in the study games.
final gameProfileProvider = StateProvider<GameProfile>((ref) {
  return _restore(ref, 'game_profile', decodeGameProfile, const GameProfile());
});

/// The question banks the games draw their questions from.
final questionBanksProvider = StateProvider<List<QuestionBank>>(
  (ref) => const <QuestionBank>[],
);

/// The weekly report shown on the weekly screen and the home screen.
///
/// Everything here is derived from what actually happened: focus minutes
/// from [studyStatsProvider], task completion from [taskScheduleProvider],
/// quiz answers from [challengeResultsProvider] and garden points from
/// [gardenProvider]. The week runs Saturday → Friday, as the screen shows.
final weeklyReportProvider = Provider<WeeklyReport>((ref) {
  final stats = ref.watch(studyStatsProvider);
  final schedule = ref.watch(taskScheduleProvider);
  final results = ref.watch(challengeResultsProvider);
  final garden = ref.watch(gardenProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: (today.weekday + 1) % 7));

  final days = <WeekDay>[];
  final subjectMinutes = <String, int>{};

  for (var i = 0; i < 7; i++) {
    final day = start.add(Duration(days: i));

    var tasksTotal = 0;
    var tasksDone = 0;
    final subjectsToday = <String>{};
    for (final entry in schedule.entries) {
      final due = entry.dueAt;
      if (due == null ||
          due.year != day.year ||
          due.month != day.month ||
          due.day != day.day) {
        continue;
      }
      tasksTotal++;
      if (entry.done) tasksDone++;
      final subject = _subjectOf(entry.title);
      if (subject != null) subjectsToday.add(subject);
    }

    var correct = 0;
    var wrong = 0;
    var challengePoints = 0;
    for (final result in results) {
      final at = result.finishedAt;
      if (at == null ||
          at.year != day.year ||
          at.month != day.month ||
          at.day != day.day) {
        continue;
      }
      correct += result.correct;
      wrong += result.total - result.correct;
      challengePoints += result.score;
    }

    var gardenPoints = 0;
    for (final plot in garden.plots) {
      if (plot.day.year == day.year &&
          plot.day.month == day.month &&
          plot.day.day == day.day) {
        gardenPoints += plot.points;
      }
    }

    final minutes = stats.minutesOn(day);
    if (minutes > 0) {
      // Focus sessions are not tied to a subject, so spread the day's time
      // across the subjects that were scheduled on it.
      final subjects = subjectsToday.isEmpty
          ? const ['مراجعة']
          : subjectsToday.toList();
      final share = (minutes / subjects.length).round();
      for (final subject in subjects) {
        subjectMinutes[subject] = (subjectMinutes[subject] ?? 0) + share;
      }
    }

    days.add(
      WeekDay(
        date: day,
        focusMinutes: minutes,
        points: challengePoints + gardenPoints,
        tasksDone: tasksDone,
        tasksTotal: tasksTotal,
        answersCorrect: correct,
        answersWrong: wrong,
      ),
    );
  }

  final subjects =
      subjectMinutes.entries
          .map(
            (e) => WeekSubject(
              subject: e.key,
              focusMinutes: e.value,
              points: e.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.focusMinutes.compareTo(a.focusMinutes));

  return WeeklyReport(
    weekStart: start,
    days: days,
    subjects: subjects,
    streak: stats.streakDays,
  );
});

/// Extracts the subject from a generated task title (`مذاكرة الرياضيات`).
String? _subjectOf(String title) {
  const prefix = 'مذاكرة ';
  if (!title.startsWith(prefix)) return null;
  final subject = title.substring(prefix.length).trim();
  return subject.isEmpty ? null : subject;
}

/// Minutes studied per day, which drive the home streak and the garden.
final studyStatsProvider = StateProvider<StudyStats>((ref) {
  return _restore(ref, 'study_stats', decodeStudyStats, const StudyStats());
});

/// Subscribes every persisted provider and writes its value back on change.
///
/// The provider carries no value of its own: watching it from the app root is
/// what keeps the listeners alive for the lifetime of the process.
final persistenceProvider = Provider<void>((ref) {
  void syncReminder() {
    if (ref.read(notificationsEnabledProvider)) {
      NotificationService.instance.scheduleDaily(
        hour: ref.read(reminderHourProvider),
        minute: ref.read(reminderMinuteProvider),
      );
    } else {
      NotificationService.instance.cancelDaily();
    }
  }

  ref.listen<bool>(notificationsEnabledProvider, (_, __) => syncReminder());
  ref.listen<int>(reminderHourProvider, (_, __) => syncReminder());
  ref.listen<int>(reminderMinuteProvider, (_, __) => syncReminder());

  // The profile survives restarts; the Firebase token intentionally does not.
  ref.listen<AuthUser?>(authUserProvider, (_, next) {
    if (next == null || next.uid.isEmpty) return;
    ref
        .read(localStoreProvider)
        .setString('auth_user', jsonEncode(next.toJson()));
  });

  final store = ref.watch(localStoreProvider);
  if (!store.isAvailable) return;

  void save<T>(
    ProviderListenable<T> source,
    String key,
    String Function(T value) encode,
  ) {
    ref.listen<T>(source, (_, next) {
      store.setString(key, encode(next));
    });
  }

  void saveBool(ProviderListenable<bool> source, String key) {
    ref.listen<bool>(source, (_, next) {
      store.setBool(key, next);
    });
  }

  save(taskListProvider, 'tasks', encodeTaskList);
  save(taskScheduleProvider, 'schedule', encodeTaskSchedule);
  save(goalsProvider, 'goals', encodeGoals);
  save(walletProvider, 'wallet', encodeWallet);
  save(notebooksProvider, 'notebooks', encodeNotebooks);
  save(wordListsProvider, 'word_lists', encodeWordLists);
  save(mistakesProvider, 'mistakes', encodeMistakeNotebook);
  save(reviewQueueProvider, 'recall', encodeReviewQueue);
  save(gameProfileProvider, 'game_profile', encodeGameProfile);
  save(gardenProvider, 'garden', encodeGarden);
  save(challengeResultsProvider, 'challenge_results', encodeChallengeResults);
  save(studyStatsProvider, 'study_stats', encodeStudyStats);
  save(selectedGradeProvider, 'selected_grade', (value) => value);
  save(readLessonsProvider, 'read_lessons', _encodeReadLessons);
  save(reminderHourProvider, 'reminder_hour', (value) => '$value');
  save(reminderMinuteProvider, 'reminder_minute', (value) => '$value');
  save(liveDatabaseUrlProvider, 'live_url', (value) => value);
  save(localeProvider, 'locale', (value) => value.languageCode);
  saveBool(notificationsEnabledProvider, 'notifications');
  saveBool(soundsEnabledProvider, 'sounds');
  saveBool(liveEnabledProvider, 'live_enabled');
});
