import 'dart:math';

import '../../../core/models/quiz_item.dart';
import '../../../core/models/subject.dart';
import 'quiz_config.dart';

class QuizEngine {
  QuizEngine(Iterable<QuizItem> items, {this.config = const QuizConfig()})
    : _queue = List.of(items)..shuffle(),
      _completed = {},
      _missed = {},
      _firstAttemptCorrect = {},
      _wrongAnswers = {},
      _incorrectAttempts = {};

  QuizEngine.restore({
    required Iterable<QuizItem> queue,
    required Set<String> completed,
    required Set<String> missed,
    required Set<String> firstAttemptCorrect,
    this.config = const QuizConfig(),
    Map<String, Set<String>> wrongAnswers = const {},
    Map<String, int> incorrectAttempts = const {},
  }) : _queue = List.of(queue),
       _completed = {...completed},
       _missed = {...missed},
       _firstAttemptCorrect = {...firstAttemptCorrect},
       _wrongAnswers = {
         for (final entry in wrongAnswers.entries) entry.key: {...entry.value},
       },
       _incorrectAttempts = {...incorrectAttempts};

  final List<QuizItem> _queue;
  final QuizConfig config;
  final Set<String> _completed;
  final Set<String> _missed;
  final Set<String> _firstAttemptCorrect;
  final Map<String, Set<String>> _wrongAnswers;
  final Map<String, int> _incorrectAttempts;
  final Random _random = Random();

  QuizItem? get current => _queue.isEmpty ? null : _queue.first;
  int get totalItems => _firstAttemptCorrect.length + _missed.length;
  int get completedItems => _completed.length;
  double get accuracy =>
      totalItems == 0 ? 0 : _firstAttemptCorrect.length / totalItems;
  Set<String> get missedIds => Set.unmodifiable(_missed);
  List<String> get remainingIds => _queue.map((item) => item.id).toList();
  Set<String> get completedIds => Set.unmodifiable(_completed);
  Set<String> get firstAttemptCorrectIds =>
      Set.unmodifiable(_firstAttemptCorrect);

  Set<String> wrongAnswersFor(String itemId) =>
      Set.unmodifiable(_wrongAnswers[itemId] ?? const <String>{});
  int incorrectAttemptsFor(String itemId) => _incorrectAttempts[itemId] ?? 0;
  Map<String, int> get incorrectAttemptsSnapshot =>
      Map.unmodifiable(_incorrectAttempts);

  Map<String, List<String>> get wrongAnswersSnapshot => {
    for (final entry in _wrongAnswers.entries) entry.key: entry.value.toList(),
  };

  void recordWrongAnswer(String answer) {
    final item = current;
    if (item == null) return;
    (_wrongAnswers[item.id] ??= <String>{}).add(answer);
    _incorrectAttempts.update(
      item.id,
      (attempts) => attempts + 1,
      ifAbsent: () => 1,
    );
    recordMistake();
  }

  void failAndRecycleCurrent(String answer) {
    final item = current;
    if (item == null) return;
    recordWrongAnswer(answer);
    _queue.removeAt(0);
    _queue.add(item);
  }

  bool submit(bool correct) {
    final item = current;
    if (item == null) return false;
    if (correct) {
      _completed.add(item.id);
      if (!_missed.contains(item.id)) _firstAttemptCorrect.add(item.id);
      _queue.removeAt(0);
      return true;
    }
    _missed.add(item.id);
    _firstAttemptCorrect.remove(item.id);
    _queue.removeAt(0);
    final insertAt = _queue.isEmpty ? 0 : 1 + _random.nextInt(_queue.length);
    _queue.insert(insertAt.clamp(0, _queue.length), item);
    return false;
  }

  void recordMistake() {
    final item = current;
    if (item != null) {
      _missed.add(item.id);
      _firstAttemptCorrect.remove(item.id);
    }
  }

  bool submitAndRecycle(bool correct) {
    final item = current;
    if (item == null) return false;
    if (correct) return submit(true);
    recordMistake();
    _queue.removeAt(0);
    final insertAt = _queue.isEmpty ? 0 : 1 + _random.nextInt(_queue.length);
    _queue.insert(insertAt.clamp(0, _queue.length), item);
    return false;
  }

  bool completeCurrent() => submit(true);

  static List<QuizItem> buildItems(
    Iterable<Subject> subjects, {
    required bool includeMeanings,
    required bool includeReadings,
    bool separateKanjiReadingTypes = false,
    int? limit,
  }) {
    final items = <QuizItem>[];
    for (final subject in subjects) {
      if (includeMeanings) {
        items.add(
          QuizItem(
            id: '${subject.id}:meaning',
            subject: subject,
            kind: QuestionKind.meaning,
          ),
        );
      }
      if (includeReadings &&
          subject.type != SubjectType.radical &&
          subject.readings.isNotEmpty) {
        if (separateKanjiReadingTypes &&
            subject.type == SubjectType.kanji &&
            subject.hasTypedReadings) {
          for (final kind in [QuestionKind.onyomi, QuestionKind.kunyomi]) {
            final type = kind == QuestionKind.onyomi ? 'onyomi' : 'kunyomi';
            if (subject.readingsFor(type).isNotEmpty) {
              items.add(
                QuizItem(
                  id: '${subject.id}:${kind.value}',
                  subject: subject,
                  kind: kind,
                ),
              );
            }
          }
        } else {
          items.add(
            QuizItem(
              id: '${subject.id}:reading',
              subject: subject,
              kind: QuestionKind.reading,
            ),
          );
        }
      }
    }
    items.shuffle();
    if (items.length <= (limit ?? items.length)) return items;
    return items.take(limit!).toList();
  }

  static List<String> distractors(
    Subject subject,
    Iterable<Subject> pool, {
    required QuestionKind kind,
  }) {
    final values = <String>[];
    final byId = {for (final item in pool) item.id: item};
    for (final id in subject.visuallySimilarSubjectIds) {
      final similar = byId[id];
      if (similar != null) values.addAll(_answers(similar, kind));
    }
    final fallback = pool.where(
      (item) => item.id != subject.id && item.type == subject.type,
    );
    for (final item in fallback) {
      values.addAll(_answers(item, kind));
    }
    return values
        .toSet()
        .where((value) => !subjectAnswers(subject, kind).contains(value))
        .take(3)
        .toList();
  }

  static List<String> subjectAnswers(Subject subject, QuestionKind kind) =>
      switch (kind) {
        QuestionKind.meaning => subject.meanings,
        QuestionKind.reading => subject.readings,
        QuestionKind.onyomi => subject.readingsFor('onyomi'),
        QuestionKind.kunyomi => subject.readingsFor('kunyomi'),
      };

  static List<String> _answers(Subject subject, QuestionKind kind) =>
      subjectAnswers(subject, kind);
}
