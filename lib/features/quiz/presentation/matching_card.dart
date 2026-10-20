import 'package:flutter/material.dart';

import '../../../core/models/quiz_item.dart';

class MatchingCard extends StatefulWidget {
  const MatchingCard({
    required this.items,
    required this.onMatched,
    required this.onComplete,
    super.key,
  });

  final List<QuizItem> items;
  final ValueChanged<QuizItem> onMatched;
  final VoidCallback onComplete;

  @override
  State<MatchingCard> createState() => _MatchingCardState();
}

class _MatchingCardState extends State<MatchingCard> {
  int? selectedLeft;
  String? selectedRightId;
  final matched = <String>{};
  late List<_MatchOption> rightValues;

  @override
  void initState() {
    super.initState();
    rightValues = [
      for (final item in widget.items)
        _MatchOption(item.id, item.acceptedAnswers.firstOrNull ?? ''),
    ]..shuffle();
  }

  @override
  void didUpdateWidget(covariant MatchingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.map((item) => item.id).join() !=
        widget.items.map((item) => item.id).join()) {
      selectedLeft = null;
      selectedRightId = null;
      matched.clear();
      rightValues = [
        for (final item in widget.items)
          _MatchOption(item.id, item.acceptedAnswers.firstOrNull ?? ''),
      ]..shuffle();
    }
  }

  void chooseLeft(int index) {
    if (!matched.contains(widget.items[index].id)) {
      setState(() => selectedLeft = index);
      _tryMatch();
    }
  }

  void chooseRight(_MatchOption option) {
    if (!matched.contains(option.itemId)) {
      setState(() => selectedRightId = option.itemId);
      _tryMatch();
    }
  }

  void _tryMatch() {
    if (selectedLeft == null || selectedRightId == null) return;
    final item = widget.items[selectedLeft!];
    final option = rightValues.firstWhere(
      (item) => item.itemId == selectedRightId,
    );
    final answer = item.acceptedAnswers.firstOrNull ?? '';
    if (answer == option.value) {
      matched.add(item.id);
      widget.onMatched(item);
      selectedLeft = null;
      selectedRightId = null;
      if (matched.length == widget.items.length) {
        widget.onComplete();
      }
    } else {
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted) {
          setState(() {
            selectedLeft = null;
            selectedRightId = null;
          });
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'MATCHING PAIRS',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.3),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (var index = 0; index < widget.items.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed:
                                  matched.contains(widget.items[index].id)
                                  ? null
                                  : () => chooseLeft(index),
                              style: selectedLeft == index
                                  ? OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE8F5D0),
                                    )
                                  : null,
                              child: Text(
                                widget.items[index].subject.characters,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final option in rightValues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: matched.contains(option.itemId)
                                  ? null
                                  : () => chooseRight(option),
                              style: selectedRightId == option.itemId
                                  ? OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE8F5D0),
                                    )
                                  : null,
                              child: Text(option.value),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchOption {
  const _MatchOption(this.itemId, this.value);

  final String itemId;
  final String value;
}
