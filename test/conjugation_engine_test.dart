import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoba_renshuu/features/conjugation/data/conjugation_dictionary.dart';
import 'package:kotoba_renshuu/features/conjugation/domain/conjugation_engine.dart';
import 'package:kotoba_renshuu/features/conjugation/domain/conjugation_models.dart';

VocabEntry word(String kanji) =>
    conjugationDictionary.firstWhere((entry) => entry.kanji == kanji);

String kana(String kanji, ConjugationForm form) =>
    ConjugationEngine.conjugate(word(kanji), form).kana;

void main() {
  test('godan verbs', () {
    expect(kana('買う', ConjugationForm.politePast), 'かいました');
    expect(kana('買う', ConjugationForm.plainNegative), 'かわない');
    expect(kana('書く', ConjugationForm.te), 'かいて');
    expect(kana('行く', ConjugationForm.te), 'いって');
    expect(kana('泳ぐ', ConjugationForm.plainPast), 'およいだ');
    expect(kana('飲む', ConjugationForm.te), 'のんで');
    expect(kana('話す', ConjugationForm.passive), 'はなされる');
    expect(kana('待つ', ConjugationForm.causative), 'またせる');
    expect(kana('帰る', ConjugationForm.volitional), 'かえろう');
    expect(kana('読む', ConjugationForm.potential), 'よめる');
    expect(kana('遊ぶ', ConjugationForm.tai), 'あそびたい');
    expect(kana('有る', ConjugationForm.plainNegative), 'ない');
    expect(kana('書く', ConjugationForm.conditionalTara), 'かいたら');
    expect(kana('書く', ConjugationForm.conditionalBa), 'かけば');
  });

  test('ichidan and irregular verbs', () {
    expect(kana('食べる', ConjugationForm.te), 'たべて');
    expect(kana('食べる', ConjugationForm.passive), 'たべられる');
    expect(kana('食べる', ConjugationForm.volitional), 'たべよう');
    expect(kana('食べる', ConjugationForm.conditionalBa), 'たべれば');
    expect(
      ConjugationEngine.conjugate(
        word('食べる'),
        ConjugationForm.potential,
      ).acceptedKana,
      containsAll(['たべられる', 'たべれる']),
    );
    expect(kana('する', ConjugationForm.passive), 'される');
    expect(kana('勉強する', ConjugationForm.potential), 'べんきょうできる');
    final kuru = ConjugationEngine.conjugate(
      word('来る'),
      ConjugationForm.plainNegative,
    );
    expect(kuru.kana, 'こない');
    expect(kuru.kanji, '来ない');
    expect(kana('来る', ConjugationForm.politeNegative), 'きません');
    expect(kana('来る', ConjugationForm.conditionalBa), 'くれば');
    expect(
      ConjugationEngine.conjugate(word('来る'), ConjugationForm.te).kanji,
      '来て',
    );
  });

  test('adjectives', () {
    expect(kana('高い', ConjugationForm.plainNegative), 'たかくない');
    expect(kana('高い', ConjugationForm.politePast), 'たかかったです');
    expect(kana('良い', ConjugationForm.plainPast), 'よかった');
    expect(
      ConjugationEngine.conjugate(word('良い'), ConjugationForm.plainPast).kanji,
      '良かった',
    );
    expect(kana('静か', ConjugationForm.plainNegative), 'しずかではない');
    expect(kana('静か', ConjugationForm.te), 'しずかで');
    expect(
      ConjugationEngine.conjugate(
        word('静か'),
        ConjugationForm.plainPresent,
      ).acceptedKana,
      contains('しずかだ'),
    );
  });

  test('every applicable pair conjugates and yields 4 distinct choices', () {
    final random = Random(1);
    for (final entry in conjugationDictionary) {
      for (final form in ConjugationForm.values) {
        if (!ConjugationEngine.isApplicable(entry, form)) continue;
        final result = ConjugationEngine.conjugate(entry, form);
        expect(result.kana, isNotEmpty, reason: '${entry.kanji} $form');
        expect(result.explanation, isNotEmpty);
        final choices = ConjugationEngine.buildChoices(entry, form, random);
        expect(choices.toSet().length, choices.length);
        expect(choices, contains(result.kana));
        expect(choices.length, 4, reason: '${entry.kanji} $form');
      }
    }
  });
}
