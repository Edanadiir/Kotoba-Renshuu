import 'package:flutter_test/flutter_test.dart';

import 'package:wanikani_reviewer/core/models/quiz_item.dart';
import 'package:wanikani_reviewer/core/models/subject.dart';
import 'package:wanikani_reviewer/features/quiz/domain/quiz_engine.dart';

void main() {
  test('a failed single-item queue stays active until answered correctly', () {
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

    engine.submitAndRecycle(false);
    expect(engine.current?.id, item.id);
    expect(engine.missedIds, {item.id});

    engine.completeCurrent();
    expect(engine.current, isNull);
  });
}
