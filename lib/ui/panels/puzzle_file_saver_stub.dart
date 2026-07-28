Future<bool> canUsePuzzleFolderPicker() async => false;

Future<String?> getPuzzleFolderName() async => null;

Future<String?> choosePuzzleFolder() async => null;

Future<List<Map<String, String>>> loadPuzzleTextFileMapsFromFolder() async {
  return const [];
}

Future<void> publishPuzzleTextFile({
  required String fileName,
  required String content,
}) async {
  throw UnsupportedError('Выбор папки поддерживается только в Flutter Web.');
}

Future<void> savePuzzleTextFile({
  required String fileName,
  required String content,
}) async {
  throw UnsupportedError(
      'Скачивание файла поддерживается только в Flutter Web.');
}
