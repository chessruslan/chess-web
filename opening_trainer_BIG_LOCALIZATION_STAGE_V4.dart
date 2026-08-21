// MAKECHESS_BIG_LOCALIZATION_STAGE_V4_20260807
// MAKECHESS_OPENING_ADD_VARIANT_V16_20260806
// OPENING_TRAINER_PROGRAMMABLE_BOT_V8_20260805
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_style.dart';
import '../../localization/makechess_localization.dart';

// MAKECHESS_OPENING_NAMES_RU_V9_20260805
//
// Каталог Lichess хранится в исходном виде на английском языке.
// Эта функция переводит название только для интерфейса MakeChess.
// Оригинальные данные Selectel и лицензия источника не изменяются.
String _openingNameRu(String source) {
  var text = source.trim();
  if (text.isEmpty) return text;

  text = text
      .replaceAll('’', "'")
      .replaceAll('`', "'")
      .replaceAll('–', '-')
      .replaceAll('—', '-');

  final hasLatin = RegExp(r'[A-Za-z]').hasMatch(text);
  if (!hasLatin) return text;

  // Сначала переводим целые устойчивые названия. Порядок важен:
  // более длинные выражения расположены выше коротких.
  const phrases = <MapEntry<String, String>>[
    MapEntry("King's Indian Defense", 'Староиндийская защита'),
    MapEntry("Queen's Indian Defense", 'Новоиндийская защита'),
    MapEntry('Nimzo-Indian Defense', 'Защита Нимцовича'),
    MapEntry('Bogo-Indian Defense', 'Защита Боголюбова'),
    MapEntry('Old Indian Defense', 'Староиндийское начало'),
    MapEntry('Indian Game', 'Индийская защита'),
    MapEntry('Grunfeld Defense', 'Защита Грюнфельда'),
    MapEntry('Grünfeld Defense', 'Защита Грюнфельда'),
    MapEntry('Semi-Slav Defense', 'Полуславянская защита'),
    MapEntry('Slav Defense', 'Славянская защита'),
    MapEntry('Sicilian Defense', 'Сицилианская защита'),
    MapEntry('French Defense', 'Французская защита'),
    MapEntry('Caro-Kann Defense', 'Защита Каро — Канн'),
    MapEntry('Scandinavian Defense', 'Скандинавская защита'),
    MapEntry('Alekhine Defense', 'Защита Алехина'),
    MapEntry('Pirc Defense', 'Защита Пирца — Уфимцева'),
    MapEntry('Modern Defense', 'Современная защита'),
    MapEntry('Dutch Defense', 'Голландская защита'),
    MapEntry('Benoni Defense', 'Защита Бенони'),
    MapEntry('Benko Gambit', 'Гамбит Бенко'),
    MapEntry('Budapest Gambit', 'Будапештский гамбит'),
    MapEntry('Philidor Defense', 'Защита Филидора'),
    MapEntry("Petrov's Defense", 'Русская партия'),
    MapEntry('Russian Game', 'Русская партия'),
    MapEntry('Ruy Lopez', 'Испанская партия'),
    MapEntry('Spanish Game', 'Испанская партия'),
    MapEntry('Italian Game', 'Итальянская партия'),
    MapEntry('Scotch Game', 'Шотландская партия'),
    MapEntry('Vienna Game', 'Венская партия'),
    MapEntry('Four Knights Game', 'Дебют четырёх коней'),
    MapEntry('Three Knights Opening', 'Дебют трёх коней'),
    MapEntry("Queen's Gambit", 'Ферзевый гамбит'),
    MapEntry("King's Gambit", 'Королевский гамбит'),
    MapEntry("Queen's Pawn Game", 'Дебют ферзевой пешки'),
    MapEntry("King's Pawn Game", 'Дебют королевской пешки'),
    MapEntry('English Opening', 'Английское начало'),
    MapEntry('Catalan Opening', 'Каталонское начало'),
    MapEntry('Reti Opening', 'Дебют Рети'),
    MapEntry('Réti Opening', 'Дебют Рети'),
    MapEntry("Bird's Opening", 'Дебют Бёрда'),
    MapEntry('Bird Opening', 'Дебют Бёрда'),
    MapEntry("Larsen's Opening", 'Дебют Ларсена'),
    MapEntry('Nimzowitsch-Larsen Attack', 'Дебют Нимцовича — Ларсена'),
    MapEntry('Polish Opening', 'Дебют Сокольского'),
    MapEntry('Sokolsky Opening', 'Дебют Сокольского'),
    MapEntry('Trompowsky Attack', 'Атака Тромповского'),
    MapEntry('London System', 'Лондонская система'),
    MapEntry('Colle System', 'Система Колле'),
    MapEntry('Stonewall Attack', 'Атака Стоунволл'),
    MapEntry('Evans Gambit', 'Гамбит Эванса'),
    MapEntry('Danish Gambit', 'Северный гамбит'),
    MapEntry('Latvian Gambit', 'Латышский гамбит'),
    MapEntry('Elephant Gambit', 'Гамбит слона'),
    MapEntry('Blackmar-Diemer Gambit', 'Гамбит Блэкмара — Димера'),
    MapEntry('Smith-Morra Gambit', 'Гамбит Смита — Морра'),
    MapEntry('Marshall Attack', 'Атака Маршалла'),
    MapEntry('Panov Attack', 'Атака Панова'),
    MapEntry('Grand Prix Attack', 'Атака Гран-при'),
    MapEntry('Wing Gambit', 'Фланговый гамбит'),
    MapEntry('Orthodox Defense', 'Ортодоксальная защита'),
    MapEntry('Tarrasch Defense', 'Защита Тарраша'),
    MapEntry('Chigorin Defense', 'Защита Чигорина'),
    MapEntry('Albin Countergambit', 'Контргамбит Альбина'),
    MapEntry('Englund Gambit', 'Гамбит Энглунда'),
    MapEntry('Owen Defense', 'Защита Оуэна'),
    MapEntry('Horwitz Defense', 'Защита Горвица'),
    MapEntry('Hippopotamus Defense', 'Защита «Гиппопотам»'),
    MapEntry('St. George Defense', 'Защита Святого Георгия'),
  ];

  for (final phrase in phrases) {
    text = text.replaceAll(
      RegExp(RegExp.escape(phrase.key), caseSensitive: false),
      phrase.value,
    );
  }

  // Оставшиеся английские слова переводятся или транслитерируются.
  text = text.replaceAllMapped(
    RegExp(r"[A-Za-z][A-Za-z'.-]*"),
    (match) => _openingWordRu(match.group(0)!),
  );

  return text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([,:;])'), r'$1')
      .replaceAll(RegExp(r'([,:;])(?=\S)'), r'$1 ')
      .replaceAll(' - ', ' — ')
      .trim();
}

String _openingWordRu(String source) {
  final original = source.trim();
  if (original.isEmpty) return original;

  final normalized = original
      .replaceAll('’', "'")
      .replaceAll('`', "'")
      .toLowerCase();

  const words = <String, String>{
    'variation': 'вариант',
    'variations': 'варианты',
    'defense': 'защита',
    'defence': 'защита',
    'attack': 'атака',
    'gambit': 'гамбит',
    'countergambit': 'контргамбит',
    'counterattack': 'контратака',
    'opening': 'начало',
    'game': 'партия',
    'system': 'система',
    'line': 'линия',
    'mainline': 'главный вариант',
    'main': 'главный',
    'accepted': 'принятый вариант',
    'declined': 'отказанный вариант',
    'classical': 'классический вариант',
    'modern': 'современный вариант',
    'traditional': 'традиционный вариант',
    'orthodox': 'ортодоксальный вариант',
    'closed': 'закрытый вариант',
    'open': 'открытый вариант',
    'semi-open': 'полуоткрытый вариант',
    'exchange': 'разменный вариант',
    'advance': 'вариант с продвижением',
    'accelerated': 'ускоренный вариант',
    'hyperaccelerated': 'гиперускоренный вариант',
    'deferred': 'отложенный вариант',
    'delayed': 'отложенный вариант',
    'improved': 'улучшенный вариант',
    'early': 'ранний вариант',
    'old': 'старый вариант',
    'new': 'новый вариант',
    'quiet': 'спокойный вариант',
    'sharp': 'острый вариант',
    'double': 'двойной',
    'four': 'четыре',
    'three': 'три',
    'two': 'два',
    'knights': 'кони',
    'knight': 'конь',
    'bishop': 'слон',
    'bishops': 'слоны',
    'queen': 'ферзь',
    "queen's": 'ферзевый',
    'king': 'король',
    "king's": 'королевский',
    'pawn': 'пешка',
    'pawns': 'пешки',
    'poisoned': 'отравленная',
    'wing': 'фланговый',
    'dragon': 'дракон',
    'fianchetto': 'фианкетто',
    'trap': 'ловушка',
    'check': 'шах',
    'center': 'центр',
    'central': 'центральный',
    'side': 'фланговый',
    'retreat': 'отступление',
    'sacrifice': 'жертва',
    'minor': 'малый',
    'major': 'главный',
    'anti': 'анти',
    'anti-': 'анти-',
    'najdorf': 'Найдорф',
    'scheveningen': 'Схевенинген',
    'sveshnikov': 'Свешников',
    'kalashnikov': 'Калашников',
    'rossolimo': 'Россолимо',
    'alapin': 'Алапин',
    'paulsen': 'Паульсен',
    'kan': 'Кан',
    'taimanov': 'Тайманов',
    'richter-rauzer': 'Рихтер — Раузер',
    'sozin': 'Созин',
    'moscow': 'Московский вариант',
    'bowdler': 'Боудлер',
    'maroczy': 'Мароци',
    'bind': 'построение',
    'winawer': 'Винавер',
    'tarrasch': 'Тарраш',
    'rubinstein': 'Рубинштейн',
    'maccutcheon': 'Мак-Кэтчон',
    'steinitz': 'Стейниц',
    'burn': 'Бёрн',
    'fort': 'Форт',
    'panov': 'Панов',
    'botvinnik': 'Ботвинник',
    'capablanca': 'Капабланка',
    'tal': 'Таль',
    'fischer': 'Фишер',
    'kasparov': 'Каспаров',
    'karpov': 'Карпов',
    'kramnik': 'Крамник',
    'spassky': 'Спасский',
    'geller': 'Геллер',
    'petrosian': 'Петросян',
    'smyslov': 'Смыслов',
    'lasker': 'Ласкер',
    'marshall': 'Маршалл',
    'morphy': 'Морфи',
    'berlin': 'Берлинский вариант',
    'arkhangelsk': 'Архангельский вариант',
    'breyer': 'Брейер',
    'zaitsev': 'Зайцев',
    'chigorin': 'Чигорин',
    'schliemann': 'Шлиман',
    'cozio': 'Коцио',
    'moller': 'Мёллер',
    'giuoco': 'Джиуоко',
    'pianissimo': 'Пианиссимо',
    'fried': 'жареный',
    'liver': 'печень',
    'max': 'Макс',
    'lange': 'Ланге',
    'evans': 'Эванс',
    'philidor': 'Филидор',
    'petrov': 'Петров',
    'scotch': 'Шотландский',
    'vienna': 'Венский',
    'italian': 'Итальянский',
    'spanish': 'Испанский',
    'english': 'Английский',
    'french': 'Французский',
    'sicilian': 'Сицилианский',
    'scandinavian': 'Скандинавский',
    'dutch': 'Голландский',
    'slav': 'Славянский',
    'catalan': 'Каталонский',
    'hungarian': 'Венгерский',
    'polish': 'Польский',
    'danish': 'Северный',
    'latvian': 'Латышский',
    'grunfeld': 'Грюнфельд',
    'grünfeld': 'Грюнфельд',
    'nimzowitsch': 'Нимцович',
    'bogo': 'Бого',
    'benoni': 'Бенони',
    'benko': 'Бенко',
    'budapest': 'Будапешт',
    'alekhine': 'Алехин',
    'caro-kann': 'Каро — Канн',
    'pirc': 'Пирц',
    'owen': 'Оуэн',
    'london': 'Лондонский',
    'colle': 'Колле',
    'trompowsky': 'Тромповский',
    'reti': 'Рети',
    'réti': 'Рети',
    'bird': 'Бёрд',
    "bird's": 'Бёрда',
    'larsen': 'Ларсен',
    "larsen's": 'Ларсена',
    'sokolsky': 'Сокольский',
    'zukertort': 'Цукерторт',
    'grob': 'Гроб',
    'ware': 'Уэр',
    'barnes': 'Барнс',
    'mieses': 'Мизес',
    'anderssen': 'Андерсен',
    "anderssen's": 'Андерсена',
    'saragosse': 'Сарагосса',
    'saragossa': 'Сарагосса',
    'kadas': 'Кадаш',
    'van': 'Ван',
    'kruijs': 'Крёйса',
  };

  final known = words[normalized];
  if (known != null) return known;

  var possessive = false;
  var word = normalized;
  if (word.endsWith("'s") && word.length > 2) {
    possessive = true;
    word = word.substring(0, word.length - 2);
  }

  final transliterated = _transliterateOpeningWord(word);
  if (!possessive) return transliterated;
  return transliterated.endsWith('а') ? transliterated : '${transliterated}а';
}

String _transliterateOpeningWord(String source) {
  var word = source.toLowerCase();

  const chunks = <MapEntry<String, String>>[
    MapEntry('sch', 'ш'),
    MapEntry('tch', 'ч'),
    MapEntry('sh', 'ш'),
    MapEntry('ch', 'ч'),
    MapEntry('zh', 'ж'),
    MapEntry('ph', 'ф'),
    MapEntry('th', 'т'),
    MapEntry('ck', 'к'),
    MapEntry('qu', 'кв'),
    MapEntry('wh', 'в'),
    MapEntry('wr', 'р'),
    MapEntry('kn', 'н'),
    MapEntry('oo', 'у'),
    MapEntry('ee', 'и'),
    MapEntry('ea', 'и'),
    MapEntry('ai', 'ай'),
    MapEntry('ay', 'ей'),
    MapEntry('oy', 'ой'),
    MapEntry('ou', 'ау'),
    MapEntry('au', 'о'),
    MapEntry('ei', 'ей'),
    MapEntry('ie', 'и'),
  ];

  final protected = <String>[];
  for (final entry in chunks) {
    word = word.replaceAllMapped(
      RegExp(RegExp.escape(entry.key)),
      (_) {
        protected.add(entry.value);
        return '§${protected.length - 1}§';
      },
    );
  }

  const letters = <String, String>{
    'a': 'а',
    'b': 'б',
    'c': 'к',
    'd': 'д',
    'e': 'е',
    'f': 'ф',
    'g': 'г',
    'h': 'х',
    'i': 'и',
    'j': 'дж',
    'k': 'к',
    'l': 'л',
    'm': 'м',
    'n': 'н',
    'o': 'о',
    'p': 'п',
    'q': 'к',
    'r': 'р',
    's': 'с',
    't': 'т',
    'u': 'у',
    'v': 'в',
    'w': 'в',
    'x': 'кс',
    'y': 'й',
    'z': 'з',
    '-': '-',
    '.': '.',
    "'": '',
  };

  final result = StringBuffer();
  for (var index = 0; index < word.length;) {
    if (word[index] == '§') {
      final end = word.indexOf('§', index + 1);
      if (end > index) {
        final token = int.tryParse(word.substring(index + 1, end));
        if (token != null && token >= 0 && token < protected.length) {
          result.write(protected[token]);
          index = end + 1;
          continue;
        }
      }
    }
    result.write(letters[word[index]] ?? word[index]);
    index++;
  }

  final value = result.toString();
  if (value.isEmpty) return source;
  return value[0].toUpperCase() + value.substring(1);
}

/// Анализ одной позиции. Оценка [score] должна быть нормализована:
/// чем больше значение, тем лучше ход для стороны, которая сейчас ходит.
class OpeningEngineLine {
  const OpeningEngineLine({
    required this.uci,
    required this.score,
    this.san,
    this.pv = const <String>[],
    this.mate,
  });

  final String uci;
  final String? san;
  final double score;
  final List<String> pv;
  final int? mate;

  String get shownMove => (san == null || san!.trim().isEmpty) ? uci : san!;

  OpeningEngineLine copyWith({
    String? uci,
    String? san,
    double? score,
    List<String>? pv,
    int? mate,
  }) {
    return OpeningEngineLine(
      uci: uci ?? this.uci,
      san: san ?? this.san,
      score: score ?? this.score,
      pv: pv ?? this.pv,
      mate: mate ?? this.mate,
    );
  }
}

typedef OpeningPositionAnalyzer = Future<List<OpeningEngineLine>> Function(
  String fen,
  int multiPv,
  List<String> searchMoves,
);

typedef OpeningBotMovePlayer = Future<void> Function(String uci);

enum OpeningBotMoveSource {
  stockfish,
  openingTree,
}

extension OpeningBotMoveSourceTitle on OpeningBotMoveSource {
  String get title {
    switch (this) {
      case OpeningBotMoveSource.stockfish:
        return 'По Stockfish';
      case OpeningBotMoveSource.openingTree:
        return 'По дебютному древу';
    }
  }

  String get description {
    switch (this) {
      case OpeningBotMoveSource.stockfish:
        return 'Линии 1–5 — пять лучших ходов Stockfish среди всех легальных ходов позиции.';
      case OpeningBotMoveSource.openingTree:
        return 'Линии 1–5 — только ветви выбранного дебюта, отсортированные Stockfish от лучшей к худшей.';
    }
  }
}

/// Разбирает правила вида: «все», «1,3,5», «1-3,7», «1,3,4-8», «6-».
class OpeningBotReplyRuleParser {
  const OpeningBotReplyRuleParser._();

  static String normalize(String source) {
    return source
        .trim()
        .toLowerCase()
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(';', ',')
        .replaceAll(RegExp(r'\s+'), ',')
        .replaceAll(RegExp(r',+'), ',')
        .replaceAll(RegExp(r'^,|,$'), '');
  }

  static bool isAll(String source) {
    final value = normalize(source);
    return value == '*' || value == 'все' || value == 'all';
  }

