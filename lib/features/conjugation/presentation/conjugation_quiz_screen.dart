import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../quiz/presentation/kana_input_controller.dart';
import '../domain/conjugation_config.dart';
import '../domain/conjugation_engine.dart';
import '../domain/conjugation_models.dart';

const _ink = Color(0xFF16212B);
const _muted = Color(0xFF73808A);
const _okBg = Color(0xFFE8F5D0);
const _okFg = Color(0xFF4C7A00);
const _badBg = Color(0xFFFFE4E0);
const _badFg = Color(0xFFB42318);

class ConjugationQuizScreen extends StatefulWidget {
  const ConjugationQuizScreen({
    required this.config,
    required this.onExit,
    super.key,
  });
  final ConjugationConfig config;
  final VoidCallback onExit;

  @override
  State<ConjugationQuizScreen> createState() => _ConjugationQuizScreenState();
}

class _ConjugationQuizScreenState extends State<ConjugationQuizScreen> {
  final random = Random();
  final input = KanaInputController();
  final focus = FocusNode();
  late final List<ConjugationQuestion> pool;
  late final List<ConjugationQuestion> queue;

  late ConjugationQuestion question;
  late ConjugationResult result;
  List<String> choices = const [];
  String? selectedChoice;
  bool answered = false;
  bool correct = false;
  bool finished = false;
  int answeredCount = 0;
  int correctCount = 0;
  final List<_Mistake> mistakes = [];

  ConjugationConfig get config => widget.config;
  bool get typing => config.inputMode == ConjugationInputMode.typing;
  int get total => config.endless ? 0 : queue.length;

