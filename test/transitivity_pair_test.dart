import 'package:flutter_test/flutter_test.dart';
import 'package:wanikani_reviewer/models/transitivity_pair.dart';
import 'package:wanikani_reviewer/models/transitivity_pairs.dart';

void main() {
  TransitivityPair byId(String id) =>
      transitivityPairs.firstWhere((entry) => entry.id == id);

  test('built-in dictionary has 60+ unique pairs with natural examples', () {
    expect(transitivityPairs.length, greaterThanOrEqualTo(60));
    expect(
      transitivityPairs.map((pair) => pair.id).toSet(),
      hasLength(transitivityPairs.length),
    );
    for (final pair in transitivityPairs) {
      expect(pair.transitiveExample, isNotNull, reason: pair.id);
      expect(pair.intransitiveExample, isNotNull, reason: pair.id);
      expect(pair.transitiveExample, contains('を'), reason: pair.id);
    }
  });

  test('examples are context specific, not a door template', () {
    expect(byId('finish').transitiveExample, '仕事を終える');
    expect(byId('finish').intransitiveExample, '授業が終わる');
    expect(byId('wake').transitiveExample, '子供を起こす');
    expect(byId('wake').intransitiveExample, '子供が起きる');
    expect(byId('close').transitiveExample, 'ドアを閉める');
    expect(byId('close').intransitiveExample, 'ドアが閉まる');
    final doorExamples = transitivityPairs.where(
      (pair) => pair.transitiveExample!.startsWith('ドア'),
    );
    expect(
      doorExamples.map((pair) => pair.id),
      unorderedEquals(['open', 'close']),
    );
  });

  test('opening pair contains the expected forms and meanings', () {
    final pair = byId('open');

    expect(pair.transitiveKanji, '開ける');
    expect(pair.transitiveKana, 'あける');
    expect(pair.intransitiveKanji, '開く');
    expect(pair.intransitiveKana, 'あく');
    expect(pair.transitiveMeaning, contains('open'));
    expect(pair.intransitiveMeaning, contains('open'));
  });
}
