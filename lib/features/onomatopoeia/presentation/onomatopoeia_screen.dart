import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/onomatopoeia_item.dart';
import '../../../models/onomatopoeia_items.dart';

const _ink = Color(0xFF16212B);
const _muted = Color(0xFF73808A);
const _kanaColor = Color(0xFF9AA5AD);
const _accent = Color(0xFF00AAFF);
const _green = Color(0xFF16866A);
const _red = Color(0xFFC44738);

class OnomatopoeiaQuizConfig {
  const OnomatopoeiaQuizConfig({required this.items, this.showKana = true});

  final List<OnomatopoeiaItem> items;
  final bool showKana;
}

List<OnomatopoeiaItem> onomatopoeiaFor(Set<OnomatopoeiaCategory> categories) =>
    onomatopoeiaItems
        .where((item) => categories.contains(item.category))
        .toList();

class OnomatopoeiaScreen extends StatefulWidget {
  const OnomatopoeiaScreen({super.key});

  @override
  State<OnomatopoeiaScreen> createState() => _OnomatopoeiaScreenState();
}

class _OnomatopoeiaScreenState extends State<OnomatopoeiaScreen> {
  OnomatopoeiaQuizConfig? activeConfig;

  @override
  Widget build(BuildContext context) {
    final config = activeConfig;
    if (config == null) {
      return OnomatopoeiaSetupScreen(
        onStart: (value) => setState(() => activeConfig = value),
      );
    }
    return OnomatopoeiaQuestionsScreen(
      config: config,
      onExit: () => setState(() => activeConfig = null),
    );
  }
}

class OnomatopoeiaSetupScreen extends StatefulWidget {
  const OnomatopoeiaSetupScreen({required this.onStart, super.key});

  final ValueChanged<OnomatopoeiaQuizConfig> onStart;

  @override
  State<OnomatopoeiaSetupScreen> createState() =>
      _OnomatopoeiaSetupScreenState();
}

class _OnomatopoeiaSetupScreenState extends State<OnomatopoeiaSetupScreen> {
  final customCount = TextEditingController();
  final random = Random();
  Set<OnomatopoeiaCategory> categories = {...OnomatopoeiaCategory.values};
  int sessionSize = 10;
  bool customCountActive = false;
  bool allSelected = false;
  bool showKana = true;

  @override
  void dispose() {
    customCount.dispose();
    super.dispose();
  }

  List<OnomatopoeiaItem> get available => onomatopoeiaFor(categories);

  int? get parsedCustomCount {
    final count = int.tryParse(customCount.text.trim());
    return count != null && count > 0 ? count : null;
  }

  int get selectedCount {
    if (allSelected) return available.length;
    final custom = parsedCustomCount;
    return (customCountActive ? custom ?? 10 : sessionSize).clamp(
      1,
      available.length,
    );
  }

  void toggleCategory(OnomatopoeiaCategory category) {
    final next = {...categories};
    if (!next.remove(category)) next.add(category);
    // An empty selection would leave nothing to practice.
    categories = next.isEmpty ? {...OnomatopoeiaCategory.values} : next;
  }

