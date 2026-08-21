// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// lib/ui/payment_modal.dart
import 'package:flutter/material.dart';

import '../localization/makechess_localization.dart';
class PaymentModal {
  static Future<void> show({
    required BuildContext context,
    required String
        planTitle, // 'Pro — расширенная версия' / 'Premium — полный доступ'
    required String price, // '390 ₽ / месяц'
    required List<String>
        features, // ['Совместная доска', 'Анализ Stockfish', ...]
    required VoidCallback onPay, // открыть оплату
    VoidCallback? onTrial, // 7 дней бесплатно (если нужно)
    VoidCallback? onEnterKey, // ввод ключа
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                MakeChessLocalizedText('MakeChess',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Выбранный тариф (плитка как в твоём окне)
                _PlanTile(
                  colorScheme: cs,
                  title: planTitle,
                  subtitle: price,
                  highlight: true, // зелёный фон
                  trialLabel: onTrial != null ? '7 дней бесплатно' : null,
                  onTrialTap: onTrial,
                ),
                const SizedBox(height: 12),

                // Список преимуществ
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: features
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 18, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: MakeChessLocalizedText(
                                      f,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color:
                                                  cs.onSurface.withOpacity(.85),
                                              fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1),

                // Кнопки снизу
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (onEnterKey != null)
                      Expanded(
                        child: _BottomButton(
                          text: 'Ввести ключ',
                          filled: false,
                          onTap: () {
                            Navigator.pop(ctx);
                            onEnterKey();
                          },
                        ),
                      ),
                    if (onEnterKey != null) const SizedBox(width: 12),
                    Expanded(
                      child: _BottomButton(
                        text: 'Оплатить',
                        filled: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          onPay();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const MakeChessLocalizedText('Отмена'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ——— Вспомогательные виджеты — стиль как в StartModal ———

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.colorScheme,
    required this.title,
    required this.subtitle,
    this.trialLabel,
    this.onTrialTap,
    this.highlight = false,
  });

  final ColorScheme colorScheme;
  final String title;
  final String subtitle;
  final String? trialLabel;
  final VoidCallback? onTrialTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? const Color(0xFF4CAF50) : colorScheme.surfaceVariant;
    final textColor = highlight ? Colors.white : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Текст
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MakeChessLocalizedText(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: textColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                MakeChessLocalizedText(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: (highlight
                            ? Colors.white.withOpacity(.9)
                            : colorScheme.onSurface.withOpacity(.75)),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Пилюля "7 дней бесплатно"
          if (trialLabel != null)
            InkWell(
              onTap: onTrialTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    MakeChessLocalizedText(trialLabel!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right,
              color: highlight ? Colors.white : colorScheme.onSurface),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({
    required this.text,
    required this.onTap,
    required this.filled,
  });

  final String text;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? cs.primary : cs.primary.withOpacity(.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: MakeChessLocalizedText(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: filled ? cs.onPrimary : cs.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
