import 'dart:math';

import '../data/conjugation_dictionary.dart';
import 'conjugation_models.dart';

class _Row {
  const _Row(this.a, this.i, this.e, this.o);
  final String a;
  final String i;
  final String e;
  final String o;
}

const _godanRows = <String, _Row>{
  'う': _Row('わ', 'い', 'え', 'お'),
  'く': _Row('か', 'き', 'け', 'こ'),
  'ぐ': _Row('が', 'ぎ', 'げ', 'ご'),
  'す': _Row('さ', 'し', 'せ', 'そ'),
  'つ': _Row('た', 'ち', 'て', 'と'),
  'ぬ': _Row('な', 'に', 'ね', 'の'),
  'ぶ': _Row('ば', 'び', 'べ', 'ぼ'),
  'む': _Row('ま', 'み', 'め', 'も'),
  'る': _Row('ら', 'り', 'れ', 'ろ'),
};

// ending -> [te suffix, past suffix]
const _godanTe = <String, List<String>>{
  'う': ['って', 'った'],
  'つ': ['って', 'った'],
  'る': ['って', 'った'],
  'む': ['んで', 'んだ'],
  'ぬ': ['んで', 'んだ'],
  'ぶ': ['んで', 'んだ'],
  'く': ['いて', 'いた'],
  'ぐ': ['いで', 'いだ'],
  'す': ['して', 'した'],
};

/// Stative verbs without a natural potential / passive / causative /
/// volitional form.
const _stativeVerbs = {
  '有る',
  'ある',
  '分かる',
  'わかる',
  '出来る',
  'できる',
  '見える',
  'みえる',
  '足りる',
  'たりる',
  '要る',
};

/// Stems and the "shown" fragments used in explanations for one verb.
class _Stems {
  const _Stems({
    required this.ending,
    required this.neg,
    required this.i,
    required this.e,
    required this.o,
    required this.te,
    required this.past,
    required this.potential,
    required this.passive,
    required this.causative,
    required this.negPart,
    required this.iPart,
    required this.ePart,
    required this.oPart,
    required this.tePart,
    required this.pastPart,
    required this.volSuffix,
    required this.potentialNote,
    required this.passiveNote,
    required this.causativeNote,
    this.potentialAlt,
  });

  final String ending;
  final String neg, i, e, o;
  final String te, past;
  final String potential, passive, causative;
  final String? potentialAlt;
  final String negPart, iPart, ePart, oPart, tePart, pastPart;
  final String volSuffix;
  final String potentialNote, passiveNote, causativeNote;
}

class _Raw {
  const _Raw(this.text, this.explanation, [this.alternatives = const []]);
  final String text;
  final String explanation;
  final List<String> alternatives;
}

/// Pure rule-based conjugation engine.
class ConjugationEngine {
  const ConjugationEngine._();

  static bool isApplicable(VocabEntry entry, ConjugationForm form) {
    if (!form.appliesTo(entry.group)) return false;
    if (_stativeVerbs.contains(entry.kanji) &&
        form.verbOnly &&
        form != ConjugationForm.tai) {
      return false;
    }
    return true;
  }

  static ConjugationResult conjugate(VocabEntry entry, ConjugationForm form) {
    final kana = _compute(entry.kana, entry.group, form, isKanji: false)!;
    final kanji = entry.hasKanji
        ? _compute(entry.kanji, entry.group, form, isKanji: true)!
        : kana;
    return ConjugationResult(
      kana: kana.text,
      kanji: kanji.text,
      explanation: kana.explanation,
      alternativesKana: kana.alternatives,
      alternativesKanji: entry.hasKanji ? kanji.alternatives : const [],
    );
  }

  /// Four shuffled kana options: the correct one plus plausible wrong ones.
  static List<String> buildChoices(
    VocabEntry entry,
    ConjugationForm form,
    Random random,
  ) {
    final result = conjugate(entry, form);
    final correct = result.acceptedKana;
    final wrong = <String>[];
    void add(String? value) {
      if (value != null &&
          value.isNotEmpty &&
          !correct.contains(value) &&
          !wrong.contains(value)) {
        wrong.add(value);
      }
    }

    // Typical mistake: conjugating with the wrong group's rules.
    switch (entry.group) {
      case WordGroup.godan when entry.kana.endsWith('る'):
        add(
          _compute(entry.kana, WordGroup.ichidan, form, isKanji: false)?.text,
        );
      case WordGroup.ichidan:
        add(_compute(entry.kana, WordGroup.godan, form, isKanji: false)?.text);
      case WordGroup.iAdjective:
        add(
          _compute(
            entry.kana,
            WordGroup.naAdjective,
            form,
            isKanji: false,
          )?.text,
        );
      default:
    }
    final otherForms =
        ConjugationForm.values
            .where((other) => other != form && isApplicable(entry, other))
            .toList()
          ..shuffle(random);
    for (final other in otherForms) {
      if (wrong.length >= 3) break;
      add(conjugate(entry, other).kana);
    }
    final fillers =
        conjugationDictionary
            .where((other) => other.group == entry.group && other != entry)
            .toList()
          ..shuffle(random);
    for (final other in fillers) {
      if (wrong.length >= 3) break;
      if (isApplicable(other, form)) add(conjugate(other, form).kana);
    }
    return [result.kana, ...wrong.take(3)]..shuffle(random);
  }

