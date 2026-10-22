/// The tasbih (مسبحة) counter.
///
/// The app ships a *tasbih* screen with a round counter the user taps to
/// count, plus a voice mode where the phone listens and counts for them.
///
/// The phrases themselves are not hardcoded here: they come from
/// `assets/data/adhkar.json`, the same file the adhkar list screen reads.
/// This model only carries the counting logic.
///
/// Shipped strings this model is built from:
///   * `المسبحة`
///   * `وِرد التسبيح`
///   * `وِرد الاستغفار`
///   * `سبح بإيدك أو بصوتك — وإحنا نعد`
///   * `سبح بصوتك`
///   * `دوس «ابدأ السمع» وسبح طبيعي`
///   * `سامعك… سبح وإحنا نعد`
///   * `مسمعتش حاجة — اكتب بإيدك.`
library;

/// Which "wird" (ور) of remembrance a phrase belongs to.
///
/// The adhkar asset tags every entry with a `type`:
///   * `0` — the general adhkar, shown in both morning and evening
///   * `1` — the morning set (`أصبحنا`)
///   * `2` — the evening set (`أمسينا`)
enum AdhkarType {
  /// Tagged `0` in the asset.
  general,

  /// Tagged `1` in the asset — the morning adhkar.
  morning,

  /// Tagged `2` in the asset — the evening adhkar.
  evening;

  /// Reads the tag out of the raw asset entry.
  static AdhkarType fromTag(Object? tag) {
    switch (tag) {
      case 1:
        return AdhkarType.morning;
      case 2:
        return AdhkarType.evening;
      default:
        return AdhkarType.general;
    }
  }
}

/// A phrase being counted.
class TasbihItem {
  TasbihItem({
    required this.content,
    required this.target,
    required this.countDescription,
    required this.order,
  });

  /// The text of the dhikr, straight from `adhkar.json`.
  final String content;

  /// How many times the phrase should be repeated.
  final int target;

  /// The wording the asset uses for the count, e.g. `مِائَةُ مَرَّةٍ`.
  final String countDescription;

  /// The position of the dhikr in the asset.
  final int order;

  /// How many times it has been said so far.
  int count = 0;

  /// Whether the target has been reached.
  bool get isComplete => count >= target;

  /// The progress in the range 0..1.
  double get progress => target <= 0 ? 0 : (count / target).clamp(0.0, 1.0);

  /// The remaining repeats.
  int get remaining => (target - count).clamp(0, target);

  /// The next count. Once the target is reached the counter wraps back to
  /// zero so the user can start the phrase again.
  int next() {
    if (isComplete) {
      count = 0;
    } else {
      count += 1;
    }
    return count;
  }

  /// Resets the counter.
  void reset() => count = 0;

  /// Builds an item from a raw `adhkar.json` entry.
  static TasbihItem fromJson(Map<String, dynamic> json) {
    return TasbihItem(
      content: (json['content'] as String?) ?? '',
      target: (json['count'] as num?)?.toInt() ?? 1,
      countDescription: (json['count_description'] as String?) ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The state of the whole counter screen.
///
/// The counter supports two ways of counting: tapping the big circle, and
/// letting the phone listen and count on its own.
class TasbihState {
  TasbihState({List<TasbihItem>? items}) : items = items ?? <TasbihItem>[];

  /// The phrases being counted.
  final List<TasbihItem> items;

  /// The index of the phrase currently on screen.
  int index = 0;

  /// Whether the phone is listening and counting on its own.
  bool listening = false;

  /// The item currently being counted.
  TasbihItem get current => items[index];

  /// The total number of taps today.
  int get total => items.fold(0, (sum, item) => sum + item.count);

  /// The number of phrases that reached their target.
  int get completedCount => items.where((i) => i.isComplete).length;

  /// Selects the phrase at [index].
  void select(int index) {
    if (index < 0 || index >= items.length) return;
    this.index = index;
  }

  /// Counts one more on the current phrase.
  int tap() => current.next();

  /// Turns the microphone listener on or off.
  void setListening(bool value) => listening = value;

  /// Resets every counter.
  void resetAll() {
    for (final item in items) {
      item.reset();
    }
  }

  /// The dhikr that are repeated more than once — these are the ones the
  /// counter makes sense for.
  static List<TasbihItem> countableFrom(List<Map<String, dynamic>> entries) {
    final out = <TasbihItem>[];
    for (final entry in entries) {
      final item = TasbihItem.fromJson(entry);
      if (item.target > 1 && item.content.isNotEmpty) out.add(item);
    }
    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }
}
