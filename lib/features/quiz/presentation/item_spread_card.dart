import 'package:flutter/material.dart';

import '../../../core/models/assignment.dart';
import '../../../core/models/subject.dart';

class ItemSpreadCard extends StatelessWidget {
  const ItemSpreadCard({required this.controller, super.key});

  final dynamic controller;

  static const _columns = [
    (SubjectType.radical, 'Radicals', Color(0xFF00AAFF)),
    (SubjectType.kanji, 'Kanji', Color(0xFFFF00AA)),
    (SubjectType.vocabulary, 'Vocabulary', Color(0xFFAA00FF)),
  ];

  @override
  Widget build(BuildContext context) {
    final spread =
        controller.itemSpread as Map<SrsStage, Map<SubjectType, int>>;
    int stageTotal(SrsStage stage) =>
        _columns.fold(0, (sum, c) => sum + (spread[stage]![c.$1] ?? 0));
    final maxTotal = SrsStage.values
        .map(stageTotal)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Spread',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 600 ? 1 : 2;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final stage in SrsStage.values)
                      SizedBox(
                        width: width,
                        child: _StageTile(
                          name: _name(stage),
                          total: stageTotal(stage),
                          maxTotal: maxTotal,
                          counts: [
                            for (final c in _columns)
                              (c.$2, c.$3, spread[stage]![c.$1] ?? 0),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _name(SrsStage stage) =>
      stage.name[0].toUpperCase() + stage.name.substring(1);
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.name,
    required this.total,
    required this.maxTotal,
    required this.counts,
  });
  final String name;
  final int total;
  final int maxTotal;
  final List<(String, Color, int)> counts;

  @override
  Widget build(BuildContext context) {
    final fraction = maxTotal == 0 ? 0.0 : total / maxTotal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: const Color(0xFFE1E6E9),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: Row(
                      children: [
                        for (final c in counts)
                          if (c.$3 > 0)
                            Expanded(
                              flex: c.$3,
                              child: ColoredBox(
                                color: c.$2,
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              for (final c in counts)
                Text(
                  '${c.$1}: ${c.$3}',
                  style: TextStyle(fontSize: 12, color: c.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