  static _Raw? _compute(
    String word,
    WordGroup group,
    ConjugationForm form, {
    required bool isKanji,
  }) {
    if (group.isVerb) {
      final stems = _verbStems(word, group);
      return stems == null ? null : _verb(word, form, stems);
    }
    return group == WordGroup.iAdjective
        ? _iAdjective(word, form, isKanji)
        : _naAdjective(word, form);
  }

  static _Stems? _verbStems(String word, WordGroup group) {
    if (word.length < 2) return null;
    switch (group) {
      case WordGroup.godan:
        final end = word[word.length - 1];
        final row = _godanRows[end];
        final tePair = _godanTe[end];
        if (row == null || tePair == null) return null;
        final base = word.substring(0, word.length - 1);
        final isIku = word == 'いく' || word.endsWith('行く');
        final teSuffix = isIku ? 'って' : tePair[0];
        final pastSuffix = isIku ? 'った' : tePair[1];
        final note = isIku ? ' (いく is irregular)' : '';
        return _Stems(
          ending: end,
          neg: base + row.a,
          i: base + row.i,
          e: base + row.e,
          o: base + row.o,
          te: base + teSuffix,
          past: base + pastSuffix,
          potential: '${base + row.e}る',
          passive: '${base + row.a}れる',
          causative: '${base + row.a}せる',
          negPart: row.a,
          iPart: row.i,
          ePart: row.e,
          oPart: row.o,
          tePart: '$teSuffix$note',
          pastPart: '$pastSuffix$note',
          volSuffix: 'う',
          potentialNote: '$end → ${row.e} + る',
          passiveNote: '$end → ${row.a} + れる',
          causativeNote: '$end → ${row.a} + せる',
        );
      case WordGroup.ichidan:
        if (!word.endsWith('る')) return null;
        final base = word.substring(0, word.length - 1);
        return _ichidanLike(
          'る',
          neg: base,
          i: base,
          e: '$baseれ',
          negPart: '',
          iPart: '',
          ePart: 'れ',
          kuru: false,
        );
      case WordGroup.irregular:
        if (word.endsWith('する')) {
          final p = word.substring(0, word.length - 2);
          return _Stems(
            ending: 'する',
            neg: '$pし',
            i: '$pし',
            e: '$pすれ',
            o: '$pし',
            te: '$pして',
            past: '$pした',
            potential: '$pできる',
            passive: '$pされる',
            causative: '$pさせる',
            negPart: 'し',
            iPart: 'し',
            ePart: 'すれ',
            oPart: 'し',
            tePart: 'して',
            pastPart: 'した',
            volSuffix: 'よう',
            potentialNote: 'する → できる (suppletive form)',
            passiveNote: 'する → さ + れる',
            causativeNote: 'する → さ + せる',
          );
        }
        if (word.endsWith('来る')) {
          final base = word.substring(0, word.length - 1);
          return _ichidanLike(
            '来る',
            neg: base,
            i: base,
            e: '$baseれ',
            negPart: '来 (こ)',
            iPart: '来 (き)',
            ePart: '来れ (くれ)',
            kuru: true,
          );
        }
        if (word.endsWith('くる')) {
          final p = word.substring(0, word.length - 2);
          return _ichidanLike(
            'くる',
            neg: '$pこ',
            i: '$pき',
            e: '$pくれ',
            negPart: 'こ',
            iPart: 'き',
            ePart: 'くれ',
            kuru: true,
          );
        }
        return null;
      default:
        return null;
    }
  }

  // Ichidan verbs and 来る/くる share their endings; only the stems differ.
  static _Stems _ichidanLike(
    String ending, {
    required String neg,
    required String i,
    required String e,
    required String negPart,
    required String iPart,
    required String ePart,
    required bool kuru,
  }) {
    return _Stems(
      ending: ending,
      neg: neg,
      i: i,
      e: e,
      o: neg,
      te: '$iて',
      past: '$iた',
      potential: '$negられる',
      potentialAlt: '$negれる',
      passive: '$negられる',
      causative: '$negさせる',
      negPart: negPart,
      iPart: iPart,
      ePart: ePart,
      oPart: negPart,
      tePart: 'て',
      pastPart: 'た',
      volSuffix: 'よう',
      potentialNote: kuru
          ? '$ending → こ + られる (colloquial: これる)'
          : 'る → られる (colloquial: れる)',
      passiveNote: kuru ? '$ending → こ + られる' : 'る → られる',
      causativeNote: kuru ? '$ending → こ + させる' : 'る → させる',
    );
  }

