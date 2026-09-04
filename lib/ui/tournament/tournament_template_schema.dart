enum TournamentTemplateFieldKind { staticText, input }

enum TournamentTemplateColumnKind {
  text,
  player,
  avatar,
  flag,
  country,
  rating,
  points,
  place,
  games,
}

enum TournamentTemplateAction {
  editData,
  save,
  callTournament,
  participate,
  addParticipant,
  removeParticipant,
  createPairing,
  enterResult,
  startTournament,
  pauseTournament,
  finishTournament,
  startRound,
  finishRound,
  recalculate,
  publish,
  printTable,
}

enum TournamentTemplateLayoutMode { automatic, coordinates }

class TournamentTemplatePosition {
  const TournamentTemplatePosition({
    required this.elementId,
    required this.xPercent,
    required this.yPercent,
  });

  final String elementId;
  final double xPercent;
  final double yPercent;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'elementId': elementId,
        'xPercent': xPercent,
        'yPercent': yPercent,
      };

  factory TournamentTemplatePosition.fromJson(Map<String, dynamic> json) =>
      TournamentTemplatePosition(
        elementId: '${json['elementId'] ?? ''}',
        xPercent: ((json['xPercent'] as num?)?.toDouble() ?? 0)
            .clamp(0, 100)
            .toDouble(),
        yPercent: ((json['yPercent'] as num?)?.toDouble() ?? 0)
            .clamp(0, 100)
            .toDouble(),
      );
}

class TournamentTemplateField {
  const TournamentTemplateField({
    required this.id,
    required this.kind,
    required this.label,
    this.value = '',
    this.prompt = '',
    this.required = false,
    this.lines = 1,
  });

  final String id;
  final TournamentTemplateFieldKind kind;
  final String label;
  final String value;
  final String prompt;
  final bool required;
  final int lines;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'label': label,
        'value': value,
        'prompt': prompt,
        'required': required,
        'lines': lines,
      };

  factory TournamentTemplateField.fromJson(Map<String, dynamic> json) =>
      TournamentTemplateField(
        id: '${json['id'] ?? ''}',
        kind: TournamentTemplateFieldKind.values.firstWhere(
          (item) => item.name == '${json['kind'] ?? ''}',
          orElse: () => TournamentTemplateFieldKind.staticText,
        ),
        label: '${json['label'] ?? ''}',
        value: '${json['value'] ?? ''}',
        prompt: '${json['prompt'] ?? ''}',
        required: json['required'] == true,
        lines: ((json['lines'] as num?)?.toInt() ?? 1).clamp(1, 10).toInt(),
      );
}

class TournamentTemplateColumn {
  const TournamentTemplateColumn({
    required this.id,
    required this.label,
    required this.kind,
    this.editable = false,
    this.enabled = true,
  });

  final String id;
  final String label;
  final TournamentTemplateColumnKind kind;
  final bool editable;
  final bool enabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'kind': kind.name,
        'editable': editable,
        'enabled': enabled,
      };

  factory TournamentTemplateColumn.fromJson(Map<String, dynamic> json) =>
      TournamentTemplateColumn(
        id: '${json['id'] ?? ''}',
        label: '${json['label'] ?? ''}',
        kind: TournamentTemplateColumnKind.values.firstWhere(
          (item) => item.name == '${json['kind'] ?? ''}',
          orElse: () => TournamentTemplateColumnKind.text,
        ),
        editable: json['editable'] == true,
        enabled: json['enabled'] != false,
      );
}

class TournamentTemplateButton {
  const TournamentTemplateButton({
    required this.id,
    required this.label,
    required this.action,
    this.enabled = true,
  });

  final String id;
  final String label;
  final TournamentTemplateAction action;
  final bool enabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'action': action.name,
        'enabled': enabled,
      };

  factory TournamentTemplateButton.fromJson(Map<String, dynamic> json) =>
      TournamentTemplateButton(
        id: '${json['id'] ?? ''}',
        label: '${json['label'] ?? ''}',
        action: TournamentTemplateAction.values.firstWhere(
          (item) => item.name == '${json['action'] ?? ''}',
          orElse: () => TournamentTemplateAction.publish,
        ),
        enabled: json['enabled'] != false,
      );
}

