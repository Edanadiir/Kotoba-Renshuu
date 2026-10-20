import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanikani_reviewer/features/transitivity/presentation/transitivity_screen.dart';
import 'package:wanikani_reviewer/models/transitivity_pairs.dart';

void main() {
  testWidgets('offline setup starts an identification session', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TransitivityScreen(learnedWords: null)),
      ),
    );

    expect(find.text('All Built-in Words'), findsOneWidget);
    expect(find.text('Unlocked on WaniKani'), findsOneWidget);
    expect(
      find.text('${transitivityPairs.length} verb pairs available'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RadioListTile<TransitivitySource>>(
            find.byType(RadioListTile<TransitivitySource>).last,
          )
          .enabled,
      isFalse,
    );

    await tester.ensureVisible(find.text('Start practice'));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    expect(find.text('Identification'), findsOneWidget);
    expect(find.text('Transitive'), findsOneWidget);
    expect(find.text('Intransitive'), findsOneWidget);

    // The English gloss stays hidden until the hint is requested.
    expect(find.textContaining('to '), findsNothing);
    await tester.tap(find.text('Show meaning (H)'));
    await tester.pump();
    expect(find.textContaining('to '), findsOneWidget);
    expect(find.text('Show meaning (H)'), findsNothing);
  });

  testWidgets('All chip sets the session size to every available pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TransitivityScreen(learnedWords: {'開く'})),
      ),
    );

    expect(find.text('Game mode'), findsNothing);
    expect(find.text('Pair Recall'), findsNothing);

    await tester.ensureVisible(find.text('All (${transitivityPairs.length})'));
    await tester.tap(find.text('All (${transitivityPairs.length})'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start practice'));
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    expect(
      find.text('Card 1 of ${transitivityPairs.length}  ·  0 correct'),
      findsOneWidget,
    );
  });
}
