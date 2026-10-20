import 'package:flutter_test/flutter_test.dart';

import 'package:wanikani_reviewer/core/models/quiz_item.dart';
import 'package:wanikani_reviewer/core/models/subject.dart';
import 'package:wanikani_reviewer/features/quiz/domain/quiz_engine.dart';

void main() {
  test('second miss stays visible until Next recycles the card', () {
    const firstSubject = Subject(
      id: 1,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '学生',
      meanings: ['Student'],
      readings: ['がくせい'],
    );
    const secondSubject = Subject(
      id: 2,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '先生',
      meanings: ['Teacher'],
      readings: ['せんせい'],
    );
    final first = QuizItem(
      id: '1:meaning',
      subject: firstSubject,
      kind: QuestionKind.meaning,
    );
    final second = QuizItem(
      id: '2:meaning',
      subject: secondSubject,
      kind: QuestionKind.meaning,
    );
    final engine = QuizEngine.restore(
      queue: [first, second],
      completed: {},
      missed: {},
      firstAttemptCorrect: {},
    );

    engine.failAndRecycleCurrent('Learner');

    expect(engine.current?.id, second.id);

    engine.failAndRecycleCurrent('Student');
    expect(engine.current?.id, first.id);

    engine.recordWrongAnswer('Pupil');
    expect(engine.incorrectAttemptsFor(first.id), 2);
    expect(engine.current?.id, first.id);

    engine.submitAndRecycle(false);
    expect(engine.current?.id, second.id);
    expect(engine.remainingIds, [second.id, first.id]);
  });

  test('failed choice advances and places the card at the queue tail', () {
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
    const nextSubject = Subject(
      id: 2,
      type: SubjectType.vocabulary,
      level: 1,
      characters: '先生',
      meanings: ['Teacher'],
      readings: ['せんせい'],
    );
    final nextItem = QuizItem(
      id: '2:meaning',
      subject: nextSubject,
      kind: QuestionKind.meaning,
    );
    final engine = QuizEngine.restore(
      queue: [item, nextItem],
      completed: {},
      missed: {},
      firstAttemptCorrect: {},
    );

    engine.failAndRecycleCurrent('Teacher');

    expect(engine.current?.id, nextItem.id);
    expect(engine.remainingIds, [nextItem.id, item.id]);
    expect(engine.missedIds, {item.id});
    expect(engine.wrongAnswersFor(item.id), {'Teacher'});

    engine.completeCurrent();
    expect(engine.current?.id, item.id);
  });
}