  static List<(int, int?)> parseRanges(String source) {
    final normalized = normalize(source);
    if (normalized.isEmpty) return const <(int, int?)>[];
    if (isAll(normalized)) return const <(int, int?)>[(1, null)];

    final result = <(int, int?)>[];
    for (final token in normalized.split(',')) {
      if (token.isEmpty) continue;
      final direct = int.tryParse(token);
      if (direct != null) {
        if (direct < 1) {
          throw const FormatException(
            'Номера ответных ходов бота начинаются с 1.',
          );
        }
        result.add((direct, direct));
        continue;
      }

      final match = RegExp(r'^(\d+)-(\d*)$').firstMatch(token);
      if (match == null) {
        throw FormatException(
          'Не удалось понять фрагмент «$token». '
          'Пример правильной записи: 1,3,4-8.',
        );
      }

      final start = int.parse(match.group(1)!);
      final endText = match.group(2)!;
      final int? end = endText.isEmpty ? null : int.parse(endText);
      if (start < 1 || (end != null && end < start)) {
        throw FormatException('Неверный диапазон «$token».');
      }
      result.add((start, end));
    }
    return result;
  }

  static bool matches(String source, int botReplyNumber) {
    if (botReplyNumber < 1) return false;
    for (final range in parseRanges(source)) {
      final start = range.$1;
      final end = range.$2;
      if (botReplyNumber >= start &&
          (end == null || botReplyNumber <= end)) {
        return true;
      }
    }
    return false;
  }

  static String? validateRuleSet(
    Map<int, String> rules, {
    int maxReplyNumber = 120,
  }) {
    for (var line = 1; line <= 5; line++) {
      try {
        parseRanges(rules[line] ?? '');
      } on FormatException catch (error) {
        return 'Линия $line: ${error.message}';
      }
    }

    for (var reply = 1; reply <= maxReplyNumber; reply++) {
      final owners = <int>[];
      for (var line = 1; line <= 5; line++) {
        try {
          if (matches(rules[line] ?? '', reply)) owners.add(line);
        } catch (_) {
          // Ошибка формата уже обработана выше.
        }
      }
      if (owners.length > 1) {
        return 'Ответный ход бота №$reply назначен одновременно '
            'линиям ${owners.join(', ')}.';
      }
    }
    return null;
  }

  static int lineForReply(Map<int, String> rules, int botReplyNumber) {
    for (var line = 1; line <= 5; line++) {
      if (matches(rules[line] ?? '', botReplyNumber)) return line;
    }
    // Незаписанные номера всегда идут по первой линии.
    return 1;
  }
}

class OpeningTrainerSettings {
  const OpeningTrainerSettings({
    this.depthFullMoves = 10,
    this.maxVariants = 4,
    this.maxEvaluationDrop = 0.20,
    this.botMoveSource = OpeningBotMoveSource.openingTree,
    this.cyclesPerSession = 1,
    this.gamesPerCycle = 1,
    this.identicalResponseGames = 1,
    this.stockfishLineRules = const <int, String>{
      1: 'все',
      2: '',
      3: '',
      4: '',
      5: '',
    },
    this.openingTreeLineRules = const <int, String>{
      1: 'все',
      2: '',
      3: '',
      4: '',
      5: '',
    },
    this.botEngineDepth = 18,
    this.botThinkingTimeMs = 2400,
    this.botMoveDelayMs = 450,
  });

  final int depthFullMoves;
  final int maxVariants;

  /// Фильтр учебных стрелок. На программируемые линии бота не влияет.
  final double maxEvaluationDrop;

  final OpeningBotMoveSource botMoveSource;
  final int cyclesPerSession;
  final int gamesPerCycle;
  final int identicalResponseGames;
  final Map<int, String> stockfishLineRules;
  final Map<int, String> openingTreeLineRules;
  final int botEngineDepth;
  final int botThinkingTimeMs;
  final int botMoveDelayMs;

  int get maxPly => depthFullMoves * 2;
  int get totalGamesPerSession => cyclesPerSession * gamesPerCycle;

  Map<int, String> rulesFor(OpeningBotMoveSource source) {
    return source == OpeningBotMoveSource.stockfish
        ? stockfishLineRules
        : openingTreeLineRules;
  }

  int lineForBotReply(
    OpeningBotMoveSource source,
    int botReplyNumber,
  ) {
    return OpeningBotReplyRuleParser.lineForReply(
      rulesFor(source),
      botReplyNumber,
    );
  }

  OpeningTrainerSettings copyWith({
    int? depthFullMoves,
    int? maxVariants,
    double? maxEvaluationDrop,
    OpeningBotMoveSource? botMoveSource,
    int? cyclesPerSession,
    int? gamesPerCycle,
    int? identicalResponseGames,
    Map<int, String>? stockfishLineRules,
    Map<int, String>? openingTreeLineRules,
    int? botEngineDepth,
    int? botThinkingTimeMs,
    int? botMoveDelayMs,
  }) {
    return OpeningTrainerSettings(
      depthFullMoves: depthFullMoves ?? this.depthFullMoves,
      maxVariants: maxVariants ?? this.maxVariants,
      maxEvaluationDrop: maxEvaluationDrop ?? this.maxEvaluationDrop,
      botMoveSource: botMoveSource ?? this.botMoveSource,
      cyclesPerSession: cyclesPerSession ?? this.cyclesPerSession,
      gamesPerCycle: gamesPerCycle ?? this.gamesPerCycle,
      identicalResponseGames:
          identicalResponseGames ?? this.identicalResponseGames,
      stockfishLineRules: Map<int, String>.unmodifiable(
        stockfishLineRules ?? this.stockfishLineRules,
      ),
      openingTreeLineRules: Map<int, String>.unmodifiable(
        openingTreeLineRules ?? this.openingTreeLineRules,
      ),
      botEngineDepth: botEngineDepth ?? this.botEngineDepth,
      botThinkingTimeMs: botThinkingTimeMs ?? this.botThinkingTimeMs,
      botMoveDelayMs: botMoveDelayMs ?? this.botMoveDelayMs,
    );
  }
}

enum OpeningTrainerMode {
  selectedOpening,
  automaticStockfish,
  automaticTree,
  automaticCombined,
  free,
}

extension OpeningTrainerModeTitle on OpeningTrainerMode {
  String get title {
    switch (this) {
      case OpeningTrainerMode.selectedOpening:
        return 'Выбранный дебют';
      case OpeningTrainerMode.automaticStockfish:
        return 'Автоматический выбор по Stockfish';
      case OpeningTrainerMode.automaticTree:
        return 'Автоматический выбор по дебютному древу';
      case OpeningTrainerMode.automaticCombined:
        return 'Автоматический комбинированный режим';
      case OpeningTrainerMode.free:
        return 'Свободный режим';
    }
  }
}

enum OpeningSelectionSort {
  firstMoves,
  name,
  popularity,
  efficiency,
}

extension OpeningSelectionSortTitle on OpeningSelectionSort {
  String get title {
    switch (this) {
      case OpeningSelectionSort.firstMoves:
        return 'по первым ходам';
      case OpeningSelectionSort.name:
        return 'по названию';
      case OpeningSelectionSort.popularity:
        return 'по популярности';
      case OpeningSelectionSort.efficiency:
        return 'по эффективности';
    }
  }
}

class OpeningTreeMove {
  OpeningTreeMove({
    required this.uci,
    this.title,
    OpeningTreeNode? next,
  }) : next = next ?? OpeningTreeNode();

  final String uci;
  final String? title;
  final OpeningTreeNode next;
}

class OpeningTreeNode {
  final LinkedHashMap<String, OpeningTreeMove> moves = LinkedHashMap();

  bool get isLeaf => moves.isEmpty;

  OpeningTreeMove addMove(String uci, {String? title}) {
    final normalized = _normalizeUci(uci);
    return moves.putIfAbsent(
      normalized,
      () => OpeningTreeMove(uci: normalized, title: title),
    );
  }
}

class OpeningTree {
  OpeningTree({
    required this.id,
    required this.name,
    required this.root,
    this.startFen = 'startpos',
    this.studentColor = 'white',
    this.sourceName,
    this.sourceLicense,
  });

  final String id;
  final String name;
  final OpeningTreeNode root;
  final String startFen;
  final String studentColor;
  final String? sourceName;
  final String? sourceLicense;

  bool get studentPlaysWhite => studentColor.toLowerCase() != 'black';

  OpeningTreeNode? nodeAt(List<String> historyUci) {
    var node = root;
    for (final raw in historyUci) {
      final move = node.moves[_normalizeUci(raw)];
      if (move == null) return null;
      node = move.next;
    }
    return node;
  }

  factory OpeningTree.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('JSON дебюта должен быть объектом.');
    }
    return OpeningTree.fromJson(Map<String, dynamic>.from(decoded));
  }

  factory OpeningTree.fromJson(Map<String, dynamic> json) {
    final root = OpeningTreeNode();
    final linesRaw = json['lines'] ?? json['branches'] ?? json['variations'];

    if (linesRaw is List) {
      for (final item in linesRaw) {
        List<dynamic>? rawMoves;
        String? title;
        if (item is List) {
          rawMoves = item;
        } else if (item is Map) {
          rawMoves = item['moves'] is List
              ? item['moves'] as List
              : item['uci'] is List
                  ? item['uci'] as List
                  : null;
          title = _openingNameRu(
            '${item['title'] ?? item['name'] ?? ''}'.trim(),
          );
        }
        if (rawMoves == null) continue;

        var node = root;
        for (var i = 0; i < rawMoves.length; i++) {
          final uci = _normalizeUci('${rawMoves[i]}');
          if (uci.isEmpty) continue;
          final edge = node.addMove(
            uci,
            title: i == rawMoves.length - 1 && title != null && title.isNotEmpty
                ? title
                : null,
          );
          node = edge.next;
        }
      }
    } else if (json['root'] is Map) {
      _fillNestedNode(
        root,
        Map<String, dynamic>.from(json['root'] as Map),
      );
    } else {
      throw const FormatException(
        'В JSON нет массива lines/branches/variations или объекта root.',
      );
    }

    if (root.moves.isEmpty) {
      throw const FormatException('В дебюте не найдено ни одной линии ходов.');
    }

    final id = '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}'.trim();
    final name = '${json['name'] ?? json['title'] ?? 'Загруженный дебют'}'.trim();
    final studentColor = '${json['studentColor'] ?? json['student_color'] ?? 'white'}'
        .trim()
        .toLowerCase();

    return OpeningTree(
      id: id.isEmpty ? '${DateTime.now().microsecondsSinceEpoch}' : id,
      name: _openingNameRu(
        name.isEmpty ? 'Загруженный дебют' : name,
      ),
      root: root,
      startFen: '${json['startFen'] ?? json['start_fen'] ?? 'startpos'}'.trim(),
      studentColor: studentColor == 'black' ? 'black' : 'white',
      sourceName: '${json['sourceName'] ?? json['source_name'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['sourceName'] ?? json['source_name']}',
      sourceLicense:
          '${json['sourceLicense'] ?? json['source_license'] ?? ''}'.trim().isEmpty
              ? null
              : '${json['sourceLicense'] ?? json['source_license']}',
    );
  }

  static void _fillNestedNode(
    OpeningTreeNode target,
    Map<String, dynamic> json,
  ) {
    final movesRaw = json['moves'];
    if (movesRaw is! List) return;

    for (final item in movesRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final uci = _normalizeUci('${map['uci'] ?? map['move'] ?? ''}');
      if (uci.isEmpty) continue;
      final edge = target.addMove(
        uci,
        title: '${map['title'] ?? map['name'] ?? ''}'.trim().isEmpty
            ? null
            : _openingNameRu('${map['title'] ?? map['name']}'),
      );
      final nextRaw = map['next'] ?? map['node'];
      if (nextRaw is Map) {
        _fillNestedNode(edge.next, Map<String, dynamic>.from(nextRaw));
      }
    }
  }
}

class OpeningDatabaseItem {
  const OpeningDatabaseItem({
    required this.id,
    required this.name,
    required this.databaseName,
    required this.studentColor,
    required this.startFen,
    required this.openingJson,
    required this.popularity,
    required this.whiteEfficiency,
    required this.blackEfficiency,
    required this.firstMovesUci,
    this.sourceName,
    this.sourceLicense,
  });

  final String id;

  /// Русское имя для интерфейса MakeChess.
  final String name;

  /// Исходное английское имя строки Selectel/Lichess.
  /// Используется только в запросах к базе и никогда не переводится.
  final String databaseName;

  final String studentColor;
  final String startFen;
  final String? sourceName;
  final String? sourceLicense;
  final Map<String, dynamic> openingJson;
  final double popularity;
  final double whiteEfficiency;
  final double blackEfficiency;
  final List<String> firstMovesUci;

  double efficiencyFor(String color) =>
      color.toLowerCase() == 'black' ? blackEfficiency : whiteEfficiency;

  String get firstMovesLabel => firstMovesUci.isEmpty
      ? 'ходы не указаны'
      : firstMovesUci.take(8).join(' ');

  factory OpeningDatabaseItem.fromRow(Map<String, dynamic> row) {
    final rawJson = row['opening_json'];
    late final Map<String, dynamic> openingJson;

    if (rawJson is Map) {
      openingJson = Map<String, dynamic>.from(rawJson);
    } else if (rawJson is String) {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const FormatException(
          'Поле opening_json должно содержать JSON-объект.',
        );
      }
      openingJson = Map<String, dynamic>.from(decoded);
    } else if (rawJson == null) {
      // Для списка дебютов загружаем только лёгкие поля каталога.
      // Полное дерево выбранного дебюта запрашивается отдельно.
      openingJson = <String, dynamic>{
        if (row['first_moves'] != null) 'firstMoves': row['first_moves'],
        if (row['popularity'] != null) 'popularity': row['popularity'],
        if (row['white_efficiency'] != null)
          'whiteEfficiency': row['white_efficiency'],
        if (row['black_efficiency'] != null)
          'blackEfficiency': row['black_efficiency'],
      };
    } else {
      throw const FormatException(
        'В записи Selectel отсутствует корректное поле opening_json.',
      );
    }

    final id = '${row['id'] ?? openingJson['id'] ?? ''}'.trim();
    final name = '${row['name'] ?? openingJson['name'] ?? ''}'.trim();
    final studentColor =
        '${row['student_color'] ?? openingJson['studentColor'] ?? 'white'}'
            .trim()
            .toLowerCase();
    final startFen =
        '${row['start_fen'] ?? openingJson['startFen'] ?? 'startpos'}'.trim();
    final sourceName =
        '${row['source_name'] ?? openingJson['sourceName'] ?? ''}'.trim();
    final sourceLicense =
        '${row['source_license'] ?? openingJson['sourceLicense'] ?? ''}'.trim();

    double numberFrom(Iterable<String> keys, {double fallback = 0}) {
      for (final key in keys) {
        final raw = row[key] ?? openingJson[key];
        if (raw is num) return raw.toDouble();
        final parsed = double.tryParse('${raw ?? ''}'.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    List<String> firstMoves() {
      final explicit = row['first_moves'] ??
          openingJson['firstMoves'] ??
          openingJson['first_moves'];
      if (explicit is List) {
        return explicit
            .map((value) => _normalizeUci('$value'))
            .where(_isUciMove)
            .take(12)
            .toList(growable: false);
      }
      final lines = openingJson['lines'] ??
          openingJson['branches'] ??
          openingJson['variations'];
      if (lines is! List || lines.isEmpty) return const <String>[];
      final first = lines.first;
      dynamic rawMoves;
      if (first is List) {
        rawMoves = first;
      } else if (first is Map) {
        rawMoves = first['moves'] ?? first['uci'];
      }
      if (rawMoves is! List) return const <String>[];
      return rawMoves
          .map((value) => _normalizeUci('$value'))
          .where(_isUciMove)
          .take(12)
          .toList(growable: false);
    }

    final genericEfficiency = numberFrom(
      const <String>['efficiency', 'scoreRate', 'score_rate'],
    );

    final databaseName = name.isEmpty ? 'Unnamed opening' : name;

    return OpeningDatabaseItem(
      id: id.isEmpty ? '${DateTime.now().microsecondsSinceEpoch}' : id,
      name: _openingNameRu(
        name.isEmpty ? 'Дебют без названия' : name,
      ),
      databaseName: databaseName,
      studentColor: studentColor == 'black' ? 'black' : 'white',
      startFen: startFen.isEmpty ? 'startpos' : startFen,
      sourceName: sourceName.isEmpty ? null : sourceName,
      sourceLicense: sourceLicense.isEmpty ? null : sourceLicense,
      openingJson: openingJson,
      popularity: numberFrom(
        const <String>['popularity', 'games', 'playCount', 'play_count'],
      ),
      whiteEfficiency: numberFrom(
        const <String>[
          'whiteEfficiency',
          'white_efficiency',
          'efficiencyWhite',
          'efficiency_white',
        ],
        fallback: genericEfficiency,
      ),
      blackEfficiency: numberFrom(
        const <String>[
          'blackEfficiency',
          'black_efficiency',
          'efficiencyBlack',
          'efficiency_black',
        ],
        fallback: genericEfficiency,
      ),
      firstMovesUci: firstMoves(),
    );
  }

  OpeningTree toTree() {
    final json = Map<String, dynamic>.from(openingJson);
    json.putIfAbsent('id', () => id);
    // В полном JSON Lichess имя английское. Для интерфейса
    // принудительно используем уже локализованное имя каталога.
    json['name'] = name;
    json.putIfAbsent('studentColor', () => studentColor);
    json.putIfAbsent('startFen', () => startFen);
    if (sourceName != null) {
      json.putIfAbsent('sourceName', () => sourceName);
    }
    if (sourceLicense != null) {
      json.putIfAbsent('sourceLicense', () => sourceLicense);
    }

    final rawLines = json['lines'];
    if (rawLines is List) {
      json['lines'] = rawLines.map((rawLine) {
        if (rawLine is! Map) return rawLine;
        final line = Map<String, dynamic>.from(rawLine);
        final title = '${line['title'] ?? line['name'] ?? ''}'.trim();
        if (title.isNotEmpty) {
          line['title'] = _openingNameRu(title);
        }
        return line;
      }).toList(growable: false);
    }

    final hasLines = json['lines'] is List ||
        json['branches'] is List ||
        json['variations'] is List ||
        json['moves'] is List;
    if (!hasLines && firstMovesUci.isNotEmpty) {
      json['lines'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'title': name,
          'moves': firstMovesUci,
        },
      ];
    }

    return OpeningTree.fromJson(json);
  }
}

class _OpeningPreviewBranch {
  const _OpeningPreviewBranch({
    required this.title,
    required this.moves,
    required this.startFen,
  });

