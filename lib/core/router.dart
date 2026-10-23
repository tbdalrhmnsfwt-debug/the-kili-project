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
import '../features/challenges/challenges_screen.dart';
import '../features/calculator/calculator_screen.dart';
import '../features/courses/course_list_screen.dart';
import '../features/exam/exam_home_screen.dart';
import '../features/exam/quiz_screen.dart';
import '../features/garden/garden_screen.dart';
import '../features/games/games_screen.dart';
import '../features/glossary/glossary_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/shell_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/lesson/book_lessons_screen.dart';
import '../features/mistakes/mistakes_screen.dart';
import '../features/notebooks/notebooks_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/quran/quran_home_screen.dart';
import '../features/quran/tasbih_screen.dart';
import '../features/question_bank/question_bank_screen.dart';
import '../features/recall/active_recall_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/subjects/subject_screen.dart';
import '../features/subjects/subjects_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/tools/irab_screen.dart';
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
  static const String subjects = '/subjects';
  static const String exams = '/exams';
  static const String quiz = '/quiz';
  static const String quran = '/quran';
  static const String glossary = '/glossary';
  static const String settings = '/settings';
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
  static const String pdfViewer = '/pdf-viewer';
  static const String scan = '/scan';
  static const String calculator = '/calculator';
  static const String irab = '/irab';
  static const String wallet = '/wallet';
  static const String achievements = '/achievements';

  /// Builds the path for a book's lesson list.
  static String lessonPath(Book book) => '$lesson/${book.grade}/${book.id}';

  /// Builds the path for a grade's book list.
  static String gradePath(String gradeId) => '$grade/$gradeId';

  /// Builds the path for a subject inside a grade and, when present, a track.
  static String subjectPath(
    String gradeId,
    String subjectId, {
    String? track,
  }) {
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
          const ShellScreen(initialIndex: 1, child: CourseListScreen()),
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
      builder: (context, state) => const CalculatorScreen(),
    ),
    GoRoute(
      path: ZakerRoutes.irab,
      builder: (context, state) => const IrabScreen(),
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
