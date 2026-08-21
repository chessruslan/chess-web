// MakeChess global Stockfish router.
// Every existing caller keeps importing this file. The selected backend is
// switched globally by the "Local Stockfish" toggle.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'stockfish_network_service.dart' as network;

const String _localHost = '127.0.0.1:17891';
final Uri _localHealthUrl = Uri.http(_localHost, '/health');

/// Single source of truth for the whole web application.
final ValueNotifier<bool> localStockfishEnabledNotifier =
    ValueNotifier<bool>(false);

bool get isLocalStockfishEnabled => localStockfishEnabledNotifier.value;
String get activeStockfishBackend =>
    isLocalStockfishEnabled ? 'local' : 'network';

Future<bool> _localBridgeReady() async {
  Object? lastError;
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      final response = await http
          .get(_localHealthUrl)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['ok'] == true && decoded['stockfish'] == true) {
          return true;
        }
      }
    } catch (e) {
      lastError = e;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  if (lastError != null) {
    debugPrint('Local Stockfish health check: $lastError');
  }
  return false;
}

Future<bool> setLocalStockfishEnabled(bool enabled) async {
  if (!enabled) {
    if (localStockfishEnabledNotifier.value) {
      localStockfishEnabledNotifier.value = false;
    }
    return false;
  }

  final ready = await _localBridgeReady();
  if (!ready) {
    throw StateError(
      'Локальный Stockfish недоступен. Запустите локальный модуль и '
      'разрешите Chrome доступ к локальной сети.',
    );
  }

  if (!localStockfishEnabledNotifier.value) {
    localStockfishEnabledNotifier.value = true;
  }
  return true;
}

Future<bool> toggleLocalStockfish() =>
    setLocalStockfishEnabled(!isLocalStockfishEnabled);

Future<Map<String, dynamic>> _getLocalAnalysisRaw(
  String fen, {
  required int depth,
  required int multiPv,
  required int maxThinkingTime,
  required List<String> searchMoves,
}) async {
  // IMPORTANT: local Stockfish receives the exact FEN supplied by the site.
  // Side to move, castling rights, en-passant and move counters are preserved.
  final cleanFen = fen.trim();
  if (cleanFen.isEmpty) {
    throw ArgumentError.value(fen, 'fen', 'FEN не должен быть пустым');
  }

  final params = <String, String>{
    'fen': cleanFen,
    'depth': depth.toString(),
    'variants': multiPv.toString(),
    'maxThinkingTime': maxThinkingTime.toString(),
  };
  if (searchMoves.isNotEmpty) {
    params['searchmoves'] = searchMoves.join(' ');
  }

  final uri = Uri.http(_localHost, '/analyze', params);
  final timeoutMs = (maxThinkingTime.clamp(250, 120000) + 15000).toInt();
  final response = await http
      .get(uri)
      .timeout(Duration(milliseconds: timeoutMs));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      'Local Stockfish HTTP ${response.statusCode}: ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw StateError('Local Stockfish returned invalid JSON.');
}

Future<Map<String, dynamic>> getAnalysisRaw(
  String fen, {
  int depth = 20,
  int multiPv = 4,
  int maxThinkingTime = 2500,
  List<String> searchMoves = const <String>[],
}) {
  if (isLocalStockfishEnabled) {
    return _getLocalAnalysisRaw(
      fen,
      depth: depth,
      multiPv: multiPv,
      maxThinkingTime: maxThinkingTime,
      searchMoves: searchMoves,
    );
  }
  return network.getAnalysisRaw(
    fen,
    depth: depth,
    multiPv: multiPv,
    maxThinkingTime: maxThinkingTime,
    searchMoves: searchMoves,
  );
}

Future<String> getAnalysisText(
  String fen, {
  int depth = 18,
  int multiPv = 3,
}) async {
  if (!isLocalStockfishEnabled) {
    return network.getAnalysisText(fen, depth: depth, multiPv: multiPv);
  }
  final raw = await getAnalysisRaw(
    fen,
    depth: depth,
    multiPv: multiPv,
    maxThinkingTime: 3000,
  );
  final text = raw['text'];
  if (text is String && text.trim().isNotEmpty) return text;
  return const JsonEncoder.withIndent('  ').convert(raw);
}

Future<String> getBestMoveUci(
  String fen, {
  int depth = 16,
  int maxThinkingTime = 1500,
}) async {
  if (!isLocalStockfishEnabled) {
    return network.getBestMoveUci(
      fen,
      depth: depth,
      maxThinkingTime: maxThinkingTime,
    );
  }

  final raw = await getAnalysisRaw(
    fen,
    depth: depth,
    multiPv: 1,
    maxThinkingTime: maxThinkingTime,
  );
  for (final key in const <String>['move', 'uci', 'bestMove', 'best_move']) {
    final value = raw[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  throw StateError('Local Stockfish did not return a best move.');
}