  final String title;
  final List<String> moves;
  final String startFen;
}

List<_OpeningPreviewBranch> _previewBranchesFromDatabaseItem(
  OpeningDatabaseItem item, {
  int limit = 4,
}) {
  final allBranches = <_OpeningPreviewBranch>[];
  final seen = <String>{};

  void addBranch(
    String title,
    Iterable<dynamic> rawMoves, {
    String? startFen,
  }) {
    final moves = rawMoves
        .map((value) => _normalizeUci('$value'))
        .where(_isUciMove)
        .toList(growable: false);
    if (moves.isEmpty) return;

    final signature = moves.join(' ');
    if (!seen.add(signature)) return;

    allBranches.add(
      _OpeningPreviewBranch(
        title: title.trim().isEmpty ? item.name : _openingNameRu(title),
        moves: moves,
        startFen: (startFen ?? item.startFen).trim().isEmpty
            ? 'startpos'
            : (startFen ?? item.startFen).trim(),
      ),
    );
  }

  final rawLines = item.openingJson['lines'] ??
      item.openingJson['branches'] ??
      item.openingJson['variations'];

  if (rawLines is List) {
    for (final rawLine in rawLines) {
      if (rawLine is List) {
        addBranch(item.name, rawLine);
        continue;
      }

      if (rawLine is Map) {
        final line = Map<String, dynamic>.from(rawLine);
        final rawMoves = line['moves'] ?? line['uci'];
        if (rawMoves is! List) continue;
        addBranch(
          '${line['title'] ?? line['name'] ?? item.name}',
          rawMoves,
          startFen: '${line['startFen'] ?? line['start_fen'] ?? item.startFen}',
        );
      }
    }
  }

  if (allBranches.isEmpty && item.firstMovesUci.isNotEmpty) {
    addBranch(item.name, item.firstMovesUci);
  }

  allBranches.sort((a, b) {
    final byLength = b.moves.length.compareTo(a.moves.length);
    if (byLength != 0) return byLength;
    return a.title.compareTo(b.title);
  });

  bool isStrictPrefix(
    List<String> shorter,
    List<String> longer,
  ) {
    if (shorter.length >= longer.length) return false;
    for (var index = 0; index < shorter.length; index++) {
      if (shorter[index] != longer[index]) return false;
    }
    return true;
  }

  final deepestBranches = <_OpeningPreviewBranch>[];

  for (final candidate in allBranches) {
    final onlyBeginningOfLongerLine = deepestBranches.any(
      (longer) => isStrictPrefix(candidate.moves, longer.moves),
    );
    if (onlyBeginningOfLongerLine) continue;

    deepestBranches.add(candidate);
    if (deepestBranches.length >= limit) break;
  }

  if (deepestBranches.isEmpty && allBranches.isNotEmpty) {
    deepestBranches.add(allBranches.first);
  }

  return List<_OpeningPreviewBranch>.unmodifiable(deepestBranches);
}
String _openingFamilyName(String name) {
  final colon = name.indexOf(':');
  return (colon < 0 ? name : name.substring(0, colon))
      .trim()
      .toLowerCase();
}

int _commonMovePrefix(List<String> first, List<String> second) {
  final max = math.min(first.length, second.length);
  var count = 0;
  while (count < max && first[count] == second[count]) {
    count++;
  }
  return count;
}

class _PreviewPiece {
  const _PreviewPiece({
    required this.id,
    required this.symbol,
    required this.square,
    required this.white,
    required this.kind,
  });

  final String id;
  final String symbol;
  final String square;
  final bool white;
  final String kind;

  _PreviewPiece copyWith({
    String? symbol,
    String? square,
    String? kind,
  }) {
    return _PreviewPiece(
      id: id,
      symbol: symbol ?? this.symbol,
      square: square ?? this.square,
      white: white,
      kind: kind ?? this.kind,
    );
  }
}

class _PreviewPosition {
  _PreviewPosition(this.pieces);

  final Map<String, _PreviewPiece> pieces;

  factory _PreviewPosition.fromFen(String fen) {
    final normalized = fen.trim();
    if (normalized.isEmpty || normalized == 'startpos') {
      return _PreviewPosition._standard();
    }

    final boardPart = normalized.split(RegExp(r'\s+')).first;
    final ranks = boardPart.split('/');
    if (ranks.length != 8) return _PreviewPosition._standard();

    final pieces = <String, _PreviewPiece>{};
    final counters = <String, int>{};

    for (var row = 0; row < 8; row++) {
      var file = 0;
      for (final rune in ranks[row].runes) {
        final token = String.fromCharCode(rune);
        final empty = int.tryParse(token);
        if (empty != null) {
          file += empty;
          continue;
        }
        if (file > 7) break;

        final white = token == token.toUpperCase();
        final kind = token.toLowerCase();
        final key = '${white ? 'w' : 'b'}_$kind';
        final number = (counters[key] ?? 0) + 1;
        counters[key] = number;
        final id = '${key}_$number';
        final square =
            '${String.fromCharCode('a'.codeUnitAt(0) + file)}${8 - row}';

        pieces[id] = _PreviewPiece(
          id: id,
          symbol: _PreviewPosition._symbol(kind, white),
          square: square,
          white: white,
          kind: kind,
        );
        file++;
      }
    }

    return pieces.isEmpty
        ? _PreviewPosition._standard()
        : _PreviewPosition(pieces);
  }

  factory _PreviewPosition._standard() {
    final pieces = <String, _PreviewPiece>{};

    void add(
      String id,
      String kind,
      bool white,
      String square,
    ) {
      pieces[id] = _PreviewPiece(
        id: id,
        symbol: _symbol(kind, white),
        square: square,
        white: white,
        kind: kind,
      );
    }

    const back = <String>['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'];
    for (var file = 0; file < 8; file++) {
      final letter = String.fromCharCode('a'.codeUnitAt(0) + file);
      add('w_${back[file]}_$file', back[file], true, '${letter}1');
      add('w_p_$file', 'p', true, '${letter}2');
      add('b_p_$file', 'p', false, '${letter}7');
      add('b_${back[file]}_$file', back[file], false, '${letter}8');
    }

    return _PreviewPosition(pieces);
  }

  static String _symbol(String kind, bool white) {
    const whitePieces = <String, String>{
      'k': '♔',
      'q': '♕',
      'r': '♖',
      'b': '♗',
      'n': '♘',
      'p': '♙',
    };
    const blackPieces = <String, String>{
      'k': '♚',
      'q': '♛',
      'r': '♜',
      'b': '♝',
      'n': '♞',
      'p': '♟',
    };
    return (white ? whitePieces : blackPieces)[kind] ?? '';
  }

  _PreviewPiece? pieceAt(String square) {
    for (final piece in pieces.values) {
      if (piece.square == square) return piece;
    }
    return null;
  }

  void applyUci(String rawMove) {
    final move = _normalizeUci(rawMove);
    if (!_isUciMove(move)) return;

    final from = move.substring(0, 2);
    final to = move.substring(2, 4);
    final promotion = move.length > 4 ? move.substring(4, 5) : '';

    final moving = pieceAt(from);
    if (moving == null) return;

    final target = pieceAt(to);
    if (target != null) {
      pieces.remove(target.id);
    }

    if (moving.kind == 'p' &&
        from.substring(0, 1) != to.substring(0, 1) &&
        target == null) {
      final toRank = int.tryParse(to.substring(1, 2)) ?? 1;
      final capturedRank = moving.white ? toRank - 1 : toRank + 1;
      final capturedSquare = '${to.substring(0, 1)}$capturedRank';
      final captured = pieceAt(capturedSquare);
      if (captured != null &&
          captured.kind == 'p' &&
          captured.white != moving.white) {
        pieces.remove(captured.id);
      }
    }

    if (moving.kind == 'k') {
      final rookMove = switch ('$from$to') {
        'e1g1' => ('h1', 'f1'),
        'e1c1' => ('a1', 'd1'),
        'e8g8' => ('h8', 'f8'),
        'e8c8' => ('a8', 'd8'),
        _ => null,
      };
      if (rookMove != null) {
        final rook = pieceAt(rookMove.$1);
        if (rook != null) {
          pieces[rook.id] = rook.copyWith(square: rookMove.$2);
        }
      }
    }

    var changed = moving.copyWith(square: to);
    if (moving.kind == 'p' && promotion.isNotEmpty) {
      changed = changed.copyWith(
        kind: promotion,
        symbol: _symbol(promotion, moving.white),
      );
    }
    pieces[moving.id] = changed;
  }
}

class _OpeningPreviewBoard extends StatefulWidget {
  const _OpeningPreviewBoard({
    super.key,
    required this.branch,
    required this.flipped,
  });

  final _OpeningPreviewBranch branch;
  final bool flipped;

  @override
  State<_OpeningPreviewBoard> createState() => _OpeningPreviewBoardState();
}

class _OpeningPreviewBoardState extends State<_OpeningPreviewBoard> {
  Timer? _timer;
  late _PreviewPosition _position;
  int _ply = 0;
  bool _playing = true;
  String? _lastMove;