  static _Raw _verb(String word, ConjugationForm form, _Stems s) {
    String ex(String part, String suffix) =>
        '${s.ending} → ${part.isEmpty ? '' : '$part + '}$suffix';
    switch (form) {
      case ConjugationForm.plainPresent:
        return _Raw(word, 'Dictionary form is the plain present.');
      case ConjugationForm.plainPast:
        return _Raw(s.past, '${s.ending} → ${s.pastPart}');
      case ConjugationForm.plainNegative:
        if (word == 'ある' || word == '有る') {
          return const _Raw('ない', 'ある is irregular: the negative is ない.');
        }
        return _Raw('${s.neg}ない', ex(s.negPart, 'ない'));
      case ConjugationForm.politePresent:
        return _Raw('${s.i}ます', ex(s.iPart, 'ます'));
      case ConjugationForm.politePast:
        return _Raw('${s.i}ました', ex(s.iPart, 'ました'));
      case ConjugationForm.politeNegative:
        return _Raw('${s.i}ません', ex(s.iPart, 'ません'));
      case ConjugationForm.te:
        return _Raw(s.te, '${s.ending} → ${s.tePart}');
      case ConjugationForm.potential:
        return _Raw(
          s.potential,
          s.potentialNote,
          s.potentialAlt == null ? const [] : [s.potentialAlt!],
        );
      case ConjugationForm.passive:
        return _Raw(s.passive, s.passiveNote);
      case ConjugationForm.causative:
        return _Raw(s.causative, s.causativeNote);
      case ConjugationForm.volitional:
        return _Raw('${s.o}${s.volSuffix}', ex(s.oPart, s.volSuffix));
      case ConjugationForm.tai:
        return _Raw('${s.i}たい', ex(s.iPart, 'たい'));
      case ConjugationForm.conditionalBa:
        return _Raw('${s.e}ば', ex(s.ePart, 'ば'));
      case ConjugationForm.conditionalTara:
        return _Raw('${s.past}ら', 'plain past (${s.past}) + ら');
    }
  }

  static _Raw _iAdjective(String word, ConjugationForm form, bool isKanji) {
    if (!word.endsWith('い')) return const _Raw('', '');
    // いい is irregular: the stem is よ- except in the plain present.
    final irregular = !isKanji && word == 'いい';
    final stem = irregular ? 'よ' : word.substring(0, word.length - 1);
    final note = irregular ? ' (いい → よ-: irregular stem)' : '';
    switch (form) {
      case ConjugationForm.plainPresent:
        return _Raw(word, 'Dictionary form is the plain present.');
      case ConjugationForm.plainPast:
        return _Raw('$stemかった', 'い → かった$note');
      case ConjugationForm.plainNegative:
        return _Raw('$stemくない', 'い → くない$note');
      case ConjugationForm.politePresent:
        return _Raw('$wordです', 'dictionary form + です');
      case ConjugationForm.politePast:
        return _Raw('$stemかったです', 'い → かった + です$note');
      case ConjugationForm.politeNegative:
        return _Raw('$stemくないです', 'い → くない + です$note', ['$stemくありません']);
      case ConjugationForm.te:
        return _Raw('$stemくて', 'い → くて$note');
      case ConjugationForm.conditionalBa:
        return _Raw('$stemければ', 'い → ければ$note');
      case ConjugationForm.conditionalTara:
        return _Raw('$stemかったら', 'い → かったら$note');
      default:
        return const _Raw('', '');
    }
  }

  static _Raw _naAdjective(String word, ConjugationForm form) {
    switch (form) {
      case ConjugationForm.plainPresent:
        return _Raw('$wordだ', 'stem + だ');
      case ConjugationForm.plainPast:
        return _Raw('$wordだった', 'stem + だった');
      case ConjugationForm.plainNegative:
        return _Raw('$wordではない', 'stem + ではない (casual: じゃない)', ['$wordじゃない']);
      case ConjugationForm.politePresent:
        return _Raw('$wordです', 'stem + です');
      case ConjugationForm.politePast:
        return _Raw('$wordでした', 'stem + でした');
      case ConjugationForm.politeNegative:
        return _Raw('$wordではありません', 'stem + ではありません (casual: じゃありません)', [
          '$wordじゃありません',
        ]);
      case ConjugationForm.te:
        return _Raw('$wordで', 'stem + で');
      case ConjugationForm.conditionalBa:
        return _Raw('$wordなら', 'stem + なら (also ならば)', ['$wordならば']);
      case ConjugationForm.conditionalTara:
        return _Raw('$wordだったら', 'stem + だったら');
      default:
        return const _Raw('', '');
    }
  }
}