  void start() {
    final pool = available.toList()..shuffle(random);
    widget.onStart(
      OnomatopoeiaQuizConfig(
        items: pool.take(selectedCount).toList(),
        showKana: showKana,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
          : const EdgeInsets.fromLTRB(42, 38, 42, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Onomatopoeia Quiz',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the sound or mimetic word (オノマトペ) that fits the '
                'sentence.',
                style: TextStyle(color: _muted, fontSize: 15),
              ),
              const SizedBox(height: 28),
              _Section(
                title: 'Categories',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final category in OnomatopoeiaCategory.values)
                      FilterChip(
                        label: Text(
                          '${category.label} (${category.description})',
                        ),
                        selected: categories.contains(category),
                        onSelected: (_) =>
                            setState(() => toggleCategory(category)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Furigana',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: showKana,
                  onChanged: (value) => setState(() => showKana = value),
                  title: const Text('Show Furigana / Kana readings'),
                  subtitle: const Text(
                    'Turn off to practice reading the kanji yourself.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Session size',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final size in const [10, 20])
                      ChoiceChip(
                        label: Text('$size cards'),
                        selected:
                            !customCountActive &&
                            !allSelected &&
                            sessionSize == size,
                        onSelected: (_) => setState(() {
                          sessionSize = size;
                          customCountActive = false;
                          allSelected = false;
                          customCount.clear();
                        }),
                      ),
                    ChoiceChip(
                      label: Text('All (${available.length})'),
                      selected: allSelected,
                      onSelected: (_) => setState(() {
                        allSelected = true;
                        customCountActive = false;
                        customCount.clear();
                      }),
                    ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: customCount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Custom count',
                          hintText: '1 – ${available.length}',
                          isDense: true,
                          errorText:
                              customCountActive && parsedCustomCount == null
                              ? 'Enter at least 1'
                              : null,
                        ),
                        onChanged: (_) => setState(() {
                          customCountActive = customCount.text.isNotEmpty;
                          if (customCountActive) allSelected = false;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: available.isEmpty ? null : start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start practice'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${available.length} sentences available',
                      style: const TextStyle(color: _muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnomatopoeiaQuestionsScreen extends StatefulWidget {
  const OnomatopoeiaQuestionsScreen({
    required this.config,
    required this.onExit,
    super.key,
  });

  final OnomatopoeiaQuizConfig config;
  final VoidCallback onExit;

  @override
  State<OnomatopoeiaQuestionsScreen> createState() =>
      _OnomatopoeiaQuestionsScreenState();
}

class _OnomatopoeiaQuestionsScreenState
    extends State<OnomatopoeiaQuestionsScreen> {
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];
  static const _numpadKeys = [
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
  ];

  final random = Random();
  final focusNode = FocusNode(debugLabel: 'onomatopoeia shortcuts');
  late final List<List<String>> shuffledOptions;
  late bool showKana = widget.config.showKana;
  int index = 0;
  int correctCount = 0;
  String? selected;
  bool translationVisible = false;

  List<OnomatopoeiaItem> get items => widget.config.items;
  OnomatopoeiaItem get item => items[index];
  bool get answered => selected != null;

  @override
  void initState() {
    super.initState();
    shuffledOptions = [
      for (final entry in items) entry.options.toList()..shuffle(random),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void _choose(String option) {
    if (answered) return;
    setState(() {
      selected = option;
      if (option == item.correctOption) correctCount++;
    });
  }

  void _advance() {
    if (!answered) return;
    setState(() {
      index++;
      selected = null;
      translationVisible = false;
    });
    focusNode.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || index >= items.length) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (answered) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        _advance();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyH) {
      setState(() => translationVisible = true);
      return KeyEventResult.handled;
    }
    for (var i = 0; i < 4; i++) {
      if (key == _digitKeys[i] || key == _numpadKeys[i]) {
        _choose(shuffledOptions[index][i]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Color _optionColor(String option) {
    if (!answered) return _accent;
    if (option == item.correctOption) return _green;
    if (option == selected) return _red;
    return const Color(0xFFB7C0C7);
  }

  InlineSpan _blankSpan(bool correct) => TextSpan(
    text: answered ? item.correctOption : '[ ＿＿ ]',
    style: TextStyle(
      color: answered ? (correct ? _green : _red) : _accent,
      decoration: TextDecoration.underline,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (index >= items.length) return _buildSummary();
    final compact = MediaQuery.sizeOf(context).width < 700;
    final (before, after) = item.sentenceParts;
    final (kanaBefore, kanaAfter) = item.kanaParts;
    final correct = selected == item.correctOption;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: _handleKey,
      child: SingleChildScrollView(
        padding: compact
            ? const EdgeInsets.fromLTRB(16, 20, 16, 28)
            : const EdgeInsets.fromLTRB(42, 34, 42, 42),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Onomatopoeia Quiz',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => showKana = !showKana),
                      icon: const Icon(Icons.translate_rounded, size: 18),
                      label: Text('Kana reading: ${showKana ? 'On' : 'Off'}'),
                    ),
                    TextButton.icon(
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Setup'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (index + 1) / items.length,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  'Card ${index + 1} of ${items.length}  ·  '
                  '$correctCount correct',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 22),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 22 : 36),
                      child: Column(
                        children: [
                          const Text(
                            'Choose the fitting onomatopoeia',
                            style: TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (showKana) ...[
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: _kanaColor,
                                  fontSize: compact ? 15 : 19,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(text: kanaBefore),
                                  _blankSpan(correct),
                                  TextSpan(text: kanaAfter),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: _ink,
                                fontSize: compact ? 26 : 34,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(text: before),
                                _blankSpan(correct),
                                TextSpan(text: after),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (translationVisible || answered)
                            Text(
                              item.englishSentence,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 16,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => translationVisible = true),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('Show translation (H)'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: compact
                            ? (MediaQuery.sizeOf(context).width - 32 - 12) / 2
                            : 205,
                        child: FilledButton(
                          onPressed: answered
                              ? null
                              : () => _choose(shuffledOptions[index][i]),
                          style: FilledButton.styleFrom(
                            backgroundColor: _optionColor(
                              shuffledOptions[index][i],
                            ),
                            disabledBackgroundColor: _optionColor(
                              shuffledOptions[index][i],
                            ),
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            shuffledOptions[index][i],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '1–4: choose    H: show translation    Enter: next',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                if (answered) ...[
                  const SizedBox(height: 18),
                  _Feedback(item: item, correct: correct, showKana: showKana),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _advance,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        index + 1 == items.length ? 'Finish' : 'Next  (Enter)',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final percent = (correctCount / items.length * 100).round();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: _accent,
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Practice complete',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$correctCount / ${items.length} correct  ·  $percent%',
                    style: const TextStyle(color: _muted, fontSize: 18),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: widget.onExit,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Practice again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.item,
    required this.correct,
    required this.showKana,
  });

  final OnomatopoeiaItem item;
  final bool correct;
  final bool showKana;

  @override
  Widget build(BuildContext context) => Card(
    color: correct ? const Color(0xFFE8F6ED) : const Color(0xFFFFF0EE),
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              correct ? 'Correct!' : 'Not quite.',
              style: TextStyle(
                color: correct ? _green : _red,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            if (showKana)
              Text(
                item.filledKana,
                style: const TextStyle(color: _kanaColor, fontSize: 15),
              ),
            Text(
              item.filledSentence,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.englishSentence,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '${item.word} – ${item.wordMeaning}',
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.explanation,
              style: const TextStyle(color: _ink, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              item.category.label,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}