class TournamentTemplateSchema {
  const TournamentTemplateSchema({
    this.fields = const <TournamentTemplateField>[],
    this.columns = const <TournamentTemplateColumn>[],
    this.buttons = const <TournamentTemplateButton>[],
    this.expandableRows = true,
    this.rowCount = 8,
    this.expandableColumns = false,
    this.layoutMode = TournamentTemplateLayoutMode.automatic,
    this.positions = const <TournamentTemplatePosition>[],
  });

  final List<TournamentTemplateField> fields;
  final List<TournamentTemplateColumn> columns;
  final List<TournamentTemplateButton> buttons;
  final bool expandableRows;
  final int rowCount;
  final bool expandableColumns;
  final TournamentTemplateLayoutMode layoutMode;
  final List<TournamentTemplatePosition> positions;

  static TournamentTemplateSchema get defaults => TournamentTemplateSchema(
        fields: const <TournamentTemplateField>[
          TournamentTemplateField(
            id: 'judge',
            kind: TournamentTemplateFieldKind.input,
            label: 'Главный судья',
            prompt: 'Введите имя главного судьи',
          ),
          TournamentTemplateField(
            id: 'organizer',
            kind: TournamentTemplateFieldKind.input,
            label: 'Организатор',
            prompt: 'Введите название организатора',
          ),
        ],
        columns: const <TournamentTemplateColumn>[
          TournamentTemplateColumn(
              id: 'player',
              label: 'Участник',
              kind: TournamentTemplateColumnKind.player),
          TournamentTemplateColumn(
              id: 'rating',
              label: 'Рейтинг',
              kind: TournamentTemplateColumnKind.rating),
          TournamentTemplateColumn(
              id: 'school',
              label: 'Школа / клуб',
              kind: TournamentTemplateColumnKind.text),
          TournamentTemplateColumn(
              id: 'rounds',
              label: 'Туры',
              kind: TournamentTemplateColumnKind.games),
          TournamentTemplateColumn(
              id: 'points',
              label: 'Очки',
              kind: TournamentTemplateColumnKind.points),
          TournamentTemplateColumn(
              id: 'buchholz',
              label: 'Бухг.',
              kind: TournamentTemplateColumnKind.text),
          TournamentTemplateColumn(
              id: 'berger',
              label: 'Бергер',
              kind: TournamentTemplateColumnKind.text),
          TournamentTemplateColumn(
              id: 'personal',
              label: 'Личн.',
              kind: TournamentTemplateColumnKind.text),
          TournamentTemplateColumn(
              id: 'place',
              label: 'Место',
              kind: TournamentTemplateColumnKind.place),
        ],
        buttons: const <TournamentTemplateButton>[
          TournamentTemplateButton(
              id: 'edit',
              label: 'Редактировать данные',
              action: TournamentTemplateAction.editData),
          TournamentTemplateButton(
              id: 'save',
              label: 'Сохранить',
              action: TournamentTemplateAction.save),
          TournamentTemplateButton(
              id: 'call',
              label: 'Вызвать на турнир',
              action: TournamentTemplateAction.callTournament),
          TournamentTemplateButton(
              id: 'start',
              label: 'Начать турнир',
              action: TournamentTemplateAction.startTournament),
          TournamentTemplateButton(
              id: 'pause',
              label: 'Приостановить',
              action: TournamentTemplateAction.pauseTournament),
          TournamentTemplateButton(
              id: 'finish',
              label: 'Закончить',
              action: TournamentTemplateAction.finishTournament),
          TournamentTemplateButton(
              id: 'participate',
              label: 'Участвовать в турнире',
              action: TournamentTemplateAction.participate),
          TournamentTemplateButton(
              id: 'pairing',
              label: 'Жеребьёвка',
              action: TournamentTemplateAction.createPairing),
          TournamentTemplateButton(
              id: 'add',
              label: 'Добавить участника',
              action: TournamentTemplateAction.addParticipant),
          TournamentTemplateButton(
              id: 'print',
              label: 'Печать',
              action: TournamentTemplateAction.printTable),
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'fields': fields.map((item) => item.toJson()).toList(),
        'columns': columns.map((item) => item.toJson()).toList(),
        'buttons': buttons.map((item) => item.toJson()).toList(),
        'expandableRows': expandableRows,
        'rowCount': rowCount,
        'expandableColumns': expandableColumns,
        'layoutMode': layoutMode.name,
        'positions': positions.map((item) => item.toJson()).toList(),
      };

  factory TournamentTemplateSchema.fromJson(Object? value) {
    if (value is! Map) return TournamentTemplateSchema.defaults;
    final json = Map<String, dynamic>.from(value);
    List<T> decode<T>(Object? raw, T Function(Map<String, dynamic>) make) =>
        raw is List
            ? raw
                .whereType<Map>()
                .map((item) => make(Map<String, dynamic>.from(item)))
                .toList()
            : <T>[];
    return TournamentTemplateSchema(
      fields: decode(json['fields'], TournamentTemplateField.fromJson),
      columns: decode(json['columns'], TournamentTemplateColumn.fromJson),
      buttons: decode(json['buttons'], TournamentTemplateButton.fromJson),
      expandableRows: json['expandableRows'] != false,
      rowCount:
          ((json['rowCount'] as num?)?.toInt() ?? 8).clamp(1, 256).toInt(),
      expandableColumns: json['expandableColumns'] == true,
      layoutMode: TournamentTemplateLayoutMode.values.firstWhere(
        (item) => item.name == '${json['layoutMode'] ?? ''}',
        orElse: () => TournamentTemplateLayoutMode.automatic,
      ),
      positions: decode(
        json['positions'],
        TournamentTemplatePosition.fromJson,
      ),
    );
  }

  TournamentTemplateSchema copyWith({
    List<TournamentTemplateField>? fields,
    List<TournamentTemplateColumn>? columns,
    List<TournamentTemplateButton>? buttons,
    bool? expandableRows,
    int? rowCount,
    bool? expandableColumns,
    TournamentTemplateLayoutMode? layoutMode,
    List<TournamentTemplatePosition>? positions,
  }) =>
      TournamentTemplateSchema(
        fields: fields ?? this.fields,
        columns: columns ?? this.columns,
        buttons: buttons ?? this.buttons,
        expandableRows: expandableRows ?? this.expandableRows,
        rowCount: rowCount ?? this.rowCount,
        expandableColumns: expandableColumns ?? this.expandableColumns,
        layoutMode: layoutMode ?? this.layoutMode,
        positions: positions ?? this.positions,
      );
}

String tournamentColumnKindLabel(TournamentTemplateColumnKind kind) =>
    switch (kind) {
      TournamentTemplateColumnKind.text => 'Обычный текст',
      TournamentTemplateColumnKind.player => 'Имя игрока',
      TournamentTemplateColumnKind.avatar => 'Аватар',
      TournamentTemplateColumnKind.flag => 'Флаг страны',
      TournamentTemplateColumnKind.country => 'Название страны',
      TournamentTemplateColumnKind.rating => 'Рейтинг',
      TournamentTemplateColumnKind.points => 'Очки',
      TournamentTemplateColumnKind.place => 'Место',
      TournamentTemplateColumnKind.games => 'Количество партий',
    };

String tournamentActionLabel(TournamentTemplateAction action) =>
    switch (action) {
      TournamentTemplateAction.editData => 'Редактировать данные',
      TournamentTemplateAction.save => 'Сохранить',
      TournamentTemplateAction.callTournament => 'Вызвать на турнир',
      TournamentTemplateAction.participate => 'Участвовать в турнире',
      TournamentTemplateAction.addParticipant => 'Добавить игрока',
      TournamentTemplateAction.removeParticipant => 'Удалить игрока',
      TournamentTemplateAction.createPairing => 'Создать жеребьёвку',
      TournamentTemplateAction.enterResult => 'Внести результат',
      TournamentTemplateAction.startTournament => 'Начать турнир',
      TournamentTemplateAction.pauseTournament => 'Приостановить',
      TournamentTemplateAction.finishTournament => 'Закончить',
      TournamentTemplateAction.startRound => 'Начать тур',
      TournamentTemplateAction.finishRound => 'Завершить тур',
      TournamentTemplateAction.recalculate => 'Пересчитать таблицу',
      TournamentTemplateAction.publish => 'Опубликовать',
      TournamentTemplateAction.printTable => 'Печать',
    };
