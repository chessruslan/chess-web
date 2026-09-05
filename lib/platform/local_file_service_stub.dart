import 'dart:typed_data';

Future<Map<String, Object>?> pickFile({
  required List<String> extensions,
  String? initialDirectory,
}) async =>
    null;

Future<String?> pickTextFile({
  required List<String> extensions,
  String? initialDirectory,
}) async =>
    null;

Future<bool> saveText({
  required String suggestedName,
  required String text,
  String? initialDirectory,
}) async =>
    false;

Future<bool> saveBytes({
  required String suggestedName,
  required Uint8List bytes,
  String? initialDirectory,
}) async =>
    false;

Future<bool> printText(String text, {required String fileName}) async => false;

Future<bool> openFolder(String path) async => false;
