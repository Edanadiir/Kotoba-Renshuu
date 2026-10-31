import 'package:flutter_test/flutter_test.dart';

import 'package:kotoba_renshuu/core/models/quiz_item.dart';
import 'package:kotoba_renshuu/core/models/subject.dart';
import 'package:kotoba_renshuu/features/quiz/domain/quiz_engine.dart';

void main() {
  test('never generates reading cards for radicals', () {
    const radical = Subject(
      id: 1,
      type: SubjectType.radical,
      level: 1,
      characters: '口',
      meanings: ['Mouth'],
      readings: ['くち'],
    );

    final items = QuizEngine.buildItems(
      [radical],
      includeMeanings: true,
      includeReadings: true,
    );

    expect(items.map((item) => item.kind), [QuestionKind.meaning]);
  });

  test('builds separate Meaning and Reading cards for one vocabulary item', () {
    const subject = Subject(
      id: 2,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '学生',
      meanings: ['Student'],
      readings: ['がくせい'],
    );

    final items = QuizEngine.buildItems(
      [subject],
      includeMeanings: true,
      includeReadings: true,
    );

    expect(items, hasLength(2));
    expect(
      items.map((item) => item.kind),
      containsAll([QuestionKind.meaning, QuestionKind.reading]),
    );
  });

  test('kanji reading cards accept only the requested reading type', () {
    const subject = Subject(
      id: 3,
      type: SubjectType.kanji,
      level: 1,
      characters: '学',
      meanings: ['Study'],
      readings: ['がく', 'まなぶ'],
      readingDetails: [
        SubjectReading(reading: 'がく', type: 'onyomi', acceptedAnswer: true),
        SubjectReading(reading: 'まなぶ', type: 'kunyomi', acceptedAnswer: true),
      ],
    );

    final items = QuizEngine.buildItems(
      [subject],
      includeMeanings: false,
      includeReadings: true,
      separateKanjiReadingTypes: true,
    );

    expect(
      items.map((item) => item.kind),
      containsAll([QuestionKind.onyomi, QuestionKind.kunyomi]),
    );
    expect(QuizEngine.subjectAnswers(subject, QuestionKind.onyomi), ['がく']);
    expect(QuizEngine.subjectAnswers(subject, QuestionKind.kunyomi), ['まなぶ']);
  });

  test('wrong answer choices persist for a quiz item', () {
    const subject = Subject(
      id: 1,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '学生',
      meanings: ['Student'],
      readings: ['がくせい'],
    );
    final item = QuizItem(
      id: '1:meaning',
      subject: subject,
      kind: QuestionKind.meaning,
    );
    final engine = QuizEngine([item]);

    engine.recordWrongAnswer('Teacher');

    expect(engine.wrongAnswersFor(item.id), {'Teacher'});
    expect(engine.missedIds, {item.id});
  });

  test(
    'counts repeated incorrect attempts per item and restores the count',
    () {
      const subject = Subject(
        id: 4,
        type: SubjectType.vocabulary,
        level: 1,
        characters: '学生',
        meanings: ['Student'],
        readings: ['がくせい'],
      );
      final item = QuizItem(
        id: '4:meaning',
        subject: subject,
        kind: QuestionKind.meaning,
      );
      final engine = QuizEngine([item]);

      engine
        ..recordWrongAnswer('Teacher')
        ..recordWrongAnswer('Teacher');

      expect(engine.incorrectAttemptsFor(item.id), 2);
      expect(engine.wrongAnswersFor(item.id), {'Teacher'});

      final restored = QuizEngine.restore(
        queue: [item],
        completed: {},
        missed: {item.id},
        firstAttemptCorrect: {},
        wrongAnswers: engine.wrongAnswersSnapshot.map(
          (key, value) => MapEntry(key, value.toSet()),
        ),
        incorrectAttempts: engine.incorrectAttemptsSnapshot,
      );
      expect(restored.incorrectAttemptsFor(item.id), 2);
    },
  );
}