  @override
  void initState() {
    super.initState();
    _resetPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startTimer();
    });
  }

  @override
  void didUpdateWidget(covariant _OpeningPreviewBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branch.title != widget.branch.title ||
        oldWidget.branch.moves.join(' ') != widget.branch.moves.join(' ')) {
      _restart();
    }
  }

  void _resetPosition() {
    _position = _PreviewPosition.fromFen(widget.branch.startFen);
    _ply = 0;
    _lastMove = null;
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_playing || widget.branch.moves.isEmpty) return;

    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted || !_playing) return;
      if (_ply >= widget.branch.moves.length) {
        setState(() => _playing = false);
        _timer?.cancel();
        return;
      }

      final move = widget.branch.moves[_ply];
      setState(() {
        _position.applyUci(move);
        _lastMove = move;
        _ply++;
      });
    });
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _resetPosition();
      _playing = true;
    });
    _startTimer();
  }

  void _togglePlay() {
    setState(() {
      if (_ply >= widget.branch.moves.length) {
        _resetPosition();
      }
      _playing = !_playing;
    });
    if (_playing) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Offset _squarePosition(String square, double cell) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square.substring(1, 2)) ?? 1;
    final column = widget.flipped ? 7 - file : file;
    final row = widget.flipped ? rank - 1 : 8 - rank;
    return Offset(column * cell, row * cell);
  }

  bool _isLastMoveSquare(String square) {
    final move = _lastMove;
    if (move == null || move.length < 4) return false;
    return square == move.substring(0, 2) || square == move.substring(2, 4);
  }

  Widget _board() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 230.0);
        final cell = size / 8;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var row = 0; row < 8; row++)
                for (var column = 0; column < 8; column++)
                  Positioned(
                    left: column * cell,
                    top: row * cell,
                    width: cell,
                    height: cell,
                    child: Builder(
                      builder: (context) {
                        final actualFile =
                            widget.flipped ? 7 - column : column;
                        final actualRank = widget.flipped ? row + 1 : 8 - row;
                        final square =
                            '${String.fromCharCode('a'.codeUnitAt(0) + actualFile)}$actualRank';
                        final light = (row + column).isEven;
                        final highlighted = _isLastMoveSquare(square);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: highlighted
                                ? const Color(0xFFB9A33B)
                                : light
                                    ? const Color(0xFFD6D1C9)
                                    : const Color(0xFF777A7D),
                          ),
                        );
                      },
                    ),
                  ),
              for (final piece in _position.pieces.values)
                AnimatedPositioned(
                  key: ValueKey(piece.id),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeInOutCubic,
                  left: _squarePosition(piece.square, cell).dx,
                  top: _squarePosition(piece.square, cell).dy,
                  width: cell,
                  height: cell,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          piece.symbol,
                          key: ValueKey('${piece.id}_${piece.symbol}'),
                          style: TextStyle(
                            fontSize: cell * 0.78,
                            height: 1,
                            color: piece.white
                                ? const Color(0xFFF7F7F7)
                                : const Color(0xFF111111),
                            shadows: const <Shadow>[
                              Shadow(
                                blurRadius: 1.5,
                                offset: Offset(0, 1),
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final totalPlies = widget.branch.moves.length;
    final lastMoveNumber = (totalPlies + 1) ~/ 2;
    final moveLabel = _lastMove == null
        ? 'Глубина ветви: $totalPlies полуходов; '
            'последний номер хода — $lastMoveNumber'
        : 'Полуход $_ply из $totalPlies: ${_lastMove!}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.r14,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.branch.title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                moveLabel,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  AppNeoButton(
                    text: MakeChessLocalization.phrase(_playing ? 'Пауза' : 'Продолжить'),
                    icon: _playing ? Icons.pause : Icons.play_arrow,
                    onTap: _togglePlay,
                    compact: true,
                  ),
                  AppNeoButton(
                    text: MakeChessLocalization.phrase('Сначала'),
                    icon: Icons.replay,
                    onTap: _restart,
                    compact: true,
                  ),
                ],
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(width: 230, child: _board()),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: details,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 230, child: _board()),
              const SizedBox(width: 14),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class OpeningMoveSuggestion {
  const OpeningMoveSuggestion({
    required this.uci,
    required this.score,
    required this.rank,
    required this.inOpeningTree,
    this.san,
    this.title,
    this.scoreAvailable = true,
    this.bookWeight = 0,
  });

  final String uci;
  final String? san;
  final double score;
  final int rank;
  final bool inOpeningTree;
  final String? title;
  final bool scoreAvailable;

  /// Реальная популярность хода, если она есть в базе.
  /// Ноль означает, что статистика ещё не загружена.
  final double bookWeight;

  String get shownMove => (san == null || san!.trim().isEmpty) ? uci : san!;
}

enum OpeningTrainerMessageKind {
  info,
  success,
  warning,
  error,
  bot,
  student,
}

class OpeningTrainerMessage {
  const OpeningTrainerMessage({
    required this.text,
    required this.kind,
    required this.createdAt,
  });

  final String text;
  final OpeningTrainerMessageKind kind;
  final DateTime createdAt;
}

enum OpeningTrainerPhase {
  noTree,
  idle,
  analyzing,
  studentTurn,
  botTurn,
  finished,
  error,
}

class OpeningTrainerBoardArrow {
  const OpeningTrainerBoardArrow({
    required this.from,
    required this.to,
    required this.color,
    required this.opacity,
    required this.widthFactor,
    required this.source,
    required this.rank,
  });

  final String from;
  final String to;
  final Color color;
  final double opacity;
  final double widthFactor;
  final String source;
  final int rank;
}

class OpeningTrainerController extends ChangeNotifier {
  OpeningTrainerController({
    OpeningTrainerSettings settings = const OpeningTrainerSettings(),
  }) : _settings = settings {
    _addMessage(
      'Загрузите дебют в настройках, затем нажмите «Начать».',
      OpeningTrainerMessageKind.info,
      notify: false,
    );
  }

  static const Color engineArrowColor = Color(0xFF68152E);
  static const Color openingArrowColor = Color(0xFF07513A);

  OpeningTrainerSettings _settings;
  OpeningTree? _tree;
  OpeningTrainerMode _mode = OpeningTrainerMode.selectedOpening;
  String _studentColor = 'white';
  List<OpeningDatabaseItem> _catalog = const <OpeningDatabaseItem>[];
  List<OpeningDatabaseItem> _matchingOpenings =
      const <OpeningDatabaseItem>[];
  String _lastOpeningSignature = '';
  OpeningTrainerPhase _phase = OpeningTrainerPhase.noTree;
  bool _sessionActive = false;
  bool _disposed = false;
  bool _analyzing = false;
  int _analysisEpoch = 0;
  String? _currentFen;
  bool _whiteToMove = true;
  final List<String> _historyUci = <String>[];
  List<OpeningEngineLine> _rawEngineLines = const <OpeningEngineLine>[];
  List<OpeningMoveSuggestion> _engineSuggestions =
      const <OpeningMoveSuggestion>[];
  List<OpeningMoveSuggestion> _openingSuggestions =
      const <OpeningMoveSuggestion>[];

  // Полные ранжированные пятёрки для программируемого бота.
  // Они не обрезаются настройкой стрелок maxEvaluationDrop.
  List<OpeningMoveSuggestion> _engineBotSuggestions =
      const <OpeningMoveSuggestion>[];
  List<OpeningMoveSuggestion> _openingBotSuggestions =
      const <OpeningMoveSuggestion>[];

  List<OpeningTrainerBoardArrow> _boardArrows =
      const <OpeningTrainerBoardArrow>[];
  final List<OpeningTrainerMessage> _messages = <OpeningTrainerMessage>[];

  int _startedGamesInSession = 0;
  int _currentCycleNumber = 0;
  int _currentGameInCycle = 0;
  int _currentIdenticalGroup = 0;
  int _currentBotReplyNumber = 0;

  /// В одинаковых партиях одной группы одна и та же позиция получает
  /// тот же фактический ответ, даже если движок вернул равные оценки
  /// в другом порядке.
  final Map<String, String> _lockedBotReplies = <String, String>{};

  OpeningTrainerSettings get settings => _settings;
  OpeningTree? get tree => _tree;
  OpeningTrainerMode get mode => _mode;
  String get studentColor => _studentColor;
  List<OpeningDatabaseItem> get catalog => List.unmodifiable(_catalog);
  List<OpeningDatabaseItem> get matchingOpenings =>
      List.unmodifiable(_matchingOpenings);
  OpeningTrainerPhase get phase => _phase;
  bool get sessionActive => _sessionActive;
  bool get analyzing => _analyzing;
  String? get currentFen => _currentFen;
  bool get whiteToMove => _whiteToMove;
  List<String> get historyUci => List.unmodifiable(_historyUci);
  List<OpeningEngineLine> get rawEngineLines => List.unmodifiable(_rawEngineLines);
  List<OpeningMoveSuggestion> get engineSuggestions =>
      List.unmodifiable(_engineSuggestions);
  List<OpeningMoveSuggestion> get openingSuggestions =>
      List.unmodifiable(_openingSuggestions);
  List<OpeningMoveSuggestion> get engineBotSuggestions =>
      List.unmodifiable(_engineBotSuggestions);
  List<OpeningMoveSuggestion> get openingBotSuggestions =>
      List.unmodifiable(_openingBotSuggestions);
  List<OpeningTrainerBoardArrow> get boardArrows =>
      List.unmodifiable(_boardArrows);
  List<OpeningTrainerMessage> get messages => List.unmodifiable(_messages);

  int get currentCycleNumber => _currentCycleNumber;
  int get currentGameInCycle => _currentGameInCycle;
  int get currentIdenticalGroup => _currentIdenticalGroup;
  int get currentBotReplyNumber => _currentBotReplyNumber;
  int get startedGamesInSession => _startedGamesInSession;

  bool get studentPlaysWhite => _studentColor != 'black';

  String get startFen => _tree?.startFen ?? 'startpos';

  bool get canStart {
    if (_mode == OpeningTrainerMode.selectedOpening) return _tree != null;
    if (_mode == OpeningTrainerMode.automaticTree ||
        _mode == OpeningTrainerMode.automaticCombined) {
      return _catalog.isNotEmpty;
    }
    return true;
  }

  String get currentOpeningLabel {
    if (_mode == OpeningTrainerMode.selectedOpening && _tree != null) {
      return _tree!.name;
    }
    if (_matchingOpenings.length == 1) return _matchingOpenings.first.name;
    if (_matchingOpenings.isEmpty) return 'Вне известной дебютной базы';
    return '${_matchingOpenings.length} возможных дебютов';
  }

  bool get isStudentsTurn =>
      _sessionActive &&
      ((_whiteToMove && studentPlaysWhite) ||
          (!_whiteToMove && !studentPlaysWhite));

  bool get controlsCurrentPosition =>
      _sessionActive &&
      _phase != OpeningTrainerPhase.finished &&
      _phase != OpeningTrainerPhase.error;

  String get phaseTitle {
    switch (_phase) {
      case OpeningTrainerPhase.noTree:
        return 'Дебют не загружен';
      case OpeningTrainerPhase.idle:
        return 'Готов';
      case OpeningTrainerPhase.analyzing:
        return 'Анализ позиции';
      case OpeningTrainerPhase.studentTurn:
        return 'Ход ученика';
      case OpeningTrainerPhase.botTurn:
        return 'Ход бота';
      case OpeningTrainerPhase.finished:
        return 'Дебют завершён';
      case OpeningTrainerPhase.error:
        return 'Ошибка';
    }
  }

  Future<void> loadOpeningFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final Uint8List? bytes = result.files.first.bytes;
    if (bytes == null) {
      throw const FormatException('Не удалось прочитать выбранный JSON-файл.');
    }
    loadTreeJson(utf8.decode(bytes));
  }

  Future<List<OpeningDatabaseItem>> fetchPublishedOpenings() async {
    try {
      const pageSize = 500;
      var offset = 0;
      final result = <OpeningDatabaseItem>[];

      while (true) {
        final rows = await Supabase.instance.client
            .from('makechess_opening_trees_v1')
            .select(
              'id,name,student_color,start_fen,source_name,source_license,'
              'first_moves:opening_json->firstMoves,'
              'popularity:opening_json->>popularity,'
              'white_efficiency:opening_json->>whiteEfficiency,'
              'black_efficiency:opening_json->>blackEfficiency',
            )
            .eq('is_published', true)
            .order('sort_order', ascending: true)
            .order('name', ascending: true)
            .range(offset, offset + pageSize - 1);

        for (final row in rows) {
          result.add(
            OpeningDatabaseItem.fromRow(
              Map<String, dynamic>.from(row),
            ),
          );
        }

        if (rows.length < pageSize) break;
        offset += pageSize;
      }

      return List<OpeningDatabaseItem>.unmodifiable(result);
    } catch (error) {
      throw StateError(
        'Не удалось получить каталог дебютов из Selectel: $error',
      );
    }
  }

  Future<OpeningDatabaseItem> fetchPublishedOpeningById(String id) async {
    try {
      final row = await Supabase.instance.client
          .from('makechess_opening_trees_v1')
          .select(
            'id,name,student_color,start_fen,source_name,'
            'source_license,opening_json',
          )
          .eq('id', id)
          .eq('is_published', true)
          .single();

      return OpeningDatabaseItem.fromRow(
        Map<String, dynamic>.from(row),
      );
    } catch (error) {
      throw StateError(
        'Не удалось загрузить выбранный дебют из Selectel: $error',
      );
    }
  }

  Future<OpeningDatabaseItem> fetchPublishedOpeningFamily(
    OpeningDatabaseItem selected,
  ) async {
    try {
      // В интерфейсе selected.name уже переведён на русский,
      // но поле name в Selectel осталось английским.
      // Семейство всегда ищем по нетронутому databaseName.
      final selectedDatabaseName = selected.databaseName.trim();
      final familyRoot = selectedDatabaseName
          .split(RegExp(r'[:,]'))
          .first
          .trim();
      final patternRoot = familyRoot;

      const pageSize = 500;
      var offset = 0;
      final familyRows = <OpeningDatabaseItem>[];

      while (true) {
        final rows = await Supabase.instance.client
            .from('makechess_opening_trees_v1')
            .select(
              'id,name,student_color,start_fen,source_name,'
              'source_license,opening_json',
            )
            .eq('is_published', true)
            .like('name', '$patternRoot%')
            .order('name', ascending: true)
            .range(offset, offset + pageSize - 1);

        for (final row in rows) {
          final item = OpeningDatabaseItem.fromRow(
            Map<String, dynamic>.from(row),
          );
          final sameSelectedBranch =
              item.databaseName == selectedDatabaseName ||
              item.databaseName.startsWith('$selectedDatabaseName:') ||
              item.databaseName.startsWith('$selectedDatabaseName,');

          final selectedIsFamilyRoot =
              selectedDatabaseName == familyRoot;
          if (selectedIsFamilyRoot || sameSelectedBranch) {
            familyRows.add(item);
          }
        }

        if (rows.length < pageSize) break;
        offset += pageSize;
      }

      if (familyRows.isEmpty) {
        return fetchPublishedOpeningById(selected.id);
      }

      final mergedLines = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in familyRows) {
        final rawLines = item.openingJson['lines'] ??
            item.openingJson['branches'] ??
            item.openingJson['variations'];
        if (rawLines is! List) continue;

        for (final raw in rawLines) {
          if (raw is! Map) continue;
          final line = Map<String, dynamic>.from(raw);
          final rawMoves = line['moves'] ?? line['uci'];
          if (rawMoves is! List) continue;

          final moves = rawMoves
              .map((value) => _normalizeUci('$value'))
              .where(_isUciMove)
              .toList(growable: false);
          if (moves.isEmpty) continue;

          final signature = moves.join(' ');
          if (!seen.add(signature)) continue;

          mergedLines.add(
            <String, dynamic>{
              'title': '${line['title'] ?? line['name'] ?? item.name}'.trim(),
              'moves': moves,
            },
          );
        }
      }

      if (mergedLines.isEmpty) {
        return fetchPublishedOpeningById(selected.id);
      }

      // Самые глубокие линии должны идти первыми.
      mergedLines.sort((a, b) {
        final aMoves = (a['moves'] as List).length;
        final bMoves = (b['moves'] as List).length;
        final byLength = bMoves.compareTo(aMoves);
        if (byLength != 0) return byLength;
        return '${a['title']}'.compareTo('${b['title']}');
      });

      return OpeningDatabaseItem(
        id: '${selected.id}_family',
        name: selected.name,
        databaseName: selected.databaseName,
        studentColor: selected.studentColor,
        startFen: selected.startFen,
        sourceName: selected.sourceName,
        sourceLicense: selected.sourceLicense,
        openingJson: <String, dynamic>{
          'id': '${selected.id}_family',
          'name': selected.name,
          'studentColor': selected.studentColor,
          'startFen': selected.startFen,
          'sourceName': selected.sourceName,
          'sourceLicense': selected.sourceLicense,
          'familyRoot': familyRoot,
          'databaseName': selected.databaseName,
          'familyRows': familyRows.length,
          'lines': mergedLines,
        },
        popularity: familyRows.fold<double>(
          0,
          (sum, item) => sum + item.popularity,
        ),
        whiteEfficiency: selected.whiteEfficiency,
        blackEfficiency: selected.blackEfficiency,
        firstMovesUci: selected.firstMovesUci,
      );
    } catch (error) {
      throw StateError(
        'Не удалось собрать полное дерево дебюта «${selected.name}»: $error',
      );
    }
  }

  void setOpeningCatalog(List<OpeningDatabaseItem> items) {
    _catalog = List<OpeningDatabaseItem>.unmodifiable(items);
    _refreshMatchingOpenings(announce: false);
    _safeNotify();
  }

  void loadDatabaseOpening(
    OpeningDatabaseItem item, {
    String? studentColor,
  }) {
    if (!_catalog.any((candidate) => candidate.id == item.id)) {
      _catalog = List<OpeningDatabaseItem>.unmodifiable(
        <OpeningDatabaseItem>[..._catalog, item],
      );
    }
    _mode = OpeningTrainerMode.selectedOpening;
    loadTree(
      item.toTree(),
      studentColorOverride: studentColor,
    );

    final familyRows =
        int.tryParse('${item.openingJson['familyRows'] ?? 0}') ?? 0;
    final rawLines = item.openingJson['lines'];
    final branchCount = rawLines is List ? rawLines.length : 0;

    if (familyRows > 0 || branchCount > 0) {
      _addMessage(
        'Дерево собрано: записей базы — $familyRows, '
        'ветвей — $branchCount.',
        OpeningTrainerMessageKind.success,
        notify: false,
      );
      _safeNotify();
    }
  }

  void configureAutomaticMode(
    OpeningTrainerMode mode, {
    required String studentColor,
  }) {
    if (mode == OpeningTrainerMode.selectedOpening) return;
    _analysisEpoch++;
    _mode = mode;
    _studentColor = studentColor.toLowerCase() == 'black' ? 'black' : 'white';
    _tree = null;
    _sessionActive = false;
    _phase = canStart ? OpeningTrainerPhase.idle : OpeningTrainerPhase.noTree;
    _historyUci.clear();
    _clearSuggestions();
    _refreshMatchingOpenings(announce: false);
    _addMessage(
      'Выбран режим «${mode.title}». Сторона ученика: '
      '${studentPlaysWhite ? 'белые' : 'чёрные'}.',
      OpeningTrainerMessageKind.success,
      notify: false,
    );
    _safeNotify();
  }

  void loadTreeJson(String source) {
    final parsed = OpeningTree.fromJsonString(source);
    loadTree(parsed);
  }

  void loadTree(
    OpeningTree tree, {
    String? studentColorOverride,
  }) {
    _tree = tree;
    _mode = OpeningTrainerMode.selectedOpening;
    final chosenColor = studentColorOverride ?? tree.studentColor;
    _studentColor = chosenColor.toLowerCase() == 'black' ? 'black' : 'white';
    _sessionActive = false;
    _phase = OpeningTrainerPhase.idle;
    _historyUci.clear();
    _clearSuggestions();
    _addMessage(
      'Загружен дебют «${tree.name}». Сторона ученика: '
      '${studentPlaysWhite ? 'белые' : 'чёрные'}.',
      OpeningTrainerMessageKind.success,
      notify: false,
    );
    _safeNotify();
  }

  void updateSettings(OpeningTrainerSettings value) {
    final stockfishError = OpeningBotReplyRuleParser.validateRuleSet(
      value.stockfishLineRules,
      maxReplyNumber: 120,
    );
    if (stockfishError != null) {
      throw FormatException('Правила Stockfish: $stockfishError');
    }

    final treeError = OpeningBotReplyRuleParser.validateRuleSet(
      value.openingTreeLineRules,
      maxReplyNumber: 120,
    );
    if (treeError != null) {
      throw FormatException('Правила дебютного дерева: $treeError');
    }

    final gamesPerCycle = value.gamesPerCycle.clamp(1, 500).toInt();
    final identicalGames =
        value.identicalResponseGames.clamp(1, gamesPerCycle).toInt();

    _settings = OpeningTrainerSettings(
      depthFullMoves: value.depthFullMoves.clamp(1, 60).toInt(),
      maxVariants: value.maxVariants.clamp(1, 12).toInt(),
      maxEvaluationDrop: value.maxEvaluationDrop.clamp(0.0, 5.0).toDouble(),
      botMoveSource: value.botMoveSource,
      cyclesPerSession: value.cyclesPerSession.clamp(1, 100).toInt(),
      gamesPerCycle: gamesPerCycle,
      identicalResponseGames: identicalGames,
      stockfishLineRules:
          Map<int, String>.unmodifiable(value.stockfishLineRules),
      openingTreeLineRules:
          Map<int, String>.unmodifiable(value.openingTreeLineRules),
      botEngineDepth: value.botEngineDepth.clamp(6, 22).toInt(),
      botThinkingTimeMs: value.botThinkingTimeMs.clamp(200, 30000).toInt(),
      botMoveDelayMs: value.botMoveDelayMs.clamp(0, 5000).toInt(),
    );

    resetBotProgramProgress(notify: false);
    _addMessage(
      'Настройки применены. Бот: ${_settings.botMoveSource.title}; '
      'циклов ${_settings.cyclesPerSession}; партий в цикле '
      '${_settings.gamesPerCycle}; одинаковых партий подряд '
      '${_settings.identicalResponseGames}.',
      OpeningTrainerMessageKind.info,
      notify: false,
    );
    _safeNotify();
  }

  void resetBotProgramProgress({bool notify = true}) {
    _startedGamesInSession = 0;
    _currentCycleNumber = 0;
    _currentGameInCycle = 0;
    _currentIdenticalGroup = 0;
    _currentBotReplyNumber = 0;
    _lockedBotReplies.clear();

    if (notify) {
      _addMessage(
        'Счётчик программируемой серии бота сброшен.',
        OpeningTrainerMessageKind.info,
        notify: false,
      );
      _safeNotify();
    }
  }

  void _prepareNextProgrammedGame() {
    final total = _settings.totalGamesPerSession;
    if (_startedGamesInSession >= total) {
      _startedGamesInSession = 0;
      _lockedBotReplies.clear();
      _addMessage(
        'Предыдущая серия из $total партий завершена. '
        'Начинается новая серия.',
        OpeningTrainerMessageKind.success,
        notify: false,
      );
    }

    _startedGamesInSession++;
    _currentCycleNumber =
        ((_startedGamesInSession - 1) ~/ _settings.gamesPerCycle) + 1;
    _currentGameInCycle =
        ((_startedGamesInSession - 1) % _settings.gamesPerCycle) + 1;
    _currentIdenticalGroup =
        ((_currentGameInCycle - 1) ~/ _settings.identicalResponseGames) + 1;
    _currentBotReplyNumber = 0;
  }

  void startSession() {
    if (!canStart) {
      _phase = OpeningTrainerPhase.noTree;
      _addMessage(
        _mode == OpeningTrainerMode.selectedOpening
            ? 'Сначала выберите дебют через кнопку «Выбрать дебют».'
            : 'Для этого режима в Selectel нет опубликованных дебютов.',
        OpeningTrainerMessageKind.warning,
        notify: false,
      );
      _safeNotify();
      return;
    }
    _analysisEpoch++;
    _prepareNextProgrammedGame();
    _sessionActive = true;
    _phase = OpeningTrainerPhase.idle;
    _historyUci.clear();
    _clearSuggestions();
    _refreshMatchingOpenings(announce: false);
    _addMessage(
      'Тренировка началась. Режим: «${_mode.title}». '
      'Сторона ученика: ${studentPlaysWhite ? 'белые' : 'чёрные'}. '
      'Серия: цикл $_currentCycleNumber/${_settings.cyclesPerSession}, '
      'партия $_currentGameInCycle/${_settings.gamesPerCycle}, '
      'группа одинаковых ответов $_currentIdenticalGroup. '
      'Бот: ${_settings.botMoveSource.title}.',
      OpeningTrainerMessageKind.success,
      notify: false,
    );
    if (_mode == OpeningTrainerMode.free) {
      _addMessage(
        'Свободный режим: стрелки являются рекомендациями, но разрешён любой легальный ход.',
        OpeningTrainerMessageKind.info,
        notify: false,
      );
    }
    _safeNotify();
  }

  void stopSession({String? reason}) {
    _analysisEpoch++;
    _sessionActive = false;
    _analyzing = false;
    _phase = canStart ? OpeningTrainerPhase.idle : OpeningTrainerPhase.noTree;
    _clearSuggestions();
    _addMessage(
      reason ?? 'Тренировка остановлена.',
      OpeningTrainerMessageKind.info,
      notify: false,
    );
    _safeNotify();
  }

  bool canStudentPlay(String uci) {
    if (!_sessionActive) return true;
    if (_phase == OpeningTrainerPhase.finished) return true;
    if (!isStudentsTurn) return false;
    if (_phase == OpeningTrainerPhase.analyzing) return false;
    if (_mode == OpeningTrainerMode.free) return true;

    final normalized = _normalizeUci(uci);
    if (_mode == OpeningTrainerMode.automaticStockfish) {
      return _engineSuggestions.any((item) => item.uci == normalized);
    }
    if (_openingSuggestions.isNotEmpty) {
      return _openingSuggestions.any((item) => item.uci == normalized);
    }
    return false;
  }

  void rejectStudentMove(String uci) {
    final normalized = _normalizeUci(uci);
    if (_phase == OpeningTrainerPhase.analyzing) {
      _addMessage(
        'Подождите окончания анализа позиции.',
        OpeningTrainerMessageKind.warning,
      );
      return;
    }

    final recommended = _mode == OpeningTrainerMode.automaticStockfish
        ? _engineSuggestions
        : _openingSuggestions;
    _addMessage(
      recommended.any((item) => item.uci == normalized)
          ? 'Ход $normalized сейчас временно недоступен.'
          : 'Ход $normalized не входит в показанные рекомендации. '
              'Для любого легального хода включите «Свободный режим».',
      OpeningTrainerMessageKind.warning,
    );
  }

  void recordStudentMove(String uci) {
    if (!_sessionActive || _phase == OpeningTrainerPhase.finished) return;
    final normalized = _normalizeUci(uci);
    _historyUci.add(normalized);
    _addMessage(
      'Вы сыграли $normalized.',
      OpeningTrainerMessageKind.success,
      notify: false,
    );
    _refreshMatchingOpenings();
    _clearSuggestions();
    _safeNotify();
  }

  void addStudentQuestion(String question) {
    final clean = question.trim();
    if (clean.isEmpty) return;
    _addMessage(clean, OpeningTrainerMessageKind.student);
  }

  void addSystemAnswer(String answer) {
    final clean = answer.trim();
    if (clean.isEmpty) return;
    _addMessage(clean, OpeningTrainerMessageKind.info);
  }

  void addSystemError(String error) {
    final clean = error.trim();
    if (clean.isEmpty) return;
    _addMessage(clean, OpeningTrainerMessageKind.error);
  }

  Future<void> analyzePosition({
    required String fen,
    required bool whiteToMove,
    required OpeningPositionAnalyzer analyze,
    required OpeningBotMovePlayer playBotMove,
    bool force = false,
  }) async {
    if (!_sessionActive || _disposed) return;
    if (_phase == OpeningTrainerPhase.finished) return;

    if (!force && _analyzing && _currentFen == fen) return;
    _currentFen = fen;
    _whiteToMove = whiteToMove;

    if (_historyUci.length >= _settings.maxPly) {
      _finishOpeningDepth();
      return;
    }

    _refreshMatchingOpenings(announce: false);
    final node = _effectiveOpeningNode();
    final treeRequired = _mode == OpeningTrainerMode.selectedOpening ||
        _mode == OpeningTrainerMode.automaticTree ||
        _mode == OpeningTrainerMode.automaticCombined;

    if (treeRequired && node == null) {
      if (_mode == OpeningTrainerMode.selectedOpening) {
        _phase = OpeningTrainerPhase.error;
        _clearSuggestions();
        _addMessage(
          'Текущая последовательность ходов отсутствует в выбранном дебюте.',
          OpeningTrainerMessageKind.error,
          notify: false,
        );
        _safeNotify();
        return;
      }
      _addMessage(
        'Последовательность вышла из известных дебютных деревьев. '
        'Переключитесь на Stockfish или свободный режим.',
        OpeningTrainerMessageKind.warning,
        notify: false,
      );
    }

    if (node != null && node.isLeaf && treeRequired) {
      _finishOpeningDepth(
        message: MakeChessLocalization.phrase('В известных ветках больше нет продолжений. Дебютная часть завершена.'),
      );
      return;
    }

    final epoch = ++_analysisEpoch;
    _analyzing = true;
    _phase = OpeningTrainerPhase.analyzing;
    _clearSuggestions();
    _safeNotify();

    try {
      final globalPv = math.max(_settings.maxVariants, 5).clamp(1, 5).toInt();
      final globalLines = await analyze(
        fen,
        globalPv,
        const <String>[],
      );
      if (_disposed || epoch != _analysisEpoch || !_sessionActive) return;

      _rawEngineLines = _deduplicateAndSort(globalLines);
      _engineBotSuggestions = _buildEngineBotSuggestions(_rawEngineLines);
      _engineSuggestions = _filterEngineSuggestions(_rawEngineLines);

      List<OpeningEngineLine> openingLines = _rawEngineLines;
      if (treeRequired && node != null && node.moves.isNotEmpty) {
        final bookMoves = node.moves.keys.toList(growable: false);
        final globalMoveSet = _rawEngineLines
            .map((line) => line.uci)
            .toSet();
        final needsRestrictedAnalysis =
            bookMoves.any((move) => !globalMoveSet.contains(move));

        if (needsRestrictedAnalysis) {
          openingLines = await analyze(
            fen,
            math.min(5, bookMoves.length),
            bookMoves,
          );
          if (_disposed || epoch != _analysisEpoch || !_sessionActive) return;
          openingLines = _deduplicateAndSort(openingLines);
        }
      }

      if (node == null) {
        _openingSuggestions = const <OpeningMoveSuggestion>[];
        _openingBotSuggestions = const <OpeningMoveSuggestion>[];
      } else {
        // Пятёрка бота всегда строится только из ветвей дерева и
        // сортируется Stockfish от лучшей к худшей без фильтра стрелок.
        _openingBotSuggestions = _buildOpeningBotSuggestions(
          node,
          openingLines,
        );

        if (_mode == OpeningTrainerMode.automaticTree ||
            _mode == OpeningTrainerMode.automaticStockfish ||
            _mode == OpeningTrainerMode.free) {
          _openingSuggestions = _buildTreeOnlySuggestions(node, openingLines);
        } else {
          _openingSuggestions = _buildOpeningSuggestions(node, openingLines);
        }
      }

      _boardArrows = _buildArrows(
        engine: _engineSuggestions,
        opening: _openingSuggestions,
      );
      _analyzing = false;

      final studentRecommendations =
          _mode == OpeningTrainerMode.automaticStockfish
              ? _engineSuggestions
              : _openingSuggestions;

      if (isStudentsTurn) {
        _phase = OpeningTrainerPhase.studentTurn;
        if (studentRecommendations.isEmpty) {
          _addMessage(
            _mode == OpeningTrainerMode.free
                ? 'Ваш ход. Можно сыграть любой легальный ход.'
                : 'Для этой позиции нет допустимых рекомендаций.',
            OpeningTrainerMessageKind.warning,
            notify: false,
          );
        } else {
          final best = studentRecommendations.first;
          _addMessage(
            _mode == OpeningTrainerMode.free
                ? 'Ваш ход. Рекомендуется ${best.shownMove}, но разрешён любой легальный ход.'
                : 'Ваш ход. Основная рекомендация: ${best.shownMove}. '
                    'Показано вариантов: ${studentRecommendations.length}.',
            OpeningTrainerMessageKind.info,
            notify: false,
          );
        }
        _safeNotify();
        return;
      }

      final botSource = _settings.botMoveSource;
      final botSuggestions = botSource == OpeningBotMoveSource.stockfish
          ? _engineBotSuggestions
          : _openingBotSuggestions;
      if (botSuggestions.isEmpty) {
        _phase = OpeningTrainerPhase.error;
        _addMessage(
          botSource == OpeningBotMoveSource.openingTree
              ? 'В текущей позиции нет доступных ходов выбранного дебютного дерева.'
              : 'Stockfish не вернул доступные ходы.',
          OpeningTrainerMessageKind.error,
          notify: false,
        );
        _safeNotify();
        return;
      }

      _phase = OpeningTrainerPhase.botTurn;
      _currentBotReplyNumber++;
      final requestedLine = _settings.lineForBotReply(
        botSource,
        _currentBotReplyNumber,
      );
      final best = _chooseProgrammedBotSuggestion(
        botSuggestions,
        requestedLine: requestedLine,
        positionKey: _historyUci.join(' '),
      );
      final actualLine = botSuggestions.indexWhere(
            (item) => item.uci == best.uci,
          ) +
          1;
      final alternatives = botSuggestions
          .where((item) => item.uci != best.uci)
          .map((item) => item.shownMove)
          .toList(growable: false);
      _addMessage(
        'Ответ бота №$_currentBotReplyNumber: '
        '${botSource.title}, задана линия $requestedLine, '
        'сыграна линия ${actualLine < 1 ? 1 : actualLine} — '
        '${best.shownMove}.'
        '${alternatives.isEmpty ? '' : ' Альтернативы: ${alternatives.join(', ')}.'}',
        OpeningTrainerMessageKind.bot,
        notify: false,
      );
      _safeNotify();

      await Future<void>.delayed(
        Duration(milliseconds: _settings.botMoveDelayMs),
      );
      if (_disposed || epoch != _analysisEpoch || !_sessionActive) return;

      _historyUci.add(best.uci);
      _refreshMatchingOpenings();
      try {
        await playBotMove(best.uci);
      } catch (_) {
        if (_historyUci.isNotEmpty && _historyUci.last == best.uci) {
          _historyUci.removeLast();
          _refreshMatchingOpenings(announce: false);
        }
        rethrow;
      }

      _addMessage(
        'Бот сыграл ${best.shownMove}.',
        OpeningTrainerMessageKind.bot,
      );
    } catch (error) {
      if (_disposed || epoch != _analysisEpoch) return;
      _analyzing = false;
      _phase = OpeningTrainerPhase.error;
      _clearSuggestions();
      _addMessage(
        'Ошибка анализа Stockfish: $error',
        OpeningTrainerMessageKind.error,
        notify: false,
      );
      _safeNotify();
    }
  }

  OpeningMoveSuggestion _chooseProgrammedBotSuggestion(
    List<OpeningMoveSuggestion> suggestions, {
    required int requestedLine,
    required String positionKey,
  }) {
    final sorted = List<OpeningMoveSuggestion>.from(suggestions)
      ..sort((a, b) {
        if (a.scoreAvailable && b.scoreAvailable) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
        } else if (a.scoreAvailable) {
          return -1;
        } else if (b.scoreAvailable) {
          return 1;
        }
        return a.uci.compareTo(b.uci);
      });

    final source = _settings.botMoveSource;
    final lockKey = '${source.name}|cycle=$_currentCycleNumber|'
        'group=$_currentIdenticalGroup|reply=$_currentBotReplyNumber|'
        'position=$positionKey';
    final lockedUci = _lockedBotReplies[lockKey];
    if (lockedUci != null) {
      for (final item in sorted) {
        if (item.uci == lockedUci) return item;
      }
    }

    final targetIndex = requestedLine.clamp(1, 5).toInt() - 1;
    final selected = targetIndex < sorted.length
        ? sorted[targetIndex]
        : sorted.first;

    _lockedBotReplies[lockKey] = selected.uci;
    return selected;
  }

  OpeningTreeNode? _effectiveOpeningNode() {
    if (_mode == OpeningTrainerMode.selectedOpening) {
      return _tree?.nodeAt(_historyUci);
    }
    final result = OpeningTreeNode();
    var found = false;
    for (final item in _matchingOpenings) {
      try {
        final node = item.toTree().nodeAt(_historyUci);
        if (node == null) continue;
        found = true;
        for (final entry in node.moves.entries) {
          result.addMove(entry.key, title: item.name);
        }
      } catch (_) {
        // Повреждённая запись не должна ломать остальные дебюты.
      }
    }
    return found ? result : null;
  }

  List<OpeningMoveSuggestion> _buildTreeOnlySuggestions(
    OpeningTreeNode node,
    List<OpeningEngineLine> lines,
  ) {
    final byUci = <String, OpeningEngineLine>{
      for (final line in lines) line.uci: line,
    };
    final weights = <String, double>{};
    final titles = <String, String?>{};
    final hasRealPopularity =
        _matchingOpenings.any((item) => item.popularity > 0);

    for (final item in _matchingOpenings) {
      try {
        final current = item.toTree().nodeAt(_historyUci);
        if (current == null) continue;
        for (final entry in current.moves.entries) {
          if (hasRealPopularity) {
            weights[entry.key] =
                (weights[entry.key] ?? 0) + item.popularity;
          } else {
            // Количество названий вариантов не является популярностью.
            // Пока реальной статистики нет, не позволяем плотности каталога
            // перевесить оценку Stockfish.
            weights[entry.key] = 0;
          }
          titles.putIfAbsent(entry.key, () => item.name);
        }
      } catch (_) {}
    }

    if (weights.isEmpty) {
      for (final entry in node.moves.entries) {
        weights[entry.key] = 0;
        titles[entry.key] = entry.value.title;
      }
    }

    final moves = weights.keys.toList()
      ..sort((a, b) {
        final aLine = byUci[a];
        final bLine = byUci[b];
        if (aLine != null && bLine != null) {
          final byEngine = bLine.score.compareTo(aLine.score);
          if (byEngine != 0) return byEngine;
        } else if (aLine != null) {
          return -1;
        } else if (bLine != null) {
          return 1;
        }

        final byWeight = (weights[b] ?? 0).compareTo(weights[a] ?? 0);
        if (byWeight != 0) return byWeight;
        return a.compareTo(b);
      });

    final limited = moves.take(_settings.maxVariants).toList(growable: false);
    return <OpeningMoveSuggestion>[
      for (var i = 0; i < limited.length; i++)
        OpeningMoveSuggestion(
          uci: limited[i],
          san: byUci[limited[i]]?.san,
          score: byUci[limited[i]]?.score ?? -999,
          rank: i + 1,
          inOpeningTree: true,
          title: titles[limited[i]],
          scoreAvailable: byUci[limited[i]] != null,
          bookWeight: weights[limited[i]] ?? 0,
        ),
    ];
  }

  void _refreshMatchingOpenings({bool announce = true}) {
    if (_catalog.isEmpty) {
      _matchingOpenings = const <OpeningDatabaseItem>[];
      return;
    }

    final matching = <OpeningDatabaseItem>[];
    for (final item in _catalog) {
      try {
        if (item.toTree().nodeAt(_historyUci) != null) matching.add(item);
      } catch (_) {}
    }
    matching.sort((a, b) {
      final byPopularity = b.popularity.compareTo(a.popularity);
      if (byPopularity != 0) return byPopularity;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    _matchingOpenings = List<OpeningDatabaseItem>.unmodifiable(matching);

    if (!announce || _historyUci.isEmpty) return;
    final signature = '${_historyUci.join(' ')}|${matching.map((e) => e.id).join(',')}';
    if (signature == _lastOpeningSignature) return;
    _lastOpeningSignature = signature;

    if (matching.isEmpty) {
      _addMessage(
        'После ${_historyUci.join(' ')} позиция не совпадает с известными дебютами.',
        OpeningTrainerMessageKind.warning,
        notify: false,
      );
      return;
    }
    if (matching.length == 1) {
      _addMessage(
        'Текущий дебют: ${matching.first.name}.',
        OpeningTrainerMessageKind.success,
        notify: false,
      );
      return;
    }
    final names = matching.take(12).map((item) => item.name).join(' • ');
    final more = matching.length > 12 ? ' • ещё ${matching.length - 12}' : '';
    _addMessage(
      'Возможные дебюты после ${_historyUci.join(' ')}: $names$more.',
      OpeningTrainerMessageKind.info,
      notify: false,
    );
  }

  void _finishOpeningDepth({String? message}) {
    _analysisEpoch++;
    _analyzing = false;
    _phase = OpeningTrainerPhase.finished;
    _clearSuggestions();
    _addMessage(
      message ??
          'Достигнута заданная глубина: ${_settings.depthFullMoves} полных ходов. '
              'Стрелки дебюта отключены.',
      OpeningTrainerMessageKind.success,
      notify: false,
    );
    _safeNotify();
  }

  List<OpeningEngineLine> _deduplicateAndSort(List<OpeningEngineLine> lines) {
    final byMove = <String, OpeningEngineLine>{};
    for (final line in lines) {
      final uci = _normalizeUci(line.uci);
      if (!_isUciMove(uci)) continue;
      final normalized = line.copyWith(uci: uci);
      final old = byMove[uci];
      if (old == null || normalized.score > old.score) {
        byMove[uci] = normalized;
      }
    }
    final result = byMove.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  List<OpeningMoveSuggestion> _buildEngineBotSuggestions(
    List<OpeningEngineLine> lines,
  ) {
    final limited = lines.take(5).toList(growable: false);
    return <OpeningMoveSuggestion>[
      for (var i = 0; i < limited.length; i++)
        OpeningMoveSuggestion(
          uci: limited[i].uci,
          san: limited[i].san,
          score: limited[i].score,
          rank: i + 1,
          inOpeningTree: false,
          scoreAvailable: true,
        ),
    ];
  }

  List<OpeningMoveSuggestion> _buildOpeningBotSuggestions(
    OpeningTreeNode node,
    List<OpeningEngineLine> lines,
  ) {
    final byUci = <String, OpeningEngineLine>{
      for (final line in lines) line.uci: line,
    };

    final result = <OpeningMoveSuggestion>[];
    for (final entry in node.moves.entries) {
      final line = byUci[entry.key];
      result.add(
        OpeningMoveSuggestion(
          uci: entry.key,
          san: line?.san,
          score: line?.score ?? -999.0,
          rank: 0,
          inOpeningTree: true,
          title: entry.value.title,
          scoreAvailable: line != null,
        ),
      );
    }

    result.sort((a, b) {
      if (a.scoreAvailable && b.scoreAvailable) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
      } else if (a.scoreAvailable) {
        return -1;
      } else if (b.scoreAvailable) {
        return 1;
      }
      return a.uci.compareTo(b.uci);
    });

    final limited = result.take(5).toList(growable: false);
    return <OpeningMoveSuggestion>[
      for (var i = 0; i < limited.length; i++)
        OpeningMoveSuggestion(
          uci: limited[i].uci,
          san: limited[i].san,
          score: limited[i].score,
          rank: i + 1,
          inOpeningTree: true,
          title: limited[i].title,
          scoreAvailable: limited[i].scoreAvailable,
          bookWeight: limited[i].bookWeight,
        ),
    ];
  }

  List<OpeningMoveSuggestion> _filterEngineSuggestions(
    List<OpeningEngineLine> lines,
  ) {
    if (lines.isEmpty) return const <OpeningMoveSuggestion>[];
    final bestScore = lines.first.score;
    final filtered = lines
        .where((line) => bestScore - line.score <= _settings.maxEvaluationDrop + 1e-9)
        .take(_settings.maxVariants)
        .toList();
    return <OpeningMoveSuggestion>[
      for (var i = 0; i < filtered.length; i++)
        OpeningMoveSuggestion(
          uci: filtered[i].uci,
          san: filtered[i].san,
          score: filtered[i].score,
          rank: i + 1,
          inOpeningTree: false,
        ),
    ];
  }

  List<OpeningMoveSuggestion> _buildOpeningSuggestions(
    OpeningTreeNode node,
    List<OpeningEngineLine> lines,
  ) {
    final byUci = <String, OpeningEngineLine>{
      for (final line in lines) line.uci: line,
    };
    final popularityByMove = <String, double>{};
    final hasRealPopularity =
        _matchingOpenings.any((item) => item.popularity > 0);

    if (hasRealPopularity) {
      for (final item in _matchingOpenings) {
        if (item.popularity <= 0) continue;
        try {
          final current = item.toTree().nodeAt(_historyUci);
          if (current == null) continue;
          for (final move in current.moves.keys) {
            popularityByMove[move] =
                (popularityByMove[move] ?? 0) + item.popularity;
          }
        } catch (_) {}
      }
    }

    final scored = <OpeningMoveSuggestion>[];
    final unscored = <OpeningMoveSuggestion>[];
    var sourceRank = 0;
    for (final entry in node.moves.entries) {
      sourceRank++;
      final line = byUci[entry.key];
      final item = OpeningMoveSuggestion(
        uci: entry.key,
        san: line?.san,
        score: line?.score ?? -999.0,
        rank: sourceRank,
        inOpeningTree: true,
        title: entry.value.title,
        scoreAvailable: line != null,
        bookWeight: popularityByMove[entry.key] ?? 0,
      );
      (line == null ? unscored : scored).add(item);
    }

    scored.sort((a, b) {
      final byEngine = b.score.compareTo(a.score);
      if (byEngine != 0) return byEngine;
      return b.bookWeight.compareTo(a.bookWeight);
    });
    if (scored.isEmpty) {
      return unscored.take(_settings.maxVariants).toList(growable: false);
    }

    final bestScore = scored.first.score;
    final accepted = scored
        .where(
          (item) =>
              bestScore - item.score <=
              _settings.maxEvaluationDrop + 1e-9,
        )
        .take(_settings.maxVariants)
        .toList(growable: true);

    // Если движок не вернул часть ходов, они не могут считаться лучшими по
    // оценке. Поэтому добавляем их только как аварийный запас, когда после
    // фильтра не осталось ни одного варианта.
    if (accepted.isEmpty && unscored.isNotEmpty) {
      accepted.addAll(unscored.take(_settings.maxVariants));
    }

    return <OpeningMoveSuggestion>[
      for (var i = 0; i < accepted.length; i++)
        OpeningMoveSuggestion(
          uci: accepted[i].uci,
          san: accepted[i].san,
          score: accepted[i].score,
          rank: i + 1,
          inOpeningTree: true,
          title: accepted[i].title,
          scoreAvailable: accepted[i].scoreAvailable,
          bookWeight: accepted[i].bookWeight,
        ),
    ];
  }

  List<OpeningTrainerBoardArrow> _buildArrows({
    required List<OpeningMoveSuggestion> engine,
    required List<OpeningMoveSuggestion> opening,
  }) {
    final result = <OpeningTrainerBoardArrow>[];

    double opacityFor(int index, {required bool primary}) {
      if (index == 0) return primary ? 0.58 : 0.54;
      if (index == 1) return primary ? 0.34 : 0.31;
      return math.max(0.17, (primary ? 0.29 : 0.27) - index * 0.045);
    }

    for (var i = 0; i < engine.length; i++) {
      final uci = engine[i].uci;
      if (!_isUciMove(uci)) continue;
      result.add(
        OpeningTrainerBoardArrow(
          from: uci.substring(0, 2),
          to: uci.substring(2, 4),
          color: engineArrowColor,
          opacity: opacityFor(i, primary: true),
          widthFactor: 1.14,
          source: 'engine',
          rank: i + 1,
        ),
      );
    }

    for (var i = 0; i < opening.length; i++) {
      final uci = opening[i].uci;
      if (!_isUciMove(uci)) continue;
      result.add(
        OpeningTrainerBoardArrow(
          from: uci.substring(0, 2),
          to: uci.substring(2, 4),
          color: openingArrowColor,
          opacity: opacityFor(i, primary: false),
          widthFactor: 0.74,
          source: 'opening',
          rank: i + 1,
        ),
      );
    }

    return result;
  }

  void _clearSuggestions() {
    _rawEngineLines = const <OpeningEngineLine>[];
    _engineSuggestions = const <OpeningMoveSuggestion>[];
    _openingSuggestions = const <OpeningMoveSuggestion>[];
    _engineBotSuggestions = const <OpeningMoveSuggestion>[];
    _openingBotSuggestions = const <OpeningMoveSuggestion>[];
    _boardArrows = const <OpeningTrainerBoardArrow>[];
  }

  void _addMessage(
    String text,
    OpeningTrainerMessageKind kind, {
    bool notify = true,
  }) {
    _messages.add(
      OpeningTrainerMessage(
        text: text,
        kind: kind,
        createdAt: DateTime.now(),
      ),
    );
    if (_messages.length > 120) {
      _messages.removeRange(0, _messages.length - 120);
    }
    if (notify) _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _analysisEpoch++;
    super.dispose();
  }
}

/// Разбирает несколько распространённых форматов ответа Stockfish API.
/// По умолчанию payload без явного POV считается оценкой с точки зрения
/// белых — так уже используется stockfish_service в текущем проекте.
class OpeningEnginePayloadParser {
  const OpeningEnginePayloadParser._();

  static List<OpeningEngineLine> parse(
    dynamic raw, {
    required bool whiteToMove,
    String? Function(String uci)? sanForUci,
    bool scoreIsWhitePerspectiveWhenPovMissing = true,
  }) {
    final variants = _variantMaps(raw);
    final result = <OpeningEngineLine>[];

    for (final variant in variants) {
      final uci = _firstUci(variant);
      if (uci == null) continue;
      final scoreData = _score(
        variant,
        whiteToMove: whiteToMove,
        scoreIsWhitePerspectiveWhenPovMissing:
            scoreIsWhitePerspectiveWhenPovMissing,
      );
      result.add(
        OpeningEngineLine(
          uci: uci,
          san: sanForUci?.call(uci),
          score: scoreData.$1,
          mate: scoreData.$2,
          pv: _pv(variant),
        ),
      );
    }

    // Некоторые сервисы при multiPV=1 возвращают только плоский объект.
    if (result.isEmpty && raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final uci = _firstUci(map);
      if (uci != null) {
        final scoreData = _score(
          map,
          whiteToMove: whiteToMove,
          scoreIsWhitePerspectiveWhenPovMissing:
              scoreIsWhitePerspectiveWhenPovMissing,
        );
        result.add(
          OpeningEngineLine(
            uci: uci,
            san: sanForUci?.call(uci),
            score: scoreData.$1,
            mate: scoreData.$2,
            pv: _pv(map),
          ),
        );
      }
    }

    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  static List<Map<String, dynamic>> _variantMaps(dynamic raw) {
    final result = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) result.add(Map<String, dynamic>.from(item));
      }
      return result;
    }
    if (raw is! Map) return result;

    final map = Map<String, dynamic>.from(raw);
    for (final key in const <String>[
      'variants',
      'lines',
      'multiPv',
      'multipv',
      'analysis',
      'pvs',
      'principalVariations',
      'topMoves',
      'bestMoves',
      'candidates',
    ]) {
      final value = map[key];
      if (value is List) {
        for (final item in value) {
          if (item is Map) result.add(Map<String, dynamic>.from(item));
        }
        if (result.isNotEmpty) return result;
      }
    }

    void visit(dynamic value) {
      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }
      if (value is! Map) return;
      final candidate = Map<String, dynamic>.from(value);
      final hasMoveField = const <String>[
        'uci',
        'move',
        'bestMove',
        'best_move',
        'bestmove',
        'pv',
        'line',
      ].any((key) => candidate[key] != null);
      final hasScoreField = const <String>[
        'score',
        'eval',
        'evaluation',
        'centipawns',
        'cp',
        'mate',
      ].any((key) => candidate[key] != null);
      if (hasMoveField && hasScoreField) {
        result.add(candidate);
      }
      for (final child in candidate.values) {
        if (child is Map || child is List) {
          visit(child);
        }
      }
    }

    visit(map);
    return result;
  }

  static String? _firstUci(Map<String, dynamic> map) {
    String? pick(dynamic value) {
      if (value is String) {
        final direct = _findUci(value);
        return direct;
      }
      if (value is Map) {
        for (final key in const <String>['uci', 'move', 'bestMove', 'best_move']) {
          final found = pick(value[key]);
          if (found != null) return found;
        }
      }
      if (value is List && value.isNotEmpty) return pick(value.first);
      return null;
    }

    for (final key in const <String>[
      'uci',
      'move',
      'bestMove',
      'best_move',
      'bestmove',
      'pv',
      'line',
      'moves',
      'continuationArr',
    ]) {
      final found = pick(map[key]);
      if (found != null) return found;
    }
    return _findUci(jsonEncode(map));
  }

  static List<String> _pv(Map<String, dynamic> map) {
    dynamic value = map['pv'] ?? map['line'] ?? map['moves'];
    if (value is String) {
      return RegExp(r'[a-h][1-8][a-h][1-8][qrbn]?', caseSensitive: false)
          .allMatches(value)
          .map((m) => m.group(0)!.toLowerCase())
          .toList(growable: false);
    }
    if (value is List) {
      return value
          .map((item) => _findUci('$item'))
          .whereType<String>()
          .toList(growable: false);
    }
    return const <String>[];
  }

  static (double, int?) _score(
    Map<String, dynamic> map, {
    required bool whiteToMove,
    required bool scoreIsWhitePerspectiveWhenPovMissing,
  }) {
    dynamic mate;
    dynamic cp;
    String? pov;

    final score = map['score'];
    if (score is Map) {
      mate = score['mate'];
      cp = score['cp'] ?? score['value'] ?? score['centipawns'];
      pov = '${score['pov'] ?? score['color'] ?? ''}'.toLowerCase();
    } else if (score is num || score is String) {
      cp = score;
    }

    mate ??= map['mate'];
    cp ??= map['cp'] ?? map['centipawns'] ?? map['eval'] ?? map['evaluation'];
    pov ??= '${map['pov'] ?? map['color'] ?? ''}'.toLowerCase();

    final mateInt = _asInt(mate);
    double value;
    if (mateInt != null) {
      if (mateInt == 0) {
        value = 0;
      } else {
        value = mateInt > 0 ? 100.0 - mateInt.abs() * 0.01 : -100.0 + mateInt.abs() * 0.01;
      }
    } else {
      value = _asDouble(cp) ?? 0.0;
      if (value.abs() > 20) value /= 100.0;
    }

    // Явный POV преобразуем к стороне хода. Текущий stockfish_service
    // проекта используется шкалой оценки белых, поэтому при отсутствии POV
    // по умолчанию также считаем значение оценкой с точки зрения белых.
    if (pov == 'white' || pov == 'black') {
      final scoreForWhite = pov == 'white' ? value : -value;
      value = whiteToMove ? scoreForWhite : -scoreForWhite;
    } else if (scoreIsWhitePerspectiveWhenPovMissing && !whiteToMove) {
      value = -value;
    }

    return (value.clamp(-100.0, 100.0).toDouble(), mateInt);
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '.').trim());
  }

  static String? _findUci(String source) {
    final match = RegExp(
      r'\b[a-h][1-8][a-h][1-8][qrbn]?\b',
      caseSensitive: false,
    ).firstMatch(source);
    return match?.group(0)?.toLowerCase();
  }
}

