import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/conjugation_config.dart';
import '../domain/conjugation_models.dart';
import 'conjugation_quiz_screen.dart';

const _ink = Color(0xFF16212B);
const _muted = Color(0xFF73808A);

/// Entry point of the module: shows the setup, then the quiz.
class ConjugationScreen extends StatefulWidget {
  const ConjugationScreen({super.key});

  @override
  State<ConjugationScreen> createState() => _ConjugationScreenState();
}

class _ConjugationScreenState extends State<ConjugationScreen> {
  ConjugationConfig? activeConfig;

  @override
  Widget build(BuildContext context) {
    final config = activeConfig;
    if (config == null) {
      return ConjugationSetupScreen(
        onStart: (value) => setState(() => activeConfig = value),
      );
    }
    return ConjugationQuizScreen(
      config: config,
      onExit: () => setState(() => activeConfig = null),
    );
  }
}

class ConjugationSetupScreen extends StatefulWidget {
  const ConjugationSetupScreen({required this.onStart, super.key});
  final ValueChanged<ConjugationConfig> onStart;

  @override
  State<ConjugationSetupScreen> createState() => _ConjugationSetupScreenState();
}

class _ConjugationSetupScreenState extends State<ConjugationSetupScreen> {
  final Set<WordGroup> groups = WordGroup.values.toSet();
  final Set<int> selectedChoices = {
    for (var i = 1; i < formChoices.length; i++) i,
  };
  ConjugationInputMode inputMode = ConjugationInputMode.typing;
  int sessionSize = 10;
  bool customActive = false;
  final customController = TextEditingController();

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  /// Parsed custom count; null when empty or invalid.
  int? get customValue {
    final value = int.tryParse(customController.text.trim());
    return value == null || value < 1 ? null : value;
  }

  int resolveSessionSize(int poolSize) {
    if (!customActive) return sessionSize;
    return (customValue ?? 10).clamp(1, poolSize < 1 ? 1 : poolSize);
  }

  Set<ConjugationForm> get forms => {
    for (final index in selectedChoices) ...formChoices[index].forms,
  };

  ConjugationConfig get config => ConjugationConfig(
    groups: groups,
    forms: forms,
    inputMode: inputMode,
    sessionSize: sessionSize,
  );

  void toggle<T>(Set<T> set, T value, bool selected) => setState(() {
    selected ? set.add(value) : set.remove(value);
  });

  @override
  Widget build(BuildContext context) {
    final poolSize = config.buildPool().length;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
          : const EdgeInsets.fromLTRB(42, 38, 42, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conjugation setup',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Practice verb and adjective conjugation with offline N5-N3 vocabulary.',
                style: TextStyle(color: _muted, fontSize: 15),
              ),
              const SizedBox(height: 30),
              _Section(
                title: 'Word groups',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final group in WordGroup.values)
                      FilterChip(
                        label: Text(group.title),
                        selected: groups.contains(group),
                        onSelected: (value) => toggle(groups, group, value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Target forms',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < formChoices.length; i++)
                      FilterChip(
                        label: Text(formChoices[i].label),
                        selected: selectedChoices.contains(i),
                        onSelected: (value) =>
                            toggle(selectedChoices, i, value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Input mode',
                child: SegmentedButton<ConjugationInputMode>(
                  segments: const [
                    ButtonSegment(
                      value: ConjugationInputMode.typing,
                      icon: Icon(Icons.keyboard_alt_outlined),
                      label: Text('Typing'),
                    ),
                    ButtonSegment(
                      value: ConjugationInputMode.multipleChoice,
                      icon: Icon(Icons.grid_view_outlined),
                      label: Text('Multiple choice'),
                    ),
                  ],
                  selected: {inputMode},
                  onSelectionChanged: (value) =>
                      setState(() => inputMode = value.first),
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Session size',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final size in const [10, 20, 50, 0])
                      ChoiceChip(
                        label: Text(size == 0 ? 'Endless ∞' : '$size cards'),
                        selected: !customActive && sessionSize == size,
                        onSelected: (_) => setState(() {
                          sessionSize = size;
                          customActive = false;
                          customController.clear();
                        }),
                      ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: customController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Custom count',
                          hintText: '1 – $poolSize',
                          isDense: true,
                          errorText:
                              customActive &&
                                  customController.text.isNotEmpty &&
                                  customValue == null
                              ? 'Min. 1 (default: 10)'
                              : customValue != null && customValue! > poolSize
                              ? 'Max. $poolSize'
                              : null,
                        ),
                        onChanged: (text) => setState(() {
                          customActive = text.isNotEmpty;
                          final value = customValue;
                          if (value != null) sessionSize = value;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: poolSize == 0
                        ? null
                        : () => widget.onStart(
                            ConjugationConfig(
                              groups: groups,
                              forms: forms,
                              inputMode: inputMode,
                              sessionSize: resolveSessionSize(poolSize),
                            ),
                          ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start practice'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      poolSize == 0
                          ? 'No matching cards: pick a word group and a form that apply to it.'
                          : '$poolSize possible cards',
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
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
              style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    ),
  );
}
