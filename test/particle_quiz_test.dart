import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoba_renshuu/features/particles/presentation/particle_quiz_screen.dart';
import 'package:kotoba_renshuu/models/particle_questions.dart';
import 'package:kotoba_renshuu/models/particle_quiz.dart';

void main() {
  test('sentence bank is well formed', () {
    expect(particleQuestions.length, greaterThanOrEqualTo(40));
    expect(
      particleQuestions.map((q) => q.id).toSet().length,
      particleQuestions.length,
    );
    for (final q in particleQuestions) {
      expect(
        ParticleQuestion.blank.allMatches(q.sentenceWithBlank).length,
        1,
        reason: q.id,
      );
      expect(q.options.length, 4, reason: q.id);
      expect(q.options.toSet().length, 4, reason: q.id);
      expect(q.options, contains(q.correctParticle), reason: q.id);
      expect(q.englishTranslation, isNotEmpty);
      expect(
        ParticleQuestion.blank.allMatches(q.sentenceKana).length,
        1,
        reason: '${q.id} kana',
      );
      expect(q.filledKana.contains('___'), isFalse);
      expect(q.explanation, isNotEmpty);
    }
    const covered = ['は', 'が', 'を', 'に', 'で', 'へ', 'と', 'も', 'から', 'まで', 'より'];
    for (final p in covered) {
      expect(
        particleQuestions.any((q) => q.correctParticle == p),
        isTrue,
        reason: p,
      );
    }
  });

  testWidgets('quiz hides translation, answers by key and advances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ParticleQuizScreen())),
    );
    final n5 = particleQuestionsFor(ParticleLevelFilter.n5).length;
    await tester.tap(find.text('N5'));
    await tester.pump();
    await tester.ensureVisible(find.text('All ($n5)'));
    await tester.tap(find.text('All ($n5)'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start practice'));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of $n5  ·  0 correct'), findsOneWidget);
    expect(find.text('Show translation (H)'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(find.text('Show translation (H)'), findsNothing);
    expect(
      find.textContaining('Not quite.').evaluate().length +
          find.textContaining('Correct!').evaluate().length,
      1,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.textContaining('Card 2 of $n5'), findsOneWidget);
  });
}