class OpeningTrainerArrowPainter extends CustomPainter {
  const OpeningTrainerArrowPainter({
    required this.arrows,
    required this.boardSize,
    required this.flipped,
  });

  final List<OpeningTrainerBoardArrow> arrows;
  final double boardSize;
  final bool flipped;

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      _drawArrow(
        canvas,
        _center(arrow.from),
        _center(arrow.to),
        arrow,
      );
    }
  }

  Offset _center(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square.substring(1, 2)) ?? 1;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank - 1 : 8 - rank;
    final cell = boardSize / 8;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    OpeningTrainerBoardArrow arrow,
  ) {
    final vector = to - from;
    if (vector.distance < 2) return;
    final cell = boardSize / 8;
    final unit = vector / vector.distance;
    final end = to - unit * (cell * 0.22);
    final strokeWidth = cell * 0.14 * arrow.widthFactor;
    final color = arrow.color.withValues(
      alpha: arrow.opacity.clamp(0.0, 1.0).toDouble(),
    );

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, end, linePaint);

    final headLength = cell * 0.34 * arrow.widthFactor;
    final headWidth = cell * 0.22 * arrow.widthFactor;
    final base = end - unit * headLength;
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo((base + normal * headWidth).dx, (base + normal * headWidth).dy)
      ..lineTo((base - normal * headWidth).dx, (base - normal * headWidth).dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant OpeningTrainerArrowPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.flipped != flipped;
  }
}

