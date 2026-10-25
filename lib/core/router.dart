/// Navigation graph.
///
/// The original app uses `go_router` (confirmed in the dependency manifest)
/// with a shell route per bottom-navigation tab.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/achievement/achievement_screen.dart';
import '../features/account/account_screen.dart';
import '../features/ai/chat_screen.dart';
import '../features/ai/mind_map_screen.dart';
import '../features/azkar/azkar_home_screen.dart';
import '../features/azkar/azkar_licenses_screen.dart';
import '../features/azkar/azkar_list_screen.dart';
import '../features/azkar/azkar_models.dart';
import '../features/azkar/azkar_settings_screen.dart';
import '../features/azkar/azkar_tasbih_screen.dart';
import '../features/azkar/kahf_screen.dart';
import '../features/azkar/salat_counter_screen.dart';
import '../features/challenges/challenges_screen.dart';
import '../features/calculator/calc_pro_screen.dart';
import '../features/courses/course_list_screen.dart';
import '../features/exam/exam_home_screen.dart';
import '../features/exam/quiz_screen.dart';
import '../features/garden/garden_screen.dart';
import '../features/games/games_screen.dart';
import '../features/glossary/glossary_screen.dart';
import '../features/hifz/hifz_home_screen.dart';
import '../features/hifz/hifz_setup_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/shell_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/lesson/book_lessons_screen.dart';
import '../features/library/study_grade_screen.dart';
import '../features/library/study_library_screen.dart';
import '../features/library/study_subject_screen.dart';
import '../features/library/official_book_screen.dart';
import '../features/library/official_flashcards_screen.dart';
import '../features/library/official_library_screen.dart';
import '../features/library/official_mind_map_screen.dart';
import '../features/library/official_section_screen.dart';
import '../features/mistakes/mistakes_screen.dart';
import '../features/islamic/diagnostics_screen.dart';
import '../features/islamic/islamic_hub_screen.dart';
import '../features/notebooks/notebooks_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/prayer/adhan_playback_screen.dart';
import '../features/prayer/adhan_settings_screen.dart';
import '../features/prayer/battery_optimization_screen.dart';
import '../features/prayer/prayer_credits_screen.dart';
import '../features/prayer/prayer_log_screen.dart';
import '../features/prayer/prayer_screen.dart';
import '../features/prayer/qibla_screen.dart';
import '../features/quran/quran_home_screen.dart';
import '../features/quran/tasbih_screen.dart';
import '../features/question_bank/question_bank_screen.dart';
import '../features/recall/active_recall_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/subjects/subject_screen.dart';
import '../features/subjects/subjects_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/tools/irab_screen.dart';
import '../features/pdf/pdf_library_screen.dart';
import '../features/tools/pdf_tools_screen.dart';
import '../features/tools/pdf_viewer_screen.dart';
import '../features/tools/scan_screen.dart';
import '../features/translate/translate_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/weakness/weakness_screen.dart';
import '../features/weekly/weekly_screen.dart';
import '../features/whiteboard/whiteboard_screen.dart';
import '../features/words/words_screen.dart';
import '../models/manhaji.dart';
import '../widgets/tr_text.dart';

/// The app's route paths.
class ZakerRoutes {
  const ZakerRoutes._();