  @override
  void initState() {
    super.initState();
    pool = config.buildPool();
    queue = config.endless
        ? []
        : (List.of(pool)..shuffle(random)).take(config.sessionSize).toList();
    _loadQuestion();
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  void _loadQuestion() {
    if (config.endless) {
      var next = pool[random.nextInt(pool.length)];
      if (pool.length > 1 && answeredCount > 0) {
        while (next == question) {
          next = pool[random.nextInt(pool.length)];
        }
      }
      question = next;
    } else {
      question = queue[answeredCount];
    }
    result = ConjugationEngine.conjugate(question.entry, question.form);
    choices = typing
        ? const []
        : ConjugationEngine.buildChoices(question.entry, question.form, random);
    selectedChoice = null;
    answered = false;
    correct = false;
    input.clear();
  }

  void _record(bool isCorrect, String given) {
    answered = true;
    correct = isCorrect;
    answeredCount++;
    if (isCorrect) {
      correctCount++;
    } else {
      mistakes.add(_Mistake(question, result, given));
    }
  }

  void _submitTyped() {
    if (answered) {
      _next();
      return;
    }
    final given = input.normalizeForSubmission().trim();
    if (given.isEmpty) return;
    setState(() => _record(result.acceptedAnswers.contains(given), given));
  }

  void _pickChoice(String choice) {
    if (answered) return;
    setState(() {
      selectedChoice = choice;
      _record(result.acceptedKana.contains(choice), choice);
    });
  }

  void _next() {
    if (!config.endless && answeredCount >= queue.length) {
      setState(() => finished = true);
      return;
    }
    setState(_loadQuestion);
    if (typing) focus.requestFocus();
  }

  void _restart() => setState(() {
    answeredCount = 0;
    correctCount = 0;
    mistakes.clear();
    finished = false;
    if (!config.endless) queue.shuffle(random);
    _loadQuestion();
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
          : const EdgeInsets.fromLTRB(42, 38, 42, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          // Fallback hotkey: Enter advances even if the text field lost focus.
          child: Focus(
            autofocus: !typing,
            onKeyEvent: (node, event) {
              final isEnter =
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter;
              if (event is KeyDownEvent &&
                  isEnter &&
                  answered &&
                  !finished &&
                  !focus.hasFocus) {
                _next();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: finished ? _buildSummary() : _buildQuiz(compact),
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(bool compact) {
    final entry = question.entry;
    final position = answered ? answeredCount : answeredCount + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: widget.onExit,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Setup'),
            ),
            const Spacer(),
            Text(
              config.endless
                  ? '$answeredCount answered · $correctCount correct'
                  : '$position / $total · $correctCount correct',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (config.endless)
              TextButton(
                onPressed: answeredCount == 0
                    ? null
                    : () => setState(() => finished = true),
                child: const Text('Finish'),
              ),
          ],
        ),
        if (!config.endless)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              value: answeredCount / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        Card(
          color: answered && !correct ? const Color(0xFFFFF8F7) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: answered && !correct
                ? const BorderSide(color: _badFg)
                : BorderSide.none,
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 20 : 38),
            child: Column(
              children: [
                Text(
                  entry.group.shortLabel.toUpperCase(),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  entry.kanji,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 52 : 72,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                if (entry.hasKanji)
                  Text(
                    entry.kana,
                    style: const TextStyle(fontSize: 20, color: _muted),
                  ),
                const SizedBox(height: 8),
                Text(
                  entry.meaning,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: _muted),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    question.form.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (typing) _typingInput() else _choiceList(),
                if (answered) ...[const SizedBox(height: 18), _feedback()],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _typingInput() => TextField(
    controller: input,
    focusNode: focus,
    autofocus: true,
    readOnly: answered,
    onChanged: input.normalizeLive,
    onSubmitted: (_) {
      _submitTyped();
      focus.requestFocus();
    },
    textInputAction: TextInputAction.done,
    decoration: InputDecoration(
      hintText: 'Type romaji or kana and press Enter',
      suffixIcon: IconButton(
        tooltip: answered ? 'Next card' : 'Check answer',
        onPressed: _submitTyped,
        icon: const Icon(Icons.arrow_forward_rounded),
      ),
    ),
  );

  Widget _choiceList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final choice in choices)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _choiceButton(choice),
        ),
    ],
  );

  Widget _choiceButton(String choice) {
    final isCorrect = result.acceptedKana.contains(choice);
    final isSelected = selectedChoice == choice;
    Color? background;
    Color foreground = _ink;
    if (answered && isCorrect) {
      background = _okBg;
      foreground = _okFg;
    } else if (answered && isSelected) {
      background = _badBg;
      foreground = _badFg;
    }
    return OutlinedButton(
      onPressed: answered ? null : () => _pickChoice(choice),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: background,
        disabledBackgroundColor: background,
        disabledForegroundColor: answered && (isCorrect || isSelected)
            ? foreground
            : _muted,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        choice,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _feedback() {
    final color = correct ? _okFg : _badFg;
    final answerText = result.kanji == result.kana
        ? result.kana
        : '${result.kanji}  (${result.kana})';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? _okBg : _badBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Text(
                correct ? 'Correct!' : 'Incorrect',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            answerText,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          if (result.alternatives.isNotEmpty)
            Text(
              'Also accepted: ${result.alternatives.join(', ')}',
              style: const TextStyle(color: _muted),
            ),
          const SizedBox(height: 8),
          Text(
            result.explanation,
            style: const TextStyle(color: _ink, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _next,
              child: Text(
                !config.endless && answeredCount >= queue.length
                    ? 'Finish'
                    : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final percent = answeredCount == 0
        ? 0
        : (correctCount * 100 / answeredCount).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Text(
                  'Session complete',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$correctCount / $answeredCount correct ($percent%)',
                  style: const TextStyle(fontSize: 18, color: _muted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Practice again'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onExit,
                      icon: const Icon(Icons.tune),
                      label: const Text('Back to setup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (mistakes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mistakes',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                  ),
                  const SizedBox(height: 10),
                  for (final mistake in mistakes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${mistake.question.entry.kanji} · ${mistake.question.form.label}\n'
                        '${mistake.result.kanji} (${mistake.result.kana})  —  you wrote: ${mistake.given}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Mistake {
  const _Mistake(this.question, this.result, this.given);
  final ConjugationQuestion question;
  final ConjugationResult result;
  final String given;
}