class OpeningTrainerDialog extends StatefulWidget {
  const OpeningTrainerDialog({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
    required this.onDragDelta,
    required this.onStart,
    required this.onStop,
    required this.onClose,
    required this.onSettingsChanged,
    required this.onTreeLoaded,
    required this.onStudentQuestion,
  });

  final OpeningTrainerController controller;
  final double width;
  final double height;
  final ValueChanged<Offset> onDragDelta;
  final Future<void> Function() onStart;
  final VoidCallback onStop;
  final VoidCallback onClose;
  final Future<void> Function() onSettingsChanged;
  final Future<void> Function() onTreeLoaded;
  final Future<String> Function(String question) onStudentQuestion;

  @override
  State<OpeningTrainerDialog> createState() => _OpeningTrainerDialogState();
}

class _OpeningTrainerDialogState extends State<OpeningTrainerDialog> {
  bool _collapsed = false;
  Offset? _dragStartGlobalPosition;
  ValueChanged<Offset>? _dragHandlerAtStart;
  final ScrollController _messagesScroll = ScrollController();
  final TextEditingController _studentQueryController = TextEditingController();
  final FocusNode _studentQueryFocus = FocusNode();
  bool _sendingQuestion = false;

  @override
  void dispose() {
    _messagesScroll.dispose();
    _studentQueryController.dispose();
    _studentQueryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            width: widget.width,
            height: _collapsed ? 48 : widget.height,
            decoration: AppDecorations.panel(bright: true),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                _header(controller),
                if (!_collapsed) ...<Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      child: Column(
                        children: <Widget>[
                          Expanded(child: _messageArea(controller)),
                          const SizedBox(height: 7),
                          _studentQuestionField(controller),
                          const SizedBox(height: 8),
                          _candidateArea(controller),
                        ],
                      ),
                    ),
                  ),
                  _footer(controller),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(OpeningTrainerController controller) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.neoButtonTop,
            AppColors.neoButtonMid,
            AppColors.neoButtonBottom,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.borderSoft),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                _dragStartGlobalPosition = details.globalPosition;
                _dragHandlerAtStart = widget.onDragDelta;
              },
              onPanUpdate: (details) {
                final start = _dragStartGlobalPosition;
                final handler = _dragHandlerAtStart;
                if (start != null && handler != null) {
                  handler(details.globalPosition - start);
                }
              },
              onPanEnd: (_) {
                _dragStartGlobalPosition = null;
                _dragHandlerAtStart = null;
              },
              onPanCancel: () {
                _dragStartGlobalPosition = null;
                _dragHandlerAtStart = null;
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.forum_outlined,
                      size: 19,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    MakeChessLocalizedText(
                      'Диалог',
                      style: AppTextStyles.panelTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        controller.phaseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _openingChooserHeaderButton(controller),
          _headerButton(
            tooltip: MakeChessLocalization.phrase('Настройки дебютного тренажёра'),
            icon: Icons.settings_outlined,
            onPressed: () => _openSettings(controller),
          ),
          _headerButton(
            tooltip: _collapsed ? 'Развернуть' : 'Свернуть',
            icon: _collapsed
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            onPressed: () => setState(() => _collapsed = !_collapsed),
          ),
          _headerButton(
            tooltip: MakeChessLocalization.phrase('Закрыть дебютный тренажёр'),
            icon: Icons.close,
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 3),
        ],
      ),
    );
  }

  Widget _openingChooserHeaderButton(OpeningTrainerController controller) {
    return Tooltip(
      message: MakeChessLocalization.phrase('Выбрать дебют или автоматический режим'),
      child: TextButton.icon(
        onPressed: () => _openOpeningChooser(controller),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(0, 34),
        ),
        icon: const Icon(Icons.account_tree_outlined, size: 17),
        label: const MakeChessLocalizedText(
          'Выбрать дебют',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _studentQuestionField(OpeningTrainerController controller) {
    Future<void> send() async {
      final question = _studentQueryController.text.trim();
      if (question.isEmpty || _sendingQuestion) return;
      setState(() => _sendingQuestion = true);
      _studentQueryController.clear();
      controller.addStudentQuestion(question);
      try {
        final answer = await widget.onStudentQuestion(question);
        controller.addSystemAnswer(answer);
      } catch (error) {
        controller.addSystemError('Не удалось получить ответ системы: $error');
      } finally {
        if (mounted) {
          setState(() => _sendingQuestion = false);
          _studentQueryFocus.requestFocus();
        }
      }
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _studentQueryController,
              focusNode: _studentQueryFocus,
              enabled: !_sendingQuestion,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              cursorColor: AppColors.accent,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => send(),
              decoration: AppInputs.dark(
                labelText: MakeChessLocalization.phrase('Запрос ученика'),
                dense: true,
              ).copyWith(
                hintText: MakeChessLocalization.phrase('Напишите вопрос о позиции или дебюте'),
                prefixIcon: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.textDim,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 46,
          height: 42,
          child: IconButton(
            tooltip: MakeChessLocalization.phrase('Отправить запрос'),
            onPressed: _sendingQuestion ? null : send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceCard,
              side: const BorderSide(color: AppColors.borderBright),
              foregroundColor: AppColors.accent,
            ),
            icon: _sendingQuestion
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 19),
          ),
        ),
      ],
    );
  }

  Widget _headerButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      onPressed: onPressed,
      color: AppColors.textDim,
      hoverColor: AppColors.accentGlowSoft,
      icon: Icon(icon, size: 19),
    );
  }

  Widget _messageArea(OpeningTrainerController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScroll.hasClients) return;
      _messagesScroll.jumpTo(_messagesScroll.position.maxScrollExtent);
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.r10,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: controller.messages.isEmpty
          ? Center(
              child: MakeChessLocalizedText(
                'Сообщений пока нет',
                style: AppTextStyles.muted,
              ),
            )
          : ListView.builder(
              controller: _messagesScroll,
              padding: const EdgeInsets.all(9),
              itemCount: controller.messages.length,
              itemBuilder: (context, index) {
                final message = controller.messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        _messageIcon(message.kind),
                        size: 16,
                        color: _messageColor(message.kind),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          message.text,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _candidateArea(OpeningTrainerController controller) {
    if (controller.analyzing) {
      return SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 9),
            MakeChessLocalizedText(
              'Stockfish оценивает варианты…',
              style: AppTextStyles.bodyDim,
            ),
          ],
        ),
      );
    }

    final engine = controller.engineSuggestions;
    final opening = controller.openingSuggestions;
    if (engine.isEmpty && opening.isEmpty) return const SizedBox.shrink();

    Widget group(
      String title,
      Color color,
      List<OpeningMoveSuggestion> items,
    ) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: AppRadius.r10,
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              for (final item in items.take(4))
                Text(
                  '${item.rank}. ${item.shownMove}  '
                  '${item.scoreAvailable ? _formatScore(item.score) : 'без оценки'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text,
                    fontWeight: item.rank == 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        group(
          'Stockfish',
          OpeningTrainerController.engineArrowColor,
          engine,
        ),
        const SizedBox(width: 8),
        group(
          'Дебютная база',
          OpeningTrainerController.openingArrowColor,
          opening,
        ),
      ],
    );
  }

  Widget _footer(OpeningTrainerController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${controller.currentOpeningLabel} • ${controller.mode.title} • '
                  '${controller.settings.depthFullMoves} ходов • '
                  'Δ${controller.settings.maxEvaluationDrop.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: controller.sessionActive
                ? AppNeoButton(
                    text: MakeChessLocalization.phrase('Стоп'),
                    icon: Icons.stop_circle_outlined,
                    onTap: widget.onStop,
                    danger: true,
                    compact: true,
                  )
                : AppNeoButton(
                    text: MakeChessLocalization.phrase('Начать'),
                    icon: Icons.play_arrow,
                    onTap: controller.canStart
                        ? () {
                            widget.onStart();
                          }
                        : null,
                    compact: true,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOpeningChooser(
    OpeningTrainerController controller,
  ) async {
    List<OpeningDatabaseItem>? cachedOpenings =
        controller.catalog.isEmpty ? null : controller.catalog;

    String page = 'modes';
    String loadingText = 'Подождите, дебют загружается';
    String errorText = '';
    String searchQuery = '';
    String selectedColor = 'white';
    OpeningSelectionSort selectedSort = OpeningSelectionSort.name;
    List<OpeningDatabaseItem> shownOpenings = <OpeningDatabaseItem>[];
    OpeningDatabaseItem? previewSelectedItem;
    List<_OpeningPreviewBranch> previewBranches =
        <_OpeningPreviewBranch>[];
    int previewVisibleCount = 4;

    StateSetter? dialogSetState;
    BuildContext? dialogContext;
    bool dialogIsOpen = true;
    int requestNumber = 0;
    Future<void> Function()? retryAction;

    void updateDialog(VoidCallback change) {
      final setter = dialogSetState;
      if (!dialogIsOpen || !mounted || setter == null) return;
      setter(change);
    }

    void backToModes() {
      requestNumber++;
      retryAction = null;
      updateDialog(() {
        page = 'modes';
        errorText = '';
        searchQuery = '';
      });
    }

    void closeDialog() {
      requestNumber++;
      final currentContext = dialogContext;
      if (!dialogIsOpen || currentContext == null) return;
      Navigator.of(currentContext).pop();
    }

    Future<List<OpeningDatabaseItem>> ensureCatalog() async {
      final current = cachedOpenings;
      if (current != null && current.isNotEmpty) return current;

      final loaded = await controller.fetchPublishedOpenings();
      cachedOpenings = loaded;
      controller.setOpeningCatalog(loaded);
      return loaded;
    }

    int compareOpenings(
      OpeningDatabaseItem a,
      OpeningDatabaseItem b,
      String color,
      OpeningSelectionSort sort,
    ) {
      switch (sort) {
        case OpeningSelectionSort.firstMoves:
          final byMoves = a.firstMovesLabel.compareTo(b.firstMovesLabel);
          return byMoves != 0 ? byMoves : a.name.compareTo(b.name);
        case OpeningSelectionSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case OpeningSelectionSort.popularity:
          final result = b.popularity.compareTo(a.popularity);
          return result != 0 ? result : a.name.compareTo(b.name);
        case OpeningSelectionSort.efficiency:
          final result =
              b.efficiencyFor(color).compareTo(a.efficiencyFor(color));
          return result != 0 ? result : a.name.compareTo(b.name);
      }
    }

    late Future<void> Function(String, OpeningSelectionSort) openManualList;
    openManualList = (
      String color,
      OpeningSelectionSort sort,
    ) async {
      final currentRequest = ++requestNumber;
      retryAction = () => openManualList(color, sort);

      updateDialog(() {
        page = 'loading';
        loadingText = 'Подождите, дебют загружается';
        errorText = '';
        selectedColor = color;
        selectedSort = sort;
        searchQuery = '';
      });

      try {
        final openings = await ensureCatalog();
        if (!dialogIsOpen || currentRequest != requestNumber) return;

        final sorted = openings.toList(growable: true)
          ..sort((a, b) => compareOpenings(a, b, color, sort));

        updateDialog(() {
          shownOpenings = sorted;
          page = 'list';
        });
      } catch (error) {
        if (!dialogIsOpen || currentRequest != requestNumber) return;
        updateDialog(() {
          errorText = '$error';
          page = 'error';
        });
      }
    };

    late Future<void> Function(OpeningDatabaseItem) selectOpening;
    selectOpening = (OpeningDatabaseItem selected) async {
      final currentRequest = ++requestNumber;
      retryAction = () => selectOpening(selected);

      updateDialog(() {
        page = 'loading';
        loadingText = 'Подождите, дебют загружается';
        errorText = '';
      });

      try {
        final fullOpening =
            await controller.fetchPublishedOpeningFamily(selected);
        if (!dialogIsOpen || currentRequest != requestNumber) return;

        controller.loadDatabaseOpening(
          fullOpening,
          studentColor: selectedColor,
        );
        await widget.onTreeLoaded();

        if (!dialogIsOpen || currentRequest != requestNumber) return;
        closeDialog();
      } catch (error) {
        if (!dialogIsOpen || currentRequest != requestNumber) return;
        updateDialog(() {
          errorText = '$error';
          page = 'error';
        });
      }
    };


    late Future<void> Function(OpeningDatabaseItem) openPreview;
    openPreview = (OpeningDatabaseItem selected) async {
      final currentRequest = ++requestNumber;
      retryAction = () => openPreview(selected);

      updateDialog(() {
        page = 'loading';
        loadingText = 'Подождите, дебют загружается';
        errorText = '';
      });

      try {
        final fullSelected =
            await controller.fetchPublishedOpeningFamily(selected);
        if (!dialogIsOpen || currentRequest != requestNumber) return;

        final branches = <_OpeningPreviewBranch>[];
        final seen = <String>{};

        void addBranches(OpeningDatabaseItem item) {
          for (final branch in _previewBranchesFromDatabaseItem(
            item,
            limit: 1000000,
          )) {
            final signature = branch.moves.join(' ');
            if (!seen.add(signature)) continue;
            branches.add(branch);
          }
        }

        addBranches(fullSelected);

        final catalog = cachedOpenings ?? controller.catalog;
        final family = _openingFamilyName(selected.name);
        final related = catalog
            .where(
              (item) =>
                  item.id != selected.id &&
                  _openingFamilyName(item.name) == family &&
                  item.firstMovesUci.isNotEmpty,
            )
            .toList(growable: true)
          ..sort((a, b) {
            final aPrefix =
                _commonMovePrefix(selected.firstMovesUci, a.firstMovesUci);
            final bPrefix =
                _commonMovePrefix(selected.firstMovesUci, b.firstMovesUci);
            final byPrefix = bPrefix.compareTo(aPrefix);
            if (byPrefix != 0) return byPrefix;
            return a.name.compareTo(b.name);
          });

        for (final relatedItem in related) {
          addBranches(relatedItem);
        }

        if (branches.isEmpty && selected.firstMovesUci.isNotEmpty) {
          branches.add(
            _OpeningPreviewBranch(
              title: selected.name,
              moves: selected.firstMovesUci,
              startFen: selected.startFen,
            ),
          );
        }

        branches.sort((a, b) {
          final byLength = b.moves.length.compareTo(a.moves.length);
          if (byLength != 0) return byLength;
          return a.title.compareTo(b.title);
        });

        if (!dialogIsOpen || currentRequest != requestNumber) return;
        updateDialog(() {
          previewSelectedItem = selected;
          previewBranches =
              List<_OpeningPreviewBranch>.unmodifiable(branches);
          previewVisibleCount =
              branches.length < 4 ? branches.length : 4;
          page = 'preview';
        });
      } catch (error) {
        if (!dialogIsOpen || currentRequest != requestNumber) return;
        updateDialog(() {
          errorText = '$error';
          page = 'error';
        });
      }
    };

    late Future<void> Function(OpeningTrainerMode) chooseAutomatic;
    chooseAutomatic = (OpeningTrainerMode mode) async {
      if (mode == OpeningTrainerMode.free) {
        controller.configureAutomaticMode(
          mode,
          studentColor: controller.studentColor,
        );
        closeDialog();
        return;
      }

      final currentRequest = ++requestNumber;
      retryAction = () => chooseAutomatic(mode);
      updateDialog(() {
        page = 'loading';
        loadingText = 'Подождите, дебют загружается';
        errorText = '';
      });

      try {
        await ensureCatalog();
        if (!dialogIsOpen || currentRequest != requestNumber) return;

        controller.configureAutomaticMode(
          mode,
          studentColor: controller.studentColor,
        );
        closeDialog();
      } catch (error) {
        if (!dialogIsOpen || currentRequest != requestNumber) return;
        updateDialog(() {
          errorText = '$error';
          page = 'error';
        });
      }
    };

    Widget modeButton({
      required String text,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return SizedBox(
        height: 42,
        child: AppNeoButton(
          text: MakeChessLocalization.phrase(text),
          icon: icon,
          onTap: onTap,
          compact: true,
        ),
      );
    }

    String dialogTitle() {
      switch (page) {
        case 'loading':
          return 'Загрузка дебюта';
        case 'list':
          return 'Дебюты за '
              '${selectedColor == 'black' ? 'чёрных' : 'белых'} '
              '${selectedSort.title}';
        case 'preview':
          return 'Предпросмотр дебюта';
        case 'error':
          return 'Дебют не загрузился';
        default:
          return 'Выбрать дебют';
      }
    }

    Widget modesPage() {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MakeChessLocalizedText('За белых', style: AppTextStyles.panelTitle),
            const SizedBox(height: 7),
            for (final sort in OpeningSelectionSort.values) ...<Widget>[
              modeButton(
                text: 'Выбрать дебют ${sort.title} за белых',
                icon: Icons.chevron_right,
                onTap: () {
                  openManualList('white', sort);
                },
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 9),
            MakeChessLocalizedText('За чёрных', style: AppTextStyles.panelTitle),
            const SizedBox(height: 7),
            for (final sort in OpeningSelectionSort.values) ...<Widget>[
              modeButton(
                text: 'Выбрать дебют ${sort.title} за чёрных',
                icon: Icons.chevron_right,
                onTap: () {
                  openManualList('black', sort);
                },
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 9),
            MakeChessLocalizedText('Автоматические режимы', style: AppTextStyles.panelTitle),
            const SizedBox(height: 7),
            modeButton(
              text: 'Автоматический выбор по Stockfish',
              icon: Icons.memory,
              onTap: () {
                chooseAutomatic(OpeningTrainerMode.automaticStockfish);
              },
            ),
            const SizedBox(height: 6),
            modeButton(
              text: 'Автоматический выбор по дебютному древу',
              icon: Icons.account_tree_outlined,
              onTap: () {
                chooseAutomatic(OpeningTrainerMode.automaticTree);
              },
            ),
            const SizedBox(height: 6),
            modeButton(
              text: 'Автоматический комбинированный режим',
              icon: Icons.merge_type,
              onTap: () {
                chooseAutomatic(OpeningTrainerMode.automaticCombined);
              },
            ),
            const SizedBox(height: 6),
            modeButton(
              text: 'Свободный режим',
              icon: Icons.open_with,
              onTap: () {
                chooseAutomatic(OpeningTrainerMode.free);
              },
            ),
          ],
        ),
      );
    }

    Widget loadingPage() {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              loadingText,
              textAlign: TextAlign.center,
              style: AppTextStyles.panelTitle,
            ),
            const SizedBox(height: 9),
            MakeChessLocalizedText(
              'Окно не закрывается. После загрузки здесь сразу появится '
              'список конкретных дебютов.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyDim,
            ),
          ],
        ),
      );
    }

    Widget listPage() {
      final normalizedQuery = searchQuery.trim().toLowerCase();
      final visible = normalizedQuery.isEmpty
          ? shownOpenings
          : shownOpenings.where((item) {
              return item.name.toLowerCase().contains(normalizedQuery) ||
                  item.firstMovesLabel
                      .toLowerCase()
                      .contains(normalizedQuery);
            }).toList(growable: false);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            autofocus: true,
            onChanged: (value) {
              updateDialog(() {
                searchQuery = value;
              });
            },
            decoration: AppInputs.dark(
              labelText: MakeChessLocalization.phrase('Найти дебют по русскому названию'),
              dense: true,
            ).copyWith(
              prefixIcon: const Icon(Icons.search),
              hintText: MakeChessLocalization.phrase('Например: Сицилианская защита'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Найдено: ${visible.length}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: MakeChessLocalizedText(
                      'Подходящих дебютов не найдено.',
                      style: AppTextStyles.bodyDim,
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.borderSoft,
                    ),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        leading: const Icon(
                          Icons.account_tree_outlined,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          item.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${item.firstMovesLabel} • популярность '
                          '${item.popularity.toStringAsFixed(0)} • эффективность '
                          '${item.efficiencyFor(selectedColor).toStringAsFixed(1)}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            TextButton.icon(
                              onPressed: () {
                                openPreview(item);
                              },
                              icon: const Icon(
                                Icons.preview_outlined,
                                size: 18,
                              ),
                              label: const MakeChessLocalizedText('Предпросмотр'),
                            ),
                            IconButton(
                              tooltip: MakeChessLocalization.phrase('Выбрать этот дебют'),
                              onPressed: () {
                                selectOpening(item);
                              },
                              icon: const Icon(
                                Icons.chevron_right,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          selectOpening(item);
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    }


    Widget previewPage() {
      final selected = previewSelectedItem;
      final totalBranchCount = previewBranches.length;
      final safeVisibleCount = previewVisibleCount > totalBranchCount
          ? totalBranchCount
          : previewVisibleCount;
      final visibleBranches = previewBranches
          .take(safeVisibleCount)
          .toList(growable: false);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selected?.name ?? 'Выбранный дебют',
                      style: AppTextStyles.panelTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalBranchCount > 0
                          ? 'Показаны $safeVisibleCount из '
                              '$totalBranchCount самых длинных разных ветвей. '
                              'Каждое нажатие добавляет следующую ветвь.'
                          : 'Для этого дебюта в базе не найдено ветвей.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  if (safeVisibleCount < totalBranchCount)
                    AppNeoButton(
                      text: MakeChessLocalization.phrase('Добавить вариант'),
                      icon: Icons.add,
                      onTap: () {
                        updateDialog(() {
                          final next = previewVisibleCount + 1;
                          previewVisibleCount = next > totalBranchCount
                              ? totalBranchCount
                              : next;
                        });
                      },
                      compact: true,
                    ),
                  if (selected != null)
                    AppNeoButton(
                      text: MakeChessLocalization.phrase('Выбрать дебют'),
                      icon: Icons.check,
                      onTap: () {
                        selectOpening(selected);
                      },
                      compact: true,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visibleBranches.isEmpty
                ? Center(
                    child: MakeChessLocalizedText(
                      'Для предпросмотра не найдено ни одной ветки.',
                      style: AppTextStyles.bodyDim,
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleBranches.length,
                    itemBuilder: (context, index) {
                      return _OpeningPreviewBoard(
                        key: ValueKey(
                          '${selected?.id ?? 'opening'}_${index}_'
                          '${visibleBranches[index].moves.join('-')}',
                        ),
                        branch: visibleBranches[index],
                        flipped: selectedColor == 'black',
                      );
                    },
                  ),
          ),
        ],
      );
    }
    Widget errorPage() {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 16),
            MakeChessLocalizedText(
              'Не удалось получить дебют из базы.',
              textAlign: TextAlign.center,
              style: AppTextStyles.panelTitle,
            ),
            const SizedBox(height: 10),
            Text(
              errorText,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyDim,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                AppNeoButton(
                  text: MakeChessLocalization.phrase('Повторить'),
                  icon: Icons.refresh,
                  onTap: () {
                    final action = retryAction;
                    if (action != null) action();
                  },
                  compact: true,
                ),
                AppNeoButton(
                  text: MakeChessLocalization.phrase('Вернуться к режимам'),
                  icon: Icons.arrow_back,
                  onTap: backToModes,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      barrierDismissible: false,
      builder: (chooserContext) {
        dialogContext = chooserContext;
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;

            Widget currentPage;
            switch (page) {
              case 'loading':
                currentPage = loadingPage();
                break;
              case 'list':
                currentPage = listPage();
                break;
              case 'preview':
                currentPage = previewPage();
                break;
              case 'error':
                currentPage = errorPage();
                break;
              default:
                currentPage = modesPage();
                break;
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.r16,
                side: const BorderSide(color: AppColors.borderBright),
              ),
              title: Row(
                children: <Widget>[
                  if (page == 'list' ||
                      page == 'loading' ||
                      page == 'preview' ||
                      page == 'error')
                    IconButton(
                      tooltip: page == 'preview'
                          ? 'Назад к списку дебютов'
                          : 'Назад к выбору режима',
                      onPressed: page == 'preview'
                          ? () {
                              requestNumber++;
                              updateDialog(() {
                                page = 'list';
                              });
                            }
                          : backToModes,
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const Icon(
                      Icons.account_tree_outlined,
                      color: AppColors.accent,
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      dialogTitle(),
                      style: AppTextStyles.panelTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: MakeChessLocalization.phrase('Закрыть'),
                    onPressed: closeDialog,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                height: 520,
                child: currentPage,
              ),
            );
          },
        );
      },
    );

    dialogIsOpen = false;
    requestNumber++;
  }

  Future<void> _openSettings(OpeningTrainerController controller) async {
    final depthCtl = TextEditingController(
      text: controller.settings.depthFullMoves.toString(),
    );
    final variantsCtl = TextEditingController(
      text: controller.settings.maxVariants.toString(),
    );
    final dropCtl = TextEditingController(
      text: controller.settings.maxEvaluationDrop.toStringAsFixed(2),
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (dialogContext) {
        bool loadingTree = false;
        String? localError;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> loadTreeFromFile() async {
              setLocalState(() {
                loadingTree = true;
                localError = null;
              });
              try {
                await controller.loadOpeningFile();
                await widget.onTreeLoaded();
              } catch (error) {
                if (dialogContext.mounted) {
                  setLocalState(() => localError = '$error');
                }
              } finally {
                if (dialogContext.mounted) {
                  setLocalState(() => loadingTree = false);
                }
              }
            }

            Future<void> loadTreeFromSelectel() async {
              setLocalState(() {
                loadingTree = true;
                localError = null;
              });

              try {
                final openings = await controller.fetchPublishedOpenings();
                if (openings.isEmpty) {
                  throw StateError(
                    'В Selectel пока нет опубликованных дебютов.',
                  );
                }
                if (!dialogContext.mounted) return;

                final selected = await showDialog<OpeningDatabaseItem>(
                  context: dialogContext,
                  barrierColor: Colors.black.withValues(alpha: 0.72),
                  builder: (selectionContext) {
                    return AlertDialog(
                      backgroundColor: AppColors.surface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.r16,
                        side: const BorderSide(
                          color: AppColors.borderBright,
                        ),
                      ),
                      title: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.cloud_download_outlined,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: MakeChessLocalizedText(
                              'Дебюты из Selectel',
                              style: AppTextStyles.panelTitle,
                            ),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: 560,
                        height: 390,
                        child: ListView.separated(
                          itemCount: openings.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: AppColors.borderSoft,
                          ),
                          itemBuilder: (context, index) {
                            final item = openings[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.account_tree_outlined,
                                color: AppColors.accent,
                              ),
                              title: Text(
                                item.name,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: MakeChessLocalizedText(
                                'Ученик: '
                                '${item.studentColor == 'black' ? 'чёрные' : 'белые'}'
                                '${item.sourceName == null ? '' : ' • ${item.sourceName}'}',
                                style: AppTextStyles.caption,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.textDim,
                              ),
                              onTap: () =>
                                  Navigator.of(selectionContext).pop(item),
                            );
                          },
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () =>
                              Navigator.of(selectionContext).pop(),
                          child: const MakeChessLocalizedText('Отмена'),
                        ),
                      ],
                    );
                  },
                );

                if (selected == null) return;
                final fullOpening =
                    await controller.fetchPublishedOpeningFamily(selected);
                controller.loadDatabaseOpening(fullOpening);
                await widget.onTreeLoaded();
              } catch (error) {
                if (dialogContext.mounted) {
                  setLocalState(() => localError = '$error');
                }
              } finally {
                if (dialogContext.mounted) {
                  setLocalState(() => loadingTree = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.r16,
                side: const BorderSide(color: AppColors.borderBright),
              ),
              title: Row(
                children: <Widget>[
                  const Icon(
                    Icons.tune,
                    color: AppColors.accent,
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: MakeChessLocalizedText(
                      'Настройки дебютного тренажёра',
                      style: AppTextStyles.panelTitle,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 44,
                        child: AppNeoButton(
                          text: controller.tree == null
                              ? 'Выбрать дебют из Selectel'
                              : 'Заменить из Selectel: ${controller.tree!.name}',
                          icon: loadingTree
                              ? Icons.hourglass_top
                              : Icons.cloud_download_outlined,
                          onTap: loadingTree ? null : loadTreeFromSelectel,
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: AppNeoButton(
                          text: MakeChessLocalization.phrase('Загрузить локальный JSON'),
                          icon: Icons.file_open,
                          onTap: loadingTree ? null : loadTreeFromFile,
                          compact: true,
                        ),
                      ),
                      if (localError != null) ...<Widget>[
                        const SizedBox(height: 7),
                        Text(
                          localError!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: depthCtl,
                        style: AppTextStyles.body,
                        cursorColor: AppColors.accent,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppInputs.dark(
                          labelText: MakeChessLocalization.phrase('Глубина дебюта, полных ходов'),
                          dense: true,
                        ).copyWith(
                          helperText: MakeChessLocalization.phrase('10 = 10 ходов белых и 10 ходов чёрных'),
                          helperStyle: AppTextStyles.caption,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: variantsCtl,
                        style: AppTextStyles.body,
                        cursorColor: AppColors.accent,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppInputs.dark(
                          labelText: MakeChessLocalization.phrase('Количество учебных стрелок'),
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dropCtl,
                        style: AppTextStyles.body,
                        cursorColor: AppColors.accent,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                        decoration: AppInputs.dark(
                          labelText: MakeChessLocalization.phrase('Допустимое падение оценки стрелок'),
                          dense: true,
                        ).copyWith(
                          helperText: MakeChessLocalization.phrase('Не ограничивает линии программируемого бота.'),
                          helperStyle: AppTextStyles.caption,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        child: AppNeoButton(
                          text: MakeChessLocalization.phrase('Настройки бота'),
                          icon: Icons.smart_toy_outlined,
                          onTap: () async {
                            await _openBotSettings(controller);
                            if (dialogContext.mounted) {
                              setLocalState(() {});
                            }
                          },
                          compact: true,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${controller.settings.botMoveSource.title} • '
                        '${controller.settings.cyclesPerSession} цикл(а) • '
                        '${controller.settings.gamesPerCycle} партий в цикле • '
                        '${controller.settings.identicalResponseGames} '
                        'одинаковых партий',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              actions: <Widget>[
                SizedBox(
                  width: 112,
                  child: AppNeoButton(
                    text: MakeChessLocalization.phrase('Отмена'),
                    icon: Icons.close,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: 122,
                  child: AppNeoButton(
                    text: MakeChessLocalization.phrase('Сохранить'),
                    icon: Icons.save_outlined,
                    onTap: () {
                      final depth = int.tryParse(depthCtl.text.trim());
                      final variants = int.tryParse(variantsCtl.text.trim());
                      final drop = double.tryParse(
                        dropCtl.text.trim().replaceAll(',', '.'),
                      );
                      if (depth == null || variants == null || drop == null) {
                        setLocalState(
                          () => localError =
                              'Проверьте числовые значения настроек.',
                        );
                        return;
                      }

                      try {
                        controller.updateSettings(
                          controller.settings.copyWith(
                            depthFullMoves: depth,
                            maxVariants: variants,
                            maxEvaluationDrop: drop,
                          ),
                        );
                        Navigator.of(dialogContext).pop(true);
                      } catch (error) {
                        setLocalState(() => localError = '$error');
                      }
                    },
                    compact: true,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    depthCtl.dispose();
    variantsCtl.dispose();
    dropCtl.dispose();

    if (saved == true) await widget.onSettingsChanged();
  }

  Future<void> _openBotSettings(
    OpeningTrainerController controller,
  ) async {
    final current = controller.settings;
    var source = current.botMoveSource;

    final cyclesCtl = TextEditingController(
      text: current.cyclesPerSession.toString(),
    );
    final gamesCtl = TextEditingController(
      text: current.gamesPerCycle.toString(),
    );
    final identicalCtl = TextEditingController(
      text: current.identicalResponseGames.toString(),
    );
    final depthCtl = TextEditingController(
      text: current.botEngineDepth.toString(),
    );
    final timeCtl = TextEditingController(
      text: current.botThinkingTimeMs.toString(),
    );
    final delayCtl = TextEditingController(
      text: current.botMoveDelayMs.toString(),
    );

    final stockfishCtls = <int, TextEditingController>{
      for (var line = 1; line <= 5; line++)
        line: TextEditingController(
          text: current.stockfishLineRules[line] ?? '',
        ),
    };
    final treeCtls = <int, TextEditingController>{
      for (var line = 1; line <= 5; line++)
        line: TextEditingController(
          text: current.openingTreeLineRules[line] ?? '',
        ),
    };

    Map<int, String> collect(
      Map<int, TextEditingController> controllers,
    ) {
      return <int, String>{
        for (var line = 1; line <= 5; line++)
          line: controllers[line]!.text.trim(),
      };
    }

    String? validate({
      required int cycles,
      required int games,
      required int identical,
      required Map<int, String> stockfishRules,
      required Map<int, String> treeRules,
    }) {
      if (cycles < 1) return 'Количество циклов должно быть не меньше 1.';
      if (games < 1) {
        return 'Количество партий в цикле должно быть не меньше 1.';
      }
      if (identical < 1 || identical > games) {
        return 'Количество одинаковых партий должно быть от 1 до $games.';
      }

      final stockfishError =
          OpeningBotReplyRuleParser.validateRuleSet(stockfishRules);
      if (stockfishError != null) {
        return 'Stockfish: $stockfishError';
      }
      final treeError =
          OpeningBotReplyRuleParser.validateRuleSet(treeRules);
      if (treeError != null) {
        return 'Дебютное древо: $treeError';
      }
      return null;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) {
        String? localError;
        String? localSuccess;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Widget sourceCard(
              OpeningBotMoveSource value,
              IconData icon,
            ) {
              final selected = source == value;
              return InkWell(
                onTap: () => setLocalState(() {
                  source = value;
                  localError = null;
                  localSuccess = null;
                }),
                borderRadius: AppRadius.r12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.surfaceCard,
                    borderRadius: AppRadius.r12,
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.borderSoft,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected
                            ? AppColors.accent
                            : AppColors.textDim,
                      ),
                      const SizedBox(width: 9),
                      Icon(icon, color: AppColors.accent),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              value.title,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value.description,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget ruleSection({
              required String title,
              required String description,
              required IconData icon,
              required Map<int, TextEditingController> controllers,
              required bool active,
            }) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accent.withValues(alpha: 0.07)
                      : AppColors.surfaceCard.withValues(alpha: 0.55),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color:
                        active ? AppColors.accent : AppColors.borderSoft,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          icon,
                          color: active
                              ? AppColors.accent
                              : AppColors.textDim,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.panelTitle,
                          ),
                        ),
                        if (active)
                          MakeChessLocalizedText(
                            'АКТИВНО',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(description, style: AppTextStyles.caption),
                    const SizedBox(height: 10),
                    for (var line = 1; line <= 5; line++) ...<Widget>[
                      TextField(
                        controller: controllers[line],
                        style: AppTextStyles.body,
                        cursorColor: AppColors.accent,
                        decoration: AppInputs.dark(
                          labelText: 'Линия $line — номера ответов бота',
                          dense: true,
                        ).copyWith(
                          hintText: line == 1 ? 'все' : 'например 3,5,7 или 4-8',
                          helperText: line == 1
                              ? 'Можно написать «все». Незаписанные номера '
                                  'тоже идут по линии 1.'
                              : null,
                          helperStyle: AppTextStyles.caption,
                        ),
                      ),
                      if (line < 5) const SizedBox(height: 9),
                    ],
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.r16,
                side: const BorderSide(color: AppColors.borderBright),
              ),
              title: Row(
                children: <Widget>[
                  const Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: MakeChessLocalizedText(
                      'Настройки бота',
                      style: AppTextStyles.panelTitle,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 720,
                height: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      MakeChessLocalizedText(
                        'Источник ответных ходов',
                        style: AppTextStyles.panelTitle,
                      ),
                      const SizedBox(height: 8),
                      sourceCard(
                        OpeningBotMoveSource.stockfish,
                        Icons.memory,
                      ),
                      const SizedBox(height: 8),
                      sourceCard(
                        OpeningBotMoveSource.openingTree,
                        Icons.account_tree_outlined,
                      ),
                      const SizedBox(height: 16),
                      MakeChessLocalizedText(
                        'Структура учебной серии',
                        style: AppTextStyles.panelTitle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: cyclesCtl,
                              style: AppTextStyles.body,
                              cursorColor: AppColors.accent,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: AppInputs.dark(
                                labelText: MakeChessLocalization.phrase('Циклов за сессию'),
                                dense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: gamesCtl,
                              style: AppTextStyles.body,
                              cursorColor: AppColors.accent,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: AppInputs.dark(
                                labelText: MakeChessLocalization.phrase('Партий в одном цикле'),
                                dense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: identicalCtl,
                              style: AppTextStyles.body,
                              cursorColor: AppColors.accent,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: AppInputs.dark(
                                labelText: MakeChessLocalization.phrase('Партий с одинаковыми ответами'),
                                dense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      MakeChessLocalizedText(
                        'Номер в правилах — это номер ответного хода именно '
                        'бота: первый ответ, второй ответ, третий ответ и так далее.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 15),
                      ruleSection(
                        title: 'ПРАВИЛА ПО STOCKFISH',
                        description:
                            'Линия 1 — лучший ход Stockfish, линия 2 — второй, '
                            'далее до линии 5.',
                        icon: Icons.memory,
                        controllers: stockfishCtls,
                        active: source == OpeningBotMoveSource.stockfish,
                      ),
                      const SizedBox(height: 12),
                      ruleSection(
                        title: 'ПРАВИЛА ПО ДЕБЮТНОМУ ДРЕВУ',
                        description:
                            'Сначала остаются только ветви дебютного дерева. '
                            'Затем Stockfish сортирует их от лучшей к худшей.',
                        icon: Icons.account_tree_outlined,
                        controllers: treeCtls,
                        active: source == OpeningBotMoveSource.openingTree,
                      ),
                      const SizedBox(height: 15),
                      MakeChessLocalizedText(
                        'Stockfish и задержка',
                        style: AppTextStyles.panelTitle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: depthCtl,
                              style: AppTextStyles.body,
                              cursorColor: AppColors.accent,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: AppInputs.dark(
                                labelText: MakeChessLocalization.phrase('Глубина Stockfish'),
                                dense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: timeCtl,
                              style: AppTextStyles.body,
                              cursorColor: AppColors.accent,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: AppInputs.dark(
                                labelText: MakeChessLocalization.phrase('Время анализа, мс'),
                                dense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: delayCtl,
                              style: AppTextStyles.body,
                              cursorColor: AppColors.accent,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: AppInputs.dark(
                                labelText: MakeChessLocalization.phrase('Пауза перед ходом, мс'),
                                dense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (localError != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          localError!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      if (localSuccess != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          localSuccess!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(14, 5, 14, 14),
              actions: <Widget>[
                SizedBox(
                  width: 138,
                  child: AppNeoButton(
                    text: MakeChessLocalization.phrase('Сбросить серию'),
                    icon: Icons.restart_alt,
                    onTap: () {
                      controller.resetBotProgramProgress();
                      setLocalState(() {
                        localError = null;
                        localSuccess = 'Счётчики серии сброшены.';
                      });
                    },
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: 148,
                  child: AppNeoButton(
                    text: MakeChessLocalization.phrase('Проверить правила'),
                    icon: Icons.rule,
                    onTap: () {
                      final cycles =
                          int.tryParse(cyclesCtl.text.trim()) ?? 0;
                      final games =
                          int.tryParse(gamesCtl.text.trim()) ?? 0;
                      final identical =
                          int.tryParse(identicalCtl.text.trim()) ?? 0;
                      final error = validate(
                        cycles: cycles,
                        games: games,
                        identical: identical,
                        stockfishRules: collect(stockfishCtls),
                        treeRules: collect(treeCtls),
                      );
                      setLocalState(() {
                        localError = error;
                        localSuccess =
                            error == null ? 'Правила не конфликтуют.' : null;
                      });
                    },
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: 102,
                  child: AppNeoButton(
                    text: MakeChessLocalization.phrase('Отмена'),
                    icon: Icons.close,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: AppNeoButton(
                    text: MakeChessLocalization.phrase('Сохранить'),
                    icon: Icons.save_outlined,
                    onTap: () {
                      final cycles =
                          int.tryParse(cyclesCtl.text.trim());
                      final games =
                          int.tryParse(gamesCtl.text.trim());
                      final identical =
                          int.tryParse(identicalCtl.text.trim());
                      final depth = int.tryParse(depthCtl.text.trim());
                      final time = int.tryParse(timeCtl.text.trim());
                      final delay = int.tryParse(delayCtl.text.trim());

                      if (cycles == null ||
                          games == null ||
                          identical == null ||
                          depth == null ||
                          time == null ||
                          delay == null) {
                        setLocalState(() {
                          localError =
                              'Проверьте числовые значения настроек.';
                          localSuccess = null;
                        });
                        return;
                      }

                      final stockfishRules = collect(stockfishCtls);
                      final treeRules = collect(treeCtls);
                      final error = validate(
                        cycles: cycles,
                        games: games,
                        identical: identical,
                        stockfishRules: stockfishRules,
                        treeRules: treeRules,
                      );
                      if (error != null) {
                        setLocalState(() {
                          localError = error;
                          localSuccess = null;
                        });
                        return;
                      }

                      try {
                        controller.updateSettings(
                          controller.settings.copyWith(
                            botMoveSource: source,
                            cyclesPerSession: cycles,
                            gamesPerCycle: games,
                            identicalResponseGames: identical,
                            stockfishLineRules: stockfishRules,
                            openingTreeLineRules: treeRules,
                            botEngineDepth: depth,
                            botThinkingTimeMs: time,
                            botMoveDelayMs: delay,
                          ),
                        );
                        Navigator.of(dialogContext).pop(true);
                      } catch (error) {
                        setLocalState(() {
                          localError = '$error';
                          localSuccess = null;
                        });
                      }
                    },
                    compact: true,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    cyclesCtl.dispose();
    gamesCtl.dispose();
    identicalCtl.dispose();
    depthCtl.dispose();
    timeCtl.dispose();
    delayCtl.dispose();
    for (final controller in stockfishCtls.values) {
      controller.dispose();
    }
    for (final controller in treeCtls.values) {
      controller.dispose();
    }

    if (saved == true) await widget.onSettingsChanged();
  }

  static String _formatScore(double score) {
    if (score.abs() >= 90) return score > 0 ? 'мат' : 'мат сопернику';
    final sign = score > 0 ? '+' : '';
    return '$sign${score.toStringAsFixed(2)}';
  }

  static IconData _messageIcon(OpeningTrainerMessageKind kind) {
    switch (kind) {
      case OpeningTrainerMessageKind.info:
        return Icons.info_outline;
      case OpeningTrainerMessageKind.success:
        return Icons.check_circle_outline;
      case OpeningTrainerMessageKind.warning:
        return Icons.warning_amber_rounded;
      case OpeningTrainerMessageKind.error:
        return Icons.error_outline;
      case OpeningTrainerMessageKind.bot:
        return Icons.smart_toy_outlined;
      case OpeningTrainerMessageKind.student:
        return Icons.person_outline;
    }
  }

  static Color _messageColor(OpeningTrainerMessageKind kind) {
    switch (kind) {
      case OpeningTrainerMessageKind.info:
        return AppColors.accent;
      case OpeningTrainerMessageKind.success:
        return AppColors.success;
      case OpeningTrainerMessageKind.warning:
        return AppColors.warning;
      case OpeningTrainerMessageKind.error:
        return AppColors.danger;
      case OpeningTrainerMessageKind.bot:
        return const Color(0xFFB05070);
      case OpeningTrainerMessageKind.student:
        return const Color(0xFF9DB7FF);
    }
  }
}

String _normalizeUci(String source) {
  final match = RegExp(
    r'[a-h][1-8][a-h][1-8][qrbn]?',
    caseSensitive: false,
  ).firstMatch(source.trim());
  return match?.group(0)?.toLowerCase() ?? '';
}

bool _isUciMove(String source) {
  return RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(source);
}
