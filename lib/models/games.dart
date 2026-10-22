/// The study games.
///
/// The shipped strings describe an "adventure map" of games that all draw
/// their questions from the student's own question bank:
///   * `خريطة مغامرة فيها عشر ألعاب كلها بتاكل من أسئلة مادتك: بنك الحظ،
///      السباق، معركة الوحش، الصندوق، القنبلة…`
///   * `كل لعبة بتديك نجوم وعملات، والعملات بتطلعك مستويات.`
///   * `مذاكرة على شكل لعبة — تجاوب صح تتقدم وتكسب.`
///   * `كل إجابة صح بتقلل طاقة الوحش لحد ما تهزمه`
library;

import 'dart:convert';

import '../core/strings.dart' show ZakerStrings;
import 'exam.dart';

/// One of the games on the adventure map.
enum GameKind {
  /// The wheel of fortune that asks one question per spin.
  fortune,

  /// The race against the clock.
  race,

  /// The monster fight: every correct answer drains the monster's energy.
  monster,

  /// The surprise chest that holds questions, coins or a bomb.
  chest,

  /// The bomb that has to be defused before it goes off.
  bomb,

  /// The memory game: match the term to its definition.
  memory,
}

/// The state of a single game session.
class GameSession {
  const GameSession({
    required this.kind,
    required this.title,
    this.questions = const [],
    this.index = 0,
    this.stars = 0,
    this.coins = 0,
    this.lives = 3,
    this.monsterEnergy = 100,
    this.finished = false,
  });

  /// Which game is being played.
  final GameKind kind;

  /// The display name of the game.
  final String title;

  /// The questions the game draws from.
  final List<ExamQuestion> questions;

  /// How many questions have been answered so far.
  final int index;

  /// Stars earned in this session.
  final int stars;

  /// Coins earned in this session.
  final int coins;

  /// Remaining lives.
  final int lives;

  /// The monster's remaining energy, in the range 0..100.
  final int monsterEnergy;

  /// Whether the session is over.
  final bool finished;

  /// The question being asked right now.
  ExamQuestion? get current {
    if (index < 0 || index >= questions.length) return null;
    return questions[index];
  }

  /// How far through the session the player is, in the range 0..1.
  double get progress {
    if (questions.isEmpty) return 0;
    return index.clamp(0, questions.length) / questions.length;
  }

  /// Whether the monster has been defeated.
  bool get monsterDefeated => kind == GameKind.monster && monsterEnergy <= 0;

  /// A copy of this session with the given fields replaced.
  GameSession copyWith({
    List<ExamQuestion>? questions,
    int? index,
    int? stars,
    int? coins,
    int? lives,
    int? monsterEnergy,
    bool? finished,
  }) {
    return GameSession(
      kind: kind,
      title: title,
      questions: questions ?? this.questions,
      index: index ?? this.index,
      stars: stars ?? this.stars,
      coins: coins ?? this.coins,
      lives: lives ?? this.lives,
      monsterEnergy: monsterEnergy ?? this.monsterEnergy,
      finished: finished ?? this.finished,
    );
  }

  /// Answers the current question.
  ///
  /// A correct answer earns a star and — in the monster game — drains the
  /// monster's energy.  A wrong one costs a life.
  GameSession answer({required bool correct, bool rewardCoins = false}) {
    final next = index + 1;
    final last = next >= questions.length;
    final drained = monsterEnergy - 25;
    return copyWith(
      index: next,
      stars: correct ? stars + 1 : stars,
      coins: (correct && rewardCoins) ? coins + 15 : coins,
      lives: correct ? lives : (lives > 0 ? lives - 1 : 0),
      monsterEnergy: correct && kind == GameKind.monster
          ? (drained < 0 ? 0 : drained)
          : monsterEnergy,
      finished: last || lives <= 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'stars': stars,
    'coins': coins,
    'lives': lives,
    'monsterEnergy': monsterEnergy,
    'finished': finished,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) {
    final name = json['kind'] as String? ?? 'fortune';
    return GameSession(
      kind: GameKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => GameKind.fortune,
      ),
      title: json['title'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      lives: (json['lives'] as num?)?.toInt() ?? 3,
      monsterEnergy: (json['monsterEnergy'] as num?)?.toInt() ?? 100,
      finished: json['finished'] as bool? ?? false,
    );
  }
}

/// The player's game profile: stars, coins and the level the coins buy.
class GameProfile {
  const GameProfile({
    this.stars = 0,
    this.coins = 0,
    this.level = 1,
  });

