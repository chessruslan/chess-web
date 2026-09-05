import 'dart:io';

import 'package:path_provider/path_provider.dart';

String _safeFileName(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

Future<Directory> _root() async {
  final documents = await getApplicationDocumentsDirectory();
  final dir = Directory(
    '${documents.path}${Platform.pathSeparator}MakeChess${Platform.pathSeparator}Tournaments',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String?> folderPath() async => (await _root()).path;

Future<String?> read(String key) async {
  try {
    final root = await _root();
    final file = File('${root.path}${Platform.pathSeparator}${_safeFileName(key)}.json');
    if (!await file.exists()) return null;
    return file.readAsString();
  } catch (_) {
    return null;
  }
}

Future<void> write(String key, String value) async {
  final root = await _root();
  final file = File('${root.path}${Platform.pathSeparator}${_safeFileName(key)}.json');
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(value, flush: true);
  if (await file.exists()) await file.delete();
  await temp.rename(file.path);
}
