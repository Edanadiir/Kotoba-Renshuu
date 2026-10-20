import 'package:flutter/widgets.dart';
import 'package:kana_kit/kana_kit.dart';

class KanaInputController extends TextEditingController {
  KanaInputController({super.text}) : _kanaKit = KanaKit();

  final KanaKit _kanaKit;

  void normalizeLive(String rawValue) {
    final normalized = normalizeLiveValue(rawValue, _kanaKit);
    if (normalized == text) return;
    final oldOffset = selection.baseOffset < 0
        ? rawValue.length
        : selection.baseOffset;
    final offset = (oldOffset + normalized.length - rawValue.length).clamp(
      0,
      normalized.length,
    );
    value = value.copyWith(
      text: normalized,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  String normalizeForSubmission() {
    final normalized = _kanaKit.toHiragana(text);
    return normalized.endsWith('n')
        ? '${normalized.substring(0, normalized.length - 1)}ん'
        : normalized;
  }

  static String normalizeLiveValue(String value, KanaKit kanaKit) {
    if (value.isEmpty) return value;
    const nSyllables = {
      'na': 'な',
      'ni': 'に',
      'nu': 'ぬ',
      'ne': 'ね',
      'no': 'の',
      'nya': 'にゃ',
      'nyu': 'にゅ',
      'nyo': 'にょ',
      'nye': 'にぇ',
    };
    for (final entry in nSyllables.entries) {
      if (value.endsWith(entry.key)) {
        final prefix = value.substring(0, value.length - entry.key.length);
        return '${kanaKit.toHiragana(prefix)}${entry.value}';
      }
    }
    if (value.endsWith('ny')) {
      final prefix = value.substring(0, value.length - 2);
      return '${kanaKit.toHiragana(prefix)}ny';
    }
    if (value.endsWith('nn')) {
      final stable = value.substring(0, value.length - 2);
      return '${kanaKit.toHiragana(stable)}ん';
    }
    if (value.endsWith('n') && !value.endsWith('nn')) {
      final stable = value.substring(0, value.length - 1);
      return '${kanaKit.toHiragana(stable)}n';
    }
    return kanaKit.toHiragana(value);
  }
}