  static const String home = '/';
  static const String courses = '/courses';
  static const String library = '/library';
  static const String subjects = '/subjects';
  static const String exams = '/exams';
  static const String quiz = '/quiz';
  static const String quran = '/quran';
  static const String hifz = '/hifz';
  static const String hifzSetup = '/hifz/setup';
  static const String glossary = '/glossary';
  static const String settings = '/settings';
  static const String appearance = '/appearance';
  static const String account = '/account';
  static const String lesson = '/lesson';
  static const String grade = '/grade';
  static const String chat = '/chat';
  static const String recall = '/recall';
  static const String mindMap = '/mindmap';
  static const String planner = '/planner';
  static const String tasks = '/tasks';
  static const String leaderboard = '/leaderboard';
  static const String garden = '/garden';
  static const String mistakes = '/mistakes';
  static const String notebooks = '/notebooks';
  static const String words = '/words';
  static const String translate = '/translate';
  static const String challenges = '/challenges';
  static const String weakness = '/weakness';
  static const String games = '/games';
  static const String questionBank = '/question-bank';
  static const String whiteboard = '/whiteboard';
  static const String weekly = '/weekly';
  static const String tasbih = '/tasbih';
  static const String pdfTools = '/pdf-tools';
  static const String pdfLibrary = '/pdf-library';
  static const String pdfViewer = '/pdf-viewer';
  static const String scan = '/scan';
  static const String calculator = '/calculator';
  static const String irab = '/irab';
  static const String prayer = '/prayer';
  static const String islamicHub = '/islam';
  static const String qibla = '/prayer/qibla';
  static const String adhanPlayback = '/prayer/adhan';
  static const String prayerNotifications = '/prayer/notifications';
  static const String prayerBattery = '/prayer/battery';
  static const String prayerCredits = '/prayer/credits';
  static const String prayerDiagnostics = '/prayer/diagnostics';
  static const String prayerLog = '/prayer/log';
  static const String azkar = '/azkar';
  static const String azkarMorning = '/azkar/morning';
  static const String azkarEvening = '/azkar/evening';
  static const String azkarTasbih = '/azkar/tasbih';
  static const String azkarSalat = '/azkar/salat';
  static const String azkarKahf = '/azkar/kahf';
  static const String azkarSettings = '/azkar/settings';
  static const String azkarLicenses = '/azkar/licenses';
  static const String wallet = '/wallet';
  static const String achievements = '/achievements';

  /// The official 2026–2027 Ministry library.
  static const String official = '/official';
  static const String officialBook = '/official/book';

  /// Builds the path for one official book.
  static String officialBookPath(String bookId) =>
      '$officialBook/${Uri.encodeComponent(bookId)}';

  /// Builds the path for an extracted lesson inside an official book.
  static String officialSectionPath(String bookId, String sectionId) =>
      '${officialBookPath(bookId)}/section/${Uri.encodeComponent(sectionId)}';

  /// Builds the path for a lesson's interactive mind map.
  static String officialMindMapPath(String bookId, String sectionId) =>
      '${officialSectionPath(bookId, sectionId)}/mindmap';

  /// Builds the path for a lesson's flashcard deck.
  static String officialFlashcardsPath(String bookId, String sectionId) =>
      '${officialSectionPath(bookId, sectionId)}/flashcards';

  /// Builds the path for a book's lesson list.
  static String lessonPath(Book book) => '$lesson/${book.grade}/${book.id}';

  /// Builds the path for a grade's book list.
  static String gradePath(String gradeId) => '$grade/$gradeId';

  /// Builds the path for a grade inside the Study Library hierarchy.
  static String libraryPath(String gradeId) => '$library/$gradeId';

  /// Builds the path for a subject inside a grade's Study Library screen.
  static String librarySubjectPath(String gradeId, String subject) =>
      '$library/$gradeId/${Uri.encodeComponent(subject)}';

  /// Builds the path for a subject inside a grade and, when present, a track.
  static String subjectPath(String gradeId, String subjectId, {String? track}) {
    final base = '$subjects/$gradeId/$subjectId';
    return track == null || track.isEmpty
        ? base
        : '$base?track=${Uri.encodeQueryComponent(track)}';
  }
}