  /// Stars earned across all games.
  final int stars;

  /// Coins earned across all games.
  final int coins;

  /// The level the coins have bought.
  final int level;

  /// How many coins the next level costs.
  int get nextLevelCost => level * 100;

  /// How far the player is towards the next level, in the range 0..1.
  double get levelProgress {
    final cost = nextLevelCost;
    if (cost <= 0) return 1;
    return (coins % cost) / cost;
  }

  /// A copy of this profile with the given fields replaced.
  GameProfile copyWith({int? stars, int? coins, int? level}) {
    return GameProfile(
      stars: stars ?? this.stars,
      coins: coins ?? this.coins,
      level: level ?? this.level,
    );
  }

  /// Adds the rewards of a finished session, levelling up as needed.
  GameProfile reward(GameSession session) {
    var newCoins = coins + session.coins;
    var newLevel = level;
    while (newCoins >= newLevel * 100) {
      newCoins -= newLevel * 100;
      newLevel += 1;
    }
    return GameProfile(
      stars: stars + session.stars,
      coins: newCoins,
      level: newLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'stars': stars,
    'coins': coins,
    'level': level,
  };

  factory GameProfile.fromJson(Map<String, dynamic> json) {
    return GameProfile(
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }
}

/// One stop on the adventure map.
class GameStop {
  const GameStop({
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  /// Which game this stop runs.
  final GameKind kind;

  /// The stop's name.
  final String title;

  /// A one-line description of the stop.
  final String subtitle;

  /// The stops on the map, in the order the shipped string lists them.
  static const List<GameStop> all = [
    GameStop(
      kind: GameKind.fortune,
      title: ZakerStrings.s_c40b2, // بنك الحظ
      subtitle: ZakerStrings.s_9d028, // ورا كل صندوق مفاجأة — سؤال، عملات، أو قنبلة
    ),
    GameStop(
      kind: GameKind.race,
      title: ZakerStrings.s_0aab0, // سباق
      subtitle: ZakerStrings.s_1a10d, // كل إجابة صح بتحرك عربيتك — اسبق الخصم
    ),
    GameStop(
      kind: GameKind.monster,
      title: ZakerStrings.s_f82b1, // معركة الوحش
      subtitle: ZakerStrings.s_8ff80, // كل إجابة صح بتقلل طاقة الوحش لحد ما تهزمه
    ),
    GameStop(
      kind: GameKind.chest,
      title: ZakerStrings.s_6344a, // اختار صندوق 👀
      subtitle: ZakerStrings.s_9d028, // ورا كل صندوق مفاجأة — سؤال، عملات، أو قنبلة
    ),
    GameStop(
      kind: GameKind.bomb,
      title: ZakerStrings.s_6d5f5, // القنبلة
      subtitle: ZakerStrings.s_597e6, // كل إجابة صح بترمي الزار — احترس من التعابين
    ),
    GameStop(
      kind: GameKind.memory,
      title: ZakerStrings.s_0f5f5, // لعبة الذاكرة
      subtitle: ZakerStrings.s_928ae, // مذاكرة على شكل لعبة — تجاوب صح تتقدم وتكسب.
    ),
  ];
}

/// Serialises the game profile for local storage.
String encodeGameProfile(GameProfile profile) =>
    base64Url.encode(utf8.encode(jsonEncode(profile.toJson())));

/// Reads back a profile written by [encodeGameProfile].
GameProfile decodeGameProfile(String raw) {
  try {
    final json =
        jsonDecode(utf8.decode(base64Url.decode(raw))) as Map<String, dynamic>;
    return GameProfile.fromJson(json);
  } catch (_) {
    return const GameProfile();
  }
}
