import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoba_renshuu/features/onomatopoeia/presentation/onomatopoeia_screen.dart';
import 'package:kotoba_renshuu/models/onomatopoeia_item.dart';
import 'package:kotoba_renshuu/models/onomatopoeia_items.dart';

void main() {
  test('onomatopoeia bank is well formed', () {
    expect(onomatopoeiaItems.length, greaterThanOrEqualTo(35));
    expect(
      onomatopoeiaItems.map((i) => i.id).toSet().length,
      onomatopoeiaItems.length,
    );
    final wordsByCategory = {
      for (final category in OnomatopoeiaCategory.values)
        category: onomatopoeiaItems
            .where((i) => i.category == category)
            .map((i) => i.word)
            .toSet(),
    };
    for (final category in OnomatopoeiaCategory.values) {
      expect(wordsByCategory[category]!.length, greaterThanOrEqualTo(10));
    }
    for (final i in onomatopoeiaItems) {
      expect(
        OnomatopoeiaItem.blank.allMatches(i.sentenceKanji).length,
        1,
        reason: i.id,
      );
      expect(
        OnomatopoeiaItem.blank.allMatches(i.sentenceKana).length,
        1,
        reason: '${i.id} kana',
      );
      expect(i.options.length, 4, reason: i.id);
      expect(i.options.toSet().length, 4, reason: i.id);
      expect(i.options, contains(i.correctOption), reason: i.id);
      expect(i.correctOption, i.word, reason: i.id);
      for (final option in i.options) {
        expect(wordsByCategory[i.category], contains(option), reason: i.id);
      }
      expect(i.englishSentence, isNotEmpty);
      expect(i.wordMeaning, isNotEmpty);
      expect(i.explanation, isNotEmpty);
    }
  });

  testWidgets('quiz hides translation, answers by key and advances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OnomatopoeiaScreen())),
    );
    final total = onomatopoeiaItems.length;
    await tester.ensureVisible(find.text('All ($total)'));
    await tester.tap(find.text('All ($total)'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start practice'));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    expect(find.text('Card 1 of $total  ·  0 correct'), findsOneWidget);
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
    expect(find.textContaining('Card 2 of $total'), findsOneWidget);
  });

  testWidgets('category chips filter the available sentences', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OnomatopoeiaScreen())),
    );
    final sounds = onomatopoeiaFor({OnomatopoeiaCategory.giseigoGiongo}).length;
    await tester.tap(find.textContaining('Gitaigo'));
    await tester.pump();
    await tester.tap(find.textContaining('Gijōgo'));
    await tester.pump();
    expect(find.text('$sounds sentences available'), findsOneWidget);
  });
}
