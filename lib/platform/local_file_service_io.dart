import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

String _mimeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.json') || lower.endsWith('.mct')) {
    return 'application/json';
  }
  if (lower.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

Future<Map<String, Object>?> pickFile({
  required List<String> extensions,
  String? initialDirectory,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: extensions.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: extensions.isEmpty ? null : extensions,
    withData: true,
    initialDirectory: initialDirectory,
  );
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.single;
  Uint8List? bytes = picked.bytes;
  if (bytes == null && picked.path != null) {
    bytes = await File(picked.path!).readAsBytes();
  }
  if (bytes == null) return null;
  return <String, Object>{
    'name': picked.name,
    'bytes': bytes,
    'mimeType': _mimeForName(picked.name),
  };
}

Future<String?> pickTextFile({
  required List<String> extensions,
  String? initialDirectory,
}) async {
  final picked = await pickFile(
    extensions: extensions,
    initialDirectory: initialDirectory,
  );
  if (picked == null) return null;
  return utf8.decode(picked['bytes'] as Uint8List, allowMalformed: true);
}

Future<bool> saveText({
  required String suggestedName,
  required String text,
  String? initialDirectory,
}) =>
    saveBytes(
      suggestedName: suggestedName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      initialDirectory: initialDirectory,
    );

Future<bool> saveBytes({
  required String suggestedName,
  required Uint8List bytes,
  String? initialDirectory,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Сохранить файл MakeChess',
    fileName: suggestedName,
    initialDirectory: initialDirectory,
  );
  if (path == null || path.trim().isEmpty) return false;
  await File(path).writeAsBytes(bytes, flush: true);
  return true;
}

Future<bool> printText(String text, {required String fileName}) async {
  if (!Platform.isWindows) return false;
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$safeName');
  await file.writeAsString(text, flush: true);
  await Process.start(
    'notepad.exe',
    <String>['/p', file.path],
    mode: ProcessStartMode.detached,
  );
  return true;
}

Future<bool> openFolder(String path) async {
  if (!Platform.isWindows || path.trim().isEmpty) return false;
  await Process.start(
    'explorer.exe',
    <String>[path],
    mode: ProcessStartMode.detached,
  );
  return true;
}
