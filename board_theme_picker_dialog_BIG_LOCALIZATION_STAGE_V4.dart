// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
import 'package:flutter/material.dart';
import '../../localization/makechess_localization.dart';

const List<Color> boardThemeSwatches = [
  Color(0xFFF0D9B5),
  Color(0xFFB58863),
  Color(0xFFE7D3B0),
  Color(0xFFAE825C),
  Color(0xFFEEEED2),
  Color(0xFF769656),
  Color(0xFFD8C3A5),
  Color(0xFF8B6A4E),
  Color(0xFFC2A383),
  Color(0xFF7A5C3E),
  Color(0xFFE6CCB2),
  Color(0xFFB08968),
  Color(0xFFE0E0E0),
  Color(0xFF9E9E9E),
  Color(0xFFBDBDBD),
  Color(0xFF616161),
  Color(0xFFEEEEEE),
  Color(0xFF424242),
  Color(0xFFB7D7A8),
  Color(0xFF4CAF50),
  Color(0xFF81C784),
  Color(0xFF2E7D32),
  Color(0xFFA5D6A7),
  Color(0xFF1B5E20),
  Color(0xFFDDEEFF),
  Color(0xFF6B8FB3),
  Color(0xFFBBDEFB),
  Color(0xFF1E88E5),
  Color(0xFF90CAF9),
  Color(0xFF0D47A1),
  Color(0xFFE6E6FA),
  Color(0xFF7B68EE),
  Color(0xFFD1C4E9),
  Color(0xFF512DA8),
  Color(0xFFB39DDB),
  Color(0xFF311B92),
  Color(0xFFFFCDD2),
  Color(0xFFE57373),
  Color(0xFFEF9A9A),
  Color(0xFFC62828),
  Color(0xFFFFAB91),
  Color(0xFFD84315),
  Color(0xFFFFF9C4),
  Color(0xFFFFF59D),
  Color(0xFFE1BEE7),
  Color(0xFFF8BBD0),
  Color(0xFFB2EBF2),
  Color(0xFFC8E6C9),
];

Future<(Color, Color)?> showBoardThemePickerDialog(
  BuildContext context, {
  required Color initialLight,
  required Color initialDark,
  bool extendedPalette = false,
}) async {
  Color light = initialLight;
  Color dark = initialDark;

  Future<Color?> pickColor(Color current) {
    if (extendedPalette) {
      Color selected = current;
      final argb = current.toARGB32();
      int red = (argb >> 16) & 0xff;
      int green = (argb >> 8) & 0xff;
      int blue = argb & 0xff;

      void updateColor(StateSetter setPickerState) {
        setPickerState(() {
          selected = Color.fromARGB(255, red, green, blue);
        });
      }

      Widget channelSlider({
        required String label,
        required int value,
        required Color color,
        required ValueChanged<int> onChanged,
      }) =>
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  activeColor: color,
                  label: value.toString(),
                  onChanged: (newValue) => onChanged(newValue.round()),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  value.toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          );

      return showDialog<Color>(
        context: context,
        builder: (pickerContext) => StatefulBuilder(
          builder: (pickerContext, setPickerState) => AlertDialog(
            title: const MakeChessLocalizedText('Выберите цвет'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 82,
                    decoration: BoxDecoration(
                      color: selected,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 14),
                  channelSlider(
                    label: 'R',
                    value: red,
                    color: Colors.redAccent,
                    onChanged: (value) {
                      red = value;
                      updateColor(setPickerState);
                    },
                  ),
                  channelSlider(
                    label: 'G',
                    value: green,
                    color: Colors.greenAccent,
                    onChanged: (value) {
                      green = value;
                      updateColor(setPickerState);
                    },
                  ),
                  channelSlider(
                    label: 'B',
                    value: blue,
                    color: Colors.blueAccent,
                    onChanged: (value) {
                      blue = value;
                      updateColor(setPickerState);
                    },
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '#${red.toRadixString(16).padLeft(2, '0')}'
                            '${green.toRadixString(16).padLeft(2, '0')}'
                            '${blue.toRadixString(16).padLeft(2, '0')}'
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const MakeChessLocalizedText(
                    'Для серого установите одинаковые значения R, G и B',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(pickerContext).pop(),
                child: const MakeChessLocalizedText('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(pickerContext).pop(selected),
                child: const MakeChessLocalizedText('Выбрать'),
              ),
            ],
          ),
        ),
      );
    }

    return showDialog<Color>(
      context: context,
      builder: (pickerContext) => AlertDialog(
        title: const MakeChessLocalizedText('Выберите цвет'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: boardThemeSwatches.map((color) {
            final selected = color.value == current.value;
            return GestureDetector(
              onTap: () => Navigator.of(pickerContext).pop(color),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.black12,
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pickerContext).pop(),
            child: const MakeChessLocalizedText('Отмена'),
          ),
        ],
      ),
    );
  }

  return showDialog<(Color, Color)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 220, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MakeChessLocalizedText(
                'Тема доски',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ColorChoice(
                      label: 'Светлая клетка',
                      color: light,
                      onTap: () async {
                        final picked = await pickColor(light);
                        if (picked != null) {
                          setDialogState(() => light = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ColorChoice(
                      label: 'Тёмная клетка',
                      color: dark,
                      onTap: () async {
                        final picked = await pickColor(dark);
                        if (picked != null) {
                          setDialogState(() => dark = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const MakeChessLocalizedText('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop((light, dark)),
                      child: const MakeChessLocalizedText('Применить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          MakeChessLocalizedText(label),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),
        ],
      );
}
