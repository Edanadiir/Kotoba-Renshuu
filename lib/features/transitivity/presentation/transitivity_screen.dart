import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/transitivity_pair.dart';
import '../../../models/transitivity_pairs.dart';
import '../domain/learned_pairs.dart';

const _ink = Color(0xFF16212B);
const _muted = Color(0xFF73808A);
const _accent = Color(0xFF00AAFF);

enum TransitivitySource { allBuiltIn, unlocked }

class TransitivityConfig {
  const TransitivityConfig({required this.pairs, required this.sessionSize});

  /// Pairs selected by the source filter for this session.
  final List<TransitivityPair> pairs;
  final int sessionSize;
}

class TransitivityScreen extends StatefulWidget {
  /// [learnedWords] holds the WaniKani vocabulary the user has started;
  /// null means no synced data, which disables the learned filter.
  const TransitivityScreen({required this.learnedWords, super.key});

  final Set<String>? learnedWords;

  @override
  State<TransitivityScreen> createState() => _TransitivityScreenState();
}

class _TransitivityScreenState extends State<TransitivityScreen> {
  TransitivityConfig? activeConfig;

  @override
  Widget build(BuildContext context) {
    final config = activeConfig;
    if (config == null) {
      return TransitivitySetupScreen(
        learnedWords: widget.learnedWords,
        onStart: (value) => setState(() => activeConfig = value),
      );
    }
    return TransitivityQuizScreen(
      config: config,
      onExit: () => setState(() => activeConfig = null),
    );
  }
}

class TransitivitySetupScreen extends StatefulWidget {
  const TransitivitySetupScreen({
    required this.learnedWords,
    required this.onStart,
    super.key,
  });

  final Set<String>? learnedWords;
  final ValueChanged<TransitivityConfig> onStart;

  @override
  State<TransitivitySetupScreen> createState() =>
      _TransitivitySetupScreenState();
}

class _TransitivitySetupScreenState extends State<TransitivitySetupScreen> {
  final customCount = TextEditingController();
  TransitivitySource source = TransitivitySource.allBuiltIn;
  LearnedRequirement requirement = LearnedRequirement.both;
  int sessionSize = 10;
  bool customCountActive = false;
  bool allSelected = false;

  @override
  void dispose() {
    customCount.dispose();
    super.dispose();
  }

  List<TransitivityPair> get availablePairs {
    final learned = widget.learnedWords;
    if (source == TransitivitySource.unlocked && learned != null) {
      return filterLearnedPairs(transitivityPairs, learned, requirement);
    }
    return transitivityPairs;
  }

  int? get parsedCustomCount {
    final count = int.tryParse(customCount.text.trim());
    return count != null && count > 0 ? count : null;
  }

  int get selectedCount {
    if (allSelected) return availablePairs.length;
    final custom = parsedCustomCount;
    return (customCountActive ? custom ?? 10 : sessionSize).clamp(
      1,
      availablePairs.length,
    );
  }

