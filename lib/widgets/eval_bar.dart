import 'package:flutter/material.dart';

class EvalBar extends StatelessWidget {
  final double eval; // от -15 до +15
  final bool flipped;

  const EvalBar({
    super.key,
    required this.eval,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    final double clamped = eval.clamp(-15.0, 15.0);

    // Базовая нормализация оценки: 0..1
    // -15 -> 0.0
    //  0  -> 0.5
    // +15 -> 1.0
    final double baseNormalized = (clamped + 15.0) / 30.0;

    // Визуальное положение полосы:
    // если доска перевёрнута — зеркалим ВЕСЬ бар
    final double visualNormalized =
        flipped ? (1.0 - baseNormalized) : baseNormalized;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;

        // Высота верхней части бара
        final double topPartHeight = height * (1.0 - visualNormalized);

        // Координата границы между цветами
        final double boundaryY = topPartHeight;

        // Кнопка с цифрой стоит центром на границе
        final double badgeTop = (boundaryY - 18.0).clamp(0.0, height - 36.0);

        // Цвета должны переворачиваться ВМЕСТЕ с доской
        final Color topColor = flipped ? Colors.white : Colors.black;
        final Color bottomColor = flipped ? Colors.black : Colors.white;

        return SizedBox(
          width: 52,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Вся колонка: нижний цвет
              Positioned(
                left: 18,
                top: 0,
                child: Container(
                  width: 14,
                  height: height,
                  decoration: BoxDecoration(
                    color: bottomColor,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                ),
              ),

              // Верхняя часть: верхний цвет
              Positioned(
                left: 18,
                top: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    width: 14,
                    height: topPartHeight,
                    color: topColor,
                  ),
                ),
              ),

              // Линия 0.00 по центру
              Positioned(
                left: 16,
                right: 16,
                top: height / 2 - 1,
                child: Container(
                  height: 2,
                  color: Colors.grey.withOpacity(0.6),
                ),
              ),

              // Синяя кнопка с оценкой — НА ГРАНИЦЕ
              Positioned(
                left: 0,
                top: badgeTop,
                child: Container(
                  width: 46,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white70, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    clamped.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
