import 'puzzle_file_saver_stub.dart'
    if (dart.library.html) 'puzzle_file_saver_web.dart' as impl;

class PuzzleSavedFile {
  const PuzzleSavedFile({required this.name, required this.content});

  final String name;
  final String content;
}

Future<bool> canUsePuzzleFolderPicker() {
  return impl.canUsePuzzleFolderPicker();
}

Future<String?> getPuzzleFolderName() {
  return impl.getPuzzleFolderName();
}

Future<String?> choosePuzzleFolder() {
  return impl.choosePuzzleFolder();
}

Future<List<PuzzleSavedFile>> loadPuzzleTextFilesFromFolder() async {
  final maps = await impl.loadPuzzleTextFileMapsFromFolder();
  return maps
      .map(
        (item) => PuzzleSavedFile(
          name: '${item['name'] ?? ''}',
          content: '${item['content'] ?? ''}',
        ),
      )
      .where((file) => file.name.trim().isNotEmpty)
      .toList(growable: false);
}

Future<void> publishPuzzleTextFile({
  required String fileName,
  required String content,
}) {
  return impl.publishPuzzleTextFile(fileName: fileName, content: content);
}

Future<void> savePuzzleTextFile({
  required String fileName,
  required String content,
}) {
  return impl.savePuzzleTextFile(fileName: fileName, content: content);
}