  void start() => widget.onStart(
    TransitivityConfig(pairs: availablePairs, sessionSize: selectedCount),
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final hasSyncedData = widget.learnedWords != null;
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
                'Transitivity Practice',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Practice Japanese transitive and intransitive verb pairs '
                '(他動詞・自動詞) with the built-in offline dictionary.',
                style: TextStyle(color: _muted, fontSize: 15),
              ),
              const SizedBox(height: 28),
              _SetupSection(
                title: 'Source filter',
                child: Column(
                  children: [
                    RadioGroup<TransitivitySource>(
                      groupValue: source,
                      onChanged: (value) {
                        if (value != null) setState(() => source = value);
                      },
                      child: Column(
                        children: [
                          const RadioListTile<TransitivitySource>(
                            contentPadding: EdgeInsets.zero,
                            value: TransitivitySource.allBuiltIn,
                            title: Text('All Built-in Words'),
                            subtitle: Text('Practice every offline verb pair.'),
                          ),
                          RadioListTile<TransitivitySource>(
                            contentPadding: EdgeInsets.zero,
                            value: TransitivitySource.unlocked,
                            enabled: hasSyncedData,
                            title: const Text('Unlocked on WaniKani'),
                            subtitle: Text(
                              hasSyncedData
                                  ? 'Only pairs whose words you have started '
                                        'in WaniKani lessons.'
                                  : 'Sync a WaniKani account to enable '
                                        'learned-word filtering.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasSyncedData &&
                        source == TransitivitySource.unlocked) ...[
                      const SizedBox(height: 8),
                      SegmentedButton<LearnedRequirement>(
                        segments: const [
                          ButtonSegment(
                            value: LearnedRequirement.both,
                            label: Text('Both words learned'),
                          ),
                          ButtonSegment(
                            value: LearnedRequirement.either,
                            label: Text('At least one learned'),
                          ),
                        ],
                        selected: {requirement},
                        onSelectionChanged: (value) =>
                            setState(() => requirement = value.first),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          availablePairs.isEmpty
                              ? 'No matching pairs yet.'
                              : '${availablePairs.length} matching pairs.',
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    ],
                    if (!hasSyncedData)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'This filter is unavailable without a synced account. '
                          'All Built-in Words works offline.',
                          style: TextStyle(color: _muted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SetupSection(
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
                      label: Text('All (${availablePairs.length})'),
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
                          hintText: '1 – ${availablePairs.length}',
                          isDense: true,
                          errorText:
                              customCountActive &&
                                  customCount.text.isNotEmpty &&
                                  parsedCustomCount == null
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
                    onPressed: availablePairs.isEmpty ? null : start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start practice'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${availablePairs.length} verb pairs available',
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

class TransitivityQuizScreen extends StatefulWidget {
  const TransitivityQuizScreen({
    required this.config,
    required this.onExit,
    super.key,
  });

  final TransitivityConfig config;
  final VoidCallback onExit;

  @override
  State<TransitivityQuizScreen> createState() => _TransitivityQuizScreenState();
}

class _TransitivityQuizScreenState extends State<TransitivityQuizScreen> {
  final random = Random();
  final keyboardFocus = FocusNode(debugLabel: 'transitivity shortcuts');
  late final List<_TransitivityQuestion> questions;
  int questionIndex = 0;
  int correctCount = 0;
  bool? wasCorrect;
  bool hintVisible = false;

  TransitivityConfig get config => widget.config;
  _TransitivityQuestion get question => questions[questionIndex];
  bool get promptIsTransitive => question.promptIsTransitive;

  @override
  void initState() {
    super.initState();
    final pool = config.pairs.toList()..shuffle(random);
    questions = [
      for (final pair in pool.take(config.sessionSize))
        _TransitivityQuestion(pair, random.nextBool()),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) keyboardFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    keyboardFocus.dispose();
    super.dispose();
  }

  void _recordAnswer(bool correct) {
    if (wasCorrect != null) return;
    setState(() {
      wasCorrect = correct;
      if (correct) correctCount++;
    });
  }

  void _advance() {
    if (wasCorrect == null) return;
    if (questionIndex + 1 == questions.length) {
      setState(() => questionIndex = questions.length);
      return;
    }
    setState(() {
      questionIndex++;
      wasCorrect = null;
      hintVisible = false;
    });
    keyboardFocus.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (questionIndex >= questions.length) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (wasCorrect != null && key == LogicalKeyboardKey.enter) {
      _advance();
      return KeyEventResult.handled;
    }
    if (wasCorrect == null) {
      if (key == LogicalKeyboardKey.keyH) {
        setState(() => hintVisible = true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.digit1) {
        _recordAnswer(promptIsTransitive);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.digit2) {
        _recordAnswer(!promptIsTransitive);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (questionIndex >= questions.length) return _buildSummary(context);
    final compact = MediaQuery.sizeOf(context).width < 700;
    final current = question;
    final promptKanji = current.promptIsTransitive
        ? current.pair.transitiveKanji
        : current.pair.intransitiveKanji;
    final promptKana = current.promptIsTransitive
        ? current.pair.transitiveKana
        : current.pair.intransitiveKana;
    final promptMeaning = current.promptIsTransitive
        ? current.pair.transitiveMeaning
        : current.pair.intransitiveMeaning;
    // In Identification the English gloss (e.g. "(someone)") gives the answer away.
    final showMeaning = hintVisible || wasCorrect != null;

    return Focus(
      focusNode: keyboardFocus,
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
                    Expanded(
                      child: Text(
                        'Identification',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                  value: (questionIndex + 1) / questions.length,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  'Card ${questionIndex + 1} of ${questions.length}  ·  '
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
                            'Which type of verb is this?',
                            style: TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            promptKanji,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink,
                              fontSize: compact ? 48 : 60,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (showMeaning)
                            Text(
                              '$promptKana  ·  $promptMeaning',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 16,
                              ),
                            )
                          else ...[
                            Text(
                              promptKana,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => hintVisible = true),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: const Text('Show meaning (H)'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _AnswerButton(
                        label: 'Transitive',
                        detail: '他動詞  ·  を',
                        icon: Icons.arrow_left_rounded,
                        color: const Color(0xFF2875BD),
                        onPressed: wasCorrect == null
                            ? () => _recordAnswer(promptIsTransitive)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnswerButton(
                        label: 'Intransitive',
                        detail: '自動詞  ·  が',
                        icon: Icons.arrow_right_rounded,
                        color: const Color(0xFF16866A),
                        onPressed: wasCorrect == null
                            ? () => _recordAnswer(!promptIsTransitive)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '← / 1: Transitive    → / 2: Intransitive',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                if (wasCorrect != null) ...[
                  const SizedBox(height: 18),
                  _FeedbackCard(
                    pair: question.pair,
                    correct: wasCorrect!,
                    compact: compact,
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _advance,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        questionIndex + 1 == questions.length
                            ? 'Finish'
                            : 'Next  (Enter)',
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

  Widget _buildSummary(BuildContext context) {
    final percent = (correctCount / questions.length * 100).round();
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
                    '$correctCount / ${questions.length} correct  ·  $percent%',
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

class _TransitivityQuestion {
  const _TransitivityQuestion(this.pair, this.promptIsTransitive);

  final TransitivityPair pair;
  final bool promptIsTransitive;
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center),
        Text(
          detail,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    ),
  );
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.pair,
    required this.correct,
    required this.compact,
  });

  final TransitivityPair pair;
  final bool correct;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    color: correct ? const Color(0xFFE8F6ED) : const Color(0xFFFFF0EE),
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? 'Correct!' : 'Not quite.',
            style: TextStyle(
              color: correct
                  ? const Color(0xFF16866A)
                  : const Color(0xFFC44738),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = !compact && constraints.maxWidth >= 560;
              final width = sideBySide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _VerbExample(
                      title: 'Transitive  他動詞',
                      verb: pair.transitiveKanji,
                      reading: pair.transitiveKana,
                      meaning: pair.transitiveMeaning,
                      example: pair.transitiveExample,
                      exampleMeaning: pair.transitiveExampleMeaning,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _VerbExample(
                      title: 'Intransitive  自動詞',
                      verb: pair.intransitiveKanji,
                      reading: pair.intransitiveKana,
                      meaning: pair.intransitiveMeaning,
                      example: pair.intransitiveExample,
                      exampleMeaning: pair.intransitiveExampleMeaning,
                    ),
                  ),
                ],
              );
            },
          ),
          if (pair.rulePattern != null) ...[
            const SizedBox(height: 10),
            Text(
              'Common pattern: ${pair.rulePattern}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

class _VerbExample extends StatelessWidget {
  const _VerbExample({
    required this.title,
    required this.verb,
    required this.reading,
    required this.meaning,
    required this.example,
    this.exampleMeaning,
  });

  final String title;
  final String verb;
  final String reading;
  final String meaning;
  final String? example;
  final String? exampleMeaning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          verb,
          style: const TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text('$reading  ·  $meaning', style: const TextStyle(color: _muted)),
        if (example != null) ...[
          const SizedBox(height: 8),
          Text(example!, style: const TextStyle(fontSize: 17, color: _ink)),
          if (exampleMeaning != null)
            Text(
              exampleMeaning!,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
        ],
      ],
    ),
  );
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}
