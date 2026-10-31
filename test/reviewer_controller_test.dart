import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoba_renshuu/core/models/assignment.dart';
import 'package:kotoba_renshuu/core/models/context_sentence.dart';
import 'package:kotoba_renshuu/core/models/quiz_item.dart';
import 'package:kotoba_renshuu/core/models/subject.dart';
import 'package:kotoba_renshuu/features/quiz/domain/quiz_engine.dart';
import 'package:kotoba_renshuu/main.dart';

void main() {
  test('wrong choice advances, while revealed second miss waits for Next', () {
    const firstSubject = Subject(
      id: 201,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '学生',
      meanings: ['Student'],
      readings: ['がくせい'],
    );
    const secondSubject = Subject(
      id: 202,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '先生',
      meanings: ['Teacher'],
      readings: ['せんせい'],
    );
    final first = QuizItem(
      id: '201:meaning',
      subject: firstSubject,
      kind: QuestionKind.meaning,
    );
    final second = QuizItem(
      id: '202:meaning',
      subject: secondSubject,
      kind: QuestionKind.meaning,
    );
    final controller = ReviewerController()
      ..quizItems = [first, second]
      ..engine = QuizEngine.restore(
        queue: [first, second],
        completed: {},
        missed: {},
        firstAttemptCorrect: {},
      );

    controller.answerChoice('Learner', false);
    expect(controller.currentItem?.id, second.id);
    expect(controller.engine?.incorrectAttemptsFor(first.id), 1);

    controller.engine = QuizEngine.restore(
      queue: [first, second],
      completed: {},
      missed: {first.id},
      firstAttemptCorrect: {},
      wrongAnswers: {
        first.id: {'Learner'},
      },
      incorrectAttempts: {first.id: 1},
    );
    controller.recordRevealedChoiceMiss('Pupil');
    expect(controller.currentItem?.id, first.id);
    expect(controller.engine?.incorrectAttemptsFor(first.id), 2);

    controller.nextAfterFeedback(false);
    expect(controller.currentItem?.id, second.id);
    expect(controller.engine?.remainingIds, [second.id, first.id]);
  });

  test('typing type filter controls Both and Readings pools', () {
    final controller = ReviewerController()
      ..subjects.addAll([
        const Subject(
          id: 1,
          type: SubjectType.radical,
          level: 1,
          characters: '口',
          meanings: ['Mouth'],
          readings: ['くち'],
        ),
        const Subject(
          id: 2,
          type: SubjectType.kanji,
          level: 1,
          characters: '口',
          meanings: ['Mouth'],
          readings: ['こう'],
        ),
        const Subject(
          id: 3,
          type: SubjectType.vocabulary,
          level: 1,
          characters: '入口',
          meanings: ['Entrance'],
          readings: ['いりぐち'],
        ),
      ])
      ..assignments.addAll([
        for (var id = 1; id <= 3; id++)
          Assignment(
            id: id,
            subjectId: id,
            srsStage: SrsStage.apprentice,
            unlockedAt: null,
          ),
      ]);

    controller.startQuiz();

    expect(controller.quizPool.map((subject) => subject.type), {
      SubjectType.radical,
      SubjectType.kanji,
      SubjectType.vocabulary,
    });
    expect(
      controller.quizItems
          .where((item) => item.kind == QuestionKind.reading)
          .map((item) => item.subject.type),
      {SubjectType.kanji, SubjectType.vocabulary},
    );
    expect(
      controller.quizItems
          .where((item) => item.kind == QuestionKind.meaning)
          .map((item) => item.subject.type),
      {SubjectType.radical, SubjectType.kanji, SubjectType.vocabulary},
    );

    controller.subjectTypes = {SubjectType.radical};
    controller.startQuiz();
    expect(controller.quizPool.map((subject) => subject.type), {
      SubjectType.radical,
    });
    expect(controller.quizItems, hasLength(1));
    expect(controller.quizItems.single.kind, QuestionKind.meaning);

    controller.selectMode(StudyMode.typing);
    controller.scope = QuestionScope.reading;
    controller.subjectTypes = {SubjectType.radical};
    expect(
      controller.filteredSubjects(StudyMode.typing).map((item) => item.type),
      isEmpty,
    );
    expect(controller.availableItemCount, 0);
  });

  test('randomly samples eligible subjects before applying session size', () {
    final controller = ReviewerController(random: Random(42))
      ..subjects.addAll([
        for (var id = 1; id <= 12; id++)
          Subject(
            id: id,
            type: SubjectType.radical,
            level: 1,
            characters: 'R$id',
            meanings: ['Radical $id'],
            readings: const [],
          ),
        const Subject(
          id: 99,
          type: SubjectType.vocabulary,
          level: 1,
          characters: '語彙',
          meanings: ['Vocabulary'],
          readings: ['ごい'],
        ),
        const Subject(
          id: 100,
          type: SubjectType.vocabulary,
          level: 1,
          characters: '未習語',
          meanings: ['Unlearned word'],
          readings: ['みしゅうご'],
        ),
      ])
      ..assignments.addAll([
        for (var id = 1; id <= 12; id++)
          Assignment(
            id: id,
            subjectId: id,
            srsStage: SrsStage.apprentice,
            unlockedAt: null,
          ),
        const Assignment(
          id: 99,
          subjectId: 99,
          srsStage: SrsStage.apprentice,
          unlockedAt: null,
        ),
      ])
      ..sessionSizes[StudyMode.typing] = 1;

    var vocabularyWasSelected = false;
    expect(
      controller
          .filteredSubjects(StudyMode.typing)
          .any((subject) => subject.id == 100),
      isFalse,
    );
    for (var attempt = 0; attempt < 40; attempt++) {
      controller.startQuiz();
      vocabularyWasSelected |= controller.quizItems.any(
        (item) => item.subject.id == 99,
      );
      if (vocabularyWasSelected) break;
    }

    expect(vocabularyWasSelected, isTrue);
  });

  test('counts filtered question cards and clamps custom session size', () {
    final controller = ReviewerController()
      ..subjects.add(
        const Subject(
          id: 42,
          type: SubjectType.vocabulary,
          level: 1,
          characters: '猫',
          meanings: ['Cat'],
          readings: ['ねこ'],
          contextSentences: [ContextSentence(en: 'A cat.', ja: '猫です。')],
        ),
      )
      ..assignments.add(
        const Assignment(
          id: 42,
          subjectId: 42,
          srsStage: SrsStage.apprentice,
          unlockedAt: null,
        ),
      );

    controller
      ..revealOnSecondMistake = false
      ..showSuccessDetails = false
      ..showEnglishByDefault = true;
    expect(controller.availableItemCount, 1);
    controller.setSessionSize(99);
    expect(controller.sessionSize, 1);
    controller.setSessionSize(0);
    expect(controller.sessionSize, 1);
    controller.startQuiz();
    expect(controller.quizItems, hasLength(2));
    expect(controller.quizConfig.revealOnSecondMiss, isFalse);
    expect(controller.quizConfig.showOther, isFalse);
    expect(controller.quizConfig.showEnglishByDefault, isTrue);
    expect(controller.engine?.config.revealOnSecondMiss, isFalse);

    controller.selectMode(StudyMode.context);
    expect(controller.availableItemCount, 1);
    controller.stages.clear();
    expect(controller.availableItemCount, 0);
    controller.startQuiz();
    expect(controller.isQuizActive, isFalse);
  });
}
