import 'package:flutter/material.dart';
import '../board_theme_controller.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
Future<void> showBoardThemeDialog(
  BuildContext context,
  BoardThemeController controller,
) {
  Color tempLight = controller.lightSquare;
  Color tempDark = controller.darkSquare;

  return showDialog(
    context: context,
    builder: (_) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            Widget colorPicker(Color color, Function(Color) onChange) {
              return GestureDetector(
                onTap: () async {
                  final newColor = await showDialog<Color>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Выбор цвета'),
                      content: SingleChildScrollView(
                        child: BlockPicker(
                          pickerColor: color,
                          onColorChanged: (c) =>
                              Navigator.pop(context, c),
                        ),
                      ),
                    ),
                  );

                  if (newColor != null) {
                    setState(() => onChange(newColor));
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Тема доски',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('Светлая'),
                          const SizedBox(height: 8),
                          colorPicker(tempLight,
                              (c) => tempLight = c),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Тёмная'),
                          const SizedBox(height: 8),
                          colorPicker(tempDark,
                              (c) => tempDark = c),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      controller.setLight(tempLight);
                      controller.setDark(tempDark);
                      Navigator.pop(context);
                    },
                    child: const Text('Применить'),
                  )
                ],
              ),
            );
          },
        ),
      );
    },
  );
}