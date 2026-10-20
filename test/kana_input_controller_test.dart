import 'package:flutter_test/flutter_test.dart';
import 'package:kana_kit/kana_kit.dart';

import 'package:wanikani_reviewer/features/quiz/presentation/kana_input_controller.dart';

void main() {
  final kanaKit = KanaKit();

  test('keeps a trailing n buffered during live conversion', () {
    expect(KanaInputController.normalizeLiveValue('n', kanaKit), 'n');
    expect(KanaInputController.normalizeLiveValue('shin', kanaKit), 'しn');
  });

  test('converts n syllables when their following input is known', () {
    expect(KanaInputController.normalizeLiveValue('na', kanaKit), 'な');
    expect(KanaInputController.normalizeLiveValue('ni', kanaKit), 'に');
    expect(KanaInputController.normalizeLiveValue('nya', kanaKit), 'にゃ');
    expect(KanaInputController.normalizeLiveValue('nn', kanaKit), 'ん');
    expect(KanaInputController.normalizeLiveValue('nya', kanaKit), 'にゃ');
    expect(KanaInputController.normalizeLiveValue('nyu', kanaKit), 'にゅ');
    expect(KanaInputController.normalizeLiveValue('nyo', kanaKit), 'にょ');
    expect(KanaInputController.normalizeLiveValue('nye', kanaKit), 'にぇ');
  });

  test('commits a final single n only on submission', () {
    final controller = KanaInputController(text: 'shin');
    expect(controller.normalizeForSubmission(), 'しん');
  });
}
