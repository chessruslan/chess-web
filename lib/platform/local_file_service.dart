import 'dart:typed_data';

import 'local_file_service_stub.dart'
    if (dart.library.html) 'local_file_service_web.dart'
    if (dart.library.io) 'local_file_service_io.dart' as impl;

class LocalPickedFile {
  const LocalPickedFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

class LocalFileService {
  LocalFileService._();

  static Future<LocalPickedFile?> pickFile({
    List<String> extensions = const <String>[],
    String? initialDirectory,
  }) async {
    final result = await impl.pickFile(
      extensions: extensions,
      initialDirectory: initialDirectory,
    );
    if (result == null) return null;
    return LocalPickedFile(
      name: '${result['name'] ?? ''}',
      bytes: result['bytes'] as Uint8List,
      mimeType: '${result['mimeType'] ?? 'application/octet-stream'}',
    );
  }

  static Future<String?> pickTextFile({
    List<String> extensions = const <String>[],
    String? initialDirectory,
  }) =>
      impl.pickTextFile(
        extensions: extensions,
        initialDirectory: initialDirectory,
      );

  static Future<bool> saveText({
    required String suggestedName,
    required String text,
    String? initialDirectory,
  }) =>
      impl.saveText(
        suggestedName: suggestedName,
        text: text,
        initialDirectory: initialDirectory,
      );

  static Future<bool> saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    String? initialDirectory,
  }) =>
      impl.saveBytes(
        suggestedName: suggestedName,
        bytes: bytes,
        initialDirectory: initialDirectory,
      );

  static Future<bool> printText(
    String text, {
    String fileName = 'makechess_print.txt',
  }) =>
      impl.printText(text, fileName: fileName);

  static Future<bool> openFolder(String path) => impl.openFolder(path);
}
