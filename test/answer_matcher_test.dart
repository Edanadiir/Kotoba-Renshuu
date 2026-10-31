import 'package:flutter_test/flutter_test.dart';
import 'package:kotoba_renshuu/features/quiz/domain/answer_matcher.dart';

void main() {
  test('normalizes numeric answers and punctuation', () {
    expect(AnswerMatcher.matches('10 minutes', 'TEN minutes!'), isTrue);
    expect(AnswerMatcher.matches('twenty-one days', '21 days'), isTrue);
    expect(AnswerMatcher.matches('one hundred and five', '105'), isTrue);
  });

  test('accepts small meaning typos only when enabled', () {
    expect(
      AnswerMatcher.matches('Student', 'Studnet', allowTypo: true),
      isTrue,
    );
    expect(AnswerMatcher.matches('Student', 'Studnet'), isFalse);
    expect(AnswerMatcher.matches('cat', 'cut', allowTypo: true), isTrue);
  });

  test('normalizes casing and whitespace', () {
    expect(AnswerMatcher.matches('  New York ', 'new   york'), isTrue);
  });
}
