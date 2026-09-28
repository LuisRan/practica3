import 'package:flutter/material.dart';

/// Medidor de nivel de audio en barras (historial de amplitud normalizada 0..1).
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.levels, required this.color});
  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final l in levels)
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: (c.maxHeight * l).clamp(4.0, c.maxHeight),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35 + l * 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
