import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_chess_app/ui/tournament/tournament_template_schema.dart';

void main() {
  test('template schema survives JSON round trip', () {
    final source = TournamentTemplateSchema.defaults.copyWith(
      expandableRows: false,
      rowCount: 24,
      expandableColumns: true,
      layoutMode: TournamentTemplateLayoutMode.coordinates,
      positions: const <TournamentTemplatePosition>[
        TournamentTemplatePosition(
          elementId: 'judge',
          xPercent: 12.5,
          yPercent: 8,
        ),
      ],
    );

    final restored = TournamentTemplateSchema.fromJson(source.toJson());

    expect(restored.fields.length, source.fields.length);
    expect(restored.columns.map((item) => item.kind),
        source.columns.map((item) => item.kind));
    expect(restored.buttons.map((item) => item.action),
        source.buttons.map((item) => item.action));
    expect(restored.expandableRows, isFalse);
    expect(restored.rowCount, 24);
    expect(restored.expandableColumns, isTrue);
    expect(restored.layoutMode, TournamentTemplateLayoutMode.coordinates);
    expect(restored.positions.single.elementId, 'judge');
    expect(restored.positions.single.xPercent, 12.5);
  });

  test('default schema separates static text from requested input', () {
    const staticField = TournamentTemplateField(
      id: 'creator',
      kind: TournamentTemplateFieldKind.staticText,
      label: 'Создатель шаблона',
      value: 'MakeChess',
    );
    const requestedField = TournamentTemplateField(
      id: 'judge',
      kind: TournamentTemplateFieldKind.input,
      label: 'Главный судья',
      prompt: 'Введите имя главного судьи',
      required: true,
    );

    final restored = TournamentTemplateSchema.fromJson(
      TournamentTemplateSchema(fields: [staticField, requestedField]).toJson(),
    );

    expect(restored.fields.first.kind, TournamentTemplateFieldKind.staticText);
    expect(restored.fields.first.value, 'MakeChess');
    expect(restored.fields.last.kind, TournamentTemplateFieldKind.input);
    expect(restored.fields.last.required, isTrue);
  });
}
