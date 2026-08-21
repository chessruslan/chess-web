// MAKECHESS_ALL_RUSSIAN_UI_V5_20260807
// lib/features/schools/school_dialog.dart
import 'package:flutter/material.dart';

import '../../../localization/makechess_localization.dart';

/// Диалог "Школы" (пока без логики, но полностью верстается и собирается)
class SchoolDialog extends StatefulWidget {
  const SchoolDialog({super.key});

  @override
  State<SchoolDialog> createState() => _SchoolDialogState();
}

class _SchoolDialogState extends State<SchoolDialog> {
  // Демоданные. Потом подставишь реальные школы/избранное.
  final List<String> _allSchools = const [
    'Grandmaster Club',
    'TwinChess Academy',
    'Beginner School',
    'Open Tactics',
  ];
  final List<String> _favorites = const [
    'TwinChess Academy',
    'Grandmaster Club',
  ];

  String? _selectedSchool;
  String? _selectedFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhone = MediaQuery.of(context).size.width < 600;

    // Размеры: «как доска» на десктопе, компактно — на телефоне
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isPhone ? 420 : 760,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: MakeChessLocalizedText(
                    'Выбор школы',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Поле 1: список школ
                MakeChessLocalizedText('Школа',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _LinedDropdown<String>(
                  value: _selectedSchool,
                  items: _allSchools,
                  hint: 'Выберите школу',
                  onChanged: (v) => setState(() => _selectedSchool = v),
                ),
                const SizedBox(height: 14),

                // Поле 2: избранные
                MakeChessLocalizedText('Избранное',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _LinedDropdown<String>(
                  value: _selectedFavorite,
                  items: _favorites,
                  hint: 'Выберите избранную',
                  onChanged: (v) {
                    setState(() {
                      _selectedFavorite = v;
                      _selectedSchool = v; // любимую сразу ставим в «школу»
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Карточка учителя (заглушка)
                _TeacherCard(
                  name: 'IM John Doe',
                  meta: '45 лет, США',
                  rating: 'Рейтинг 2400',
                  // вместо картинки можно потом ставить NetworkImage / File …
                ),
                const SizedBox(height: 16),

                // Кнопки
                FilledButton(
                  onPressed: _selectedSchool == null
                      ? null
                      : () {
                          // TODO: вход ученика + авто-видеозвонок/подключение к SFU
                          Navigator.pop(context,
                              {'role': 'student', 'school': _selectedSchool});
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: MakeChessLocalizedText('Войти как ученик'),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: _selectedSchool == null
                      ? null
                      : () {
                          // TODO: вход учителя
                          Navigator.pop(context,
                              {'role': 'teacher', 'school': _selectedSchool});
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: MakeChessLocalizedText('Войти как учитель'),
                  ),
                ),
                const SizedBox(height: 12),

                // Создать школу
                OutlinedButton.icon(
                  onPressed: () async {
                    // Пустая «заглушка» создания школы (вынесена ниже)
                    await showDialog(
                      context: context,
                      builder: (_) => const CreateSchoolDialog(),
                    );
                    // После закрытия можно перечитать список школ.
                  },
                  icon: const Icon(Icons.add_business),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: MakeChessLocalizedText('Создать школу'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // На телефоне делаем полноэкранный диалог
    if (isPhone) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        backgroundColor: Colors.transparent,
        child: content,
      );
    }

    // На десктопе — обычный диалог
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      content: content,
    );
    // (Кнопки закрытия не нужны — есть действия выше)
  }
}

/// Выпадающий список с аккуратной рамкой
class _LinedDropdown<T> extends StatelessWidget {
  const _LinedDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
  });

  final List<T> items;
  final T? value;
  final String? hint;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        hint: MakeChessLocalizedText(hint ?? ''),
        isExpanded: true,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(10),
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: MakeChessLocalizedText(e.toString()),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Карточка «Учитель»
class _TeacherCard extends StatelessWidget {
  const _TeacherCard({
    required this.name,
    required this.meta,
    required this.rating,
  });

  final String name;
  final String meta;
  final String rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Заглушка аватарки
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 110,
              height: 110,
              color: theme.colorScheme.primaryContainer,
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MakeChessLocalizedText(name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                MakeChessLocalizedText(meta, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                MakeChessLocalizedText(rating,
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Создать школу» — пока пустышка. Потом добавим поля.
class CreateSchoolDialog extends StatelessWidget {
  const CreateSchoolDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const MakeChessLocalizedText('Создать школу'),
      content: SizedBox(
        width: 420,
        child: MakeChessLocalizedText(
          'Здесь будет форма создания школы (название, описание, обложка, '
          'времена занятий, приватность и т.д.).',
          style: theme.textTheme.bodyMedium,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const MakeChessLocalizedText('Закрыть'),
        ),
        FilledButton(
          onPressed: () {
            // TODO: сохранить и обновить список
            Navigator.pop(context);
          },
          child: const MakeChessLocalizedText('Создать'),
        ),
      ],
    );
  }
}