/// The root router.
final GoRouter appRouter = GoRouter(
  initialLocation: ZakerRoutes.home,
  routes: [
    GoRoute(
      path: ZakerRoutes.home,
      builder: (context, state) =>
          const ShellScreen(initialIndex: 0, child: HomeScreen()),
    ),
    GoRoute(
      path: ZakerRoutes.courses,
      builder: (context, state) =>
          const ShellScreen(initialIndex: 1, child: StudyLibraryScreen()),
    ),
    GoRoute(
      path: ZakerRoutes.official,
      builder: (context, state) => const OfficialLibraryScreen(),
    ),
    GoRoute(
      path: '${ZakerRoutes.officialBook}/:bookId',
      builder: (context, state) =>
          OfficialBookScreen(bookId: state.pathParameters['bookId'] ?? ''),
    ),
    GoRoute(
      path: '${ZakerRoutes.officialBook}/:bookId/section/:sectionId',
      builder: (context, state) => OfficialSectionScreen(
        bookId: state.pathParameters['bookId'] ?? '',
        sectionId: state.pathParameters['sectionId'] ?? '',
      ),
    ),
    GoRoute(
      path: '${ZakerRoutes.officialBook}/:bookId/section/:sectionId/mindmap',
      builder: (context, state) => OfficialMindMapScreen(
        bookId: state.pathParameters['bookId'] ?? '',
        sectionId: state.pathParameters['sectionId'] ?? '',
      ),
    ),
    GoRoute(
      path: '${ZakerRoutes.officialBook}/:bookId/section/:sectionId/flashcards',
      builder: (context, state) => OfficialFlashcardsScreen(
        bookId: state.pathParameters['bookId'] ?? '',
        sectionId: state.pathParameters['sectionId'] ?? '',
      ),
    ),
    GoRoute(
      path: '${ZakerRoutes.library}/:gradeId',
      builder: (context, state) =>
          StudyGradeScreen(gradeId: state.pathParameters['gradeId'] ?? 'sec1'),
    ),
    GoRoute(
      path: '${ZakerRoutes.library}/:gradeId/:subject',
      builder: (context, state) => StudySubjectScreen(
        gradeId: state.pathParameters['gradeId'] ?? 'sec1',
        subject: state.pathParameters['subject'] ?? '',
      ),
    ),
    GoRoute(
      path: ZakerRoutes.exams,
      builder: (context, state) =>
          const ShellScreen(initialIndex: 2, child: ExamHomeScreen()),
    ),
    GoRoute(
      path: ZakerRoutes.quran,
      builder: (context, state) =>
          const ShellScreen(initialIndex: 3, child: QuranHomeScreen()),
    ),
    GoRoute(
      path: ZakerRoutes.hifz,
      builder: (context, state) => const HifzHomeScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.hifzSetup,
      builder: (context, state) => HifzSetupScreen(
        initialSurahNumber: int.tryParse(
          state.uri.queryParameters['surah'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: ZakerRoutes.subjects,
      builder: (context, state) => SubjectsScreen(
        gradeId: state.uri.queryParameters['grade'],
        trackId: state.uri.queryParameters['track'],
      ),
    ),
    GoRoute(
      path: '${ZakerRoutes.subjects}/:gradeId/:subjectId',
      builder: (context, state) => SubjectScreen(
        gradeId: state.pathParameters['gradeId'] ?? 'sec1',
        subjectId: state.pathParameters['subjectId'] ?? '',
        trackId: state.uri.queryParameters['track'],
      ),
    ),
    GoRoute(
      path: ZakerRoutes.quiz,
      builder: (context, state) => const QuizScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.glossary,
      builder: (context, state) => const GlossaryScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.appearance,
      builder: (context, state) => const AppearanceScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.account,
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.grade,
      builder: (context, state) {
        final gradeId = state.pathParameters['gradeId'] ?? 'sec1';
        return CourseListScreen(gradeId: gradeId);
      },
    ),
    GoRoute(
      path: '${ZakerRoutes.lesson}/:gradeId/:bookId',
      builder: (context, state) {
        final gradeId = state.pathParameters['gradeId'] ?? 'sec1';
        final bookId = state.pathParameters['bookId'] ?? '';
        return BookLessonsScreen(gradeId: gradeId, bookId: bookId);
      },
    ),
    GoRoute(
      path: ZakerRoutes.chat,
      builder: (context, state) => ChatScreen(
        subject: state.uri.queryParameters['subject'],
        // The home search field hands its text over as `q`.
        initialQuestion: state.uri.queryParameters['q'],
      ),
    ),
    GoRoute(
      path: ZakerRoutes.recall,
      builder: (context, state) => const ActiveRecallScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.mindMap,
      builder: (context, state) =>
          MindMapScreen(title: state.uri.queryParameters['title'] ?? 'خريطة'),
    ),
    GoRoute(
      path: ZakerRoutes.planner,
      builder: (context, state) => const PlannerScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.tasks,
      builder: (context, state) => const TasksScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.leaderboard,
      builder: (context, state) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.garden,
      builder: (context, state) => const GardenScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.mistakes,
      builder: (context, state) => const MistakesScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.notebooks,
      builder: (context, state) => const NotebooksScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.words,
      builder: (context, state) => const WordsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.translate,
      builder: (context, state) => const TranslateScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.challenges,
      builder: (context, state) => const ChallengesScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.weakness,
      builder: (context, state) => const WeaknessScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.games,
      builder: (context, state) => const GamesScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.questionBank,
      builder: (context, state) => const QuestionBankScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.whiteboard,
      builder: (context, state) => const WhiteboardScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.weekly,
      builder: (context, state) => const WeeklyScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.tasbih,
      builder: (context, state) => const TasbihScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.pdfTools,
      builder: (context, state) => const PdfToolsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.pdfLibrary,
      builder: (context, state) => const PdfLibraryScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.pdfViewer,
      builder: (context, state) => PdfViewerScreen(
        path: state.uri.queryParameters['path'],
        title: state.uri.queryParameters['title'],
      ),
    ),
    GoRoute(
      path: ZakerRoutes.scan,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.calculator,
      builder: (context, state) => const CalculatorProScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.irab,
      builder: (context, state) => const IrabScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.islamicHub,
      builder: (context, state) => const IslamicHubScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.prayer,
      builder: (context, state) => const PrayerScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.qibla,
      builder: (context, state) => const QiblaScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.adhanPlayback,
      builder: (context, state) {
        final query = state.uri.queryParameters;
        return AdhanPlaybackScreen(
          prayerName: query['prayer'] ?? 'dhuhr',
          time: DateTime.tryParse(query['time'] ?? ''),
          city: query['city'] ?? '',
          voiceId: query['voice'],
          notificationId: int.tryParse(query['id'] ?? ''),
        );
      },
    ),
    GoRoute(
      path: ZakerRoutes.prayerNotifications,
      builder: (context, state) => const AdhanSettingsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.prayerBattery,
      builder: (context, state) => const BatteryOptimizationScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.prayerCredits,
      builder: (context, state) => const PrayerCreditsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.prayerDiagnostics,
      builder: (context, state) => const DiagnosticsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.prayerLog,
      builder: (context, state) => const PrayerLogScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.azkar,
      builder: (context, state) => const AzkarHomeScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.azkarMorning,
      builder: (context, state) =>
          const AzkarListScreen(period: AzkarPeriod.morning),
    ),
    GoRoute(
      path: ZakerRoutes.azkarEvening,
      builder: (context, state) =>
          const AzkarListScreen(period: AzkarPeriod.evening),
    ),
    GoRoute(
      path: ZakerRoutes.azkarTasbih,
      builder: (context, state) => const AzkarTasbihScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.azkarSalat,
      builder: (context, state) => SalatCounterScreen(
        initialPhraseId: state.uri.queryParameters['phrase'],
      ),
    ),
    GoRoute(
      path: ZakerRoutes.azkarKahf,
      builder: (context, state) => const KahfScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.azkarSettings,
      builder: (context, state) => const AzkarSettingsScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.azkarLicenses,
      builder: (context, state) => const AzkarLicensesScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.wallet,
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.achievements,
      builder: (context, state) => const AchievementScreen(),
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: TrText('مفيش الصفحة دي: ${state.uri}'))),
);
