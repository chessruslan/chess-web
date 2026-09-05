import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

String _accept(List<String> extensions) => extensions
    .map((value) => value.startsWith('.') ? value : '.$value')
    .join(',');

Future<Map<String, Object>?> pickFile({
  required List<String> extensions,
  String? initialDirectory,
}) async {
  final input = html.FileUploadInputElement();
  if (extensions.isNotEmpty) input.accept = _accept(extensions);
  input.click();
  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is! ByteBuffer) return null;
  return <String, Object>{
    'name': file.name,
    'bytes': Uint8List.view(result),
    'mimeType': file.type.isEmpty ? 'application/octet-stream' : file.type,
  };
}

Future<String?> pickTextFile({
  required List<String> extensions,
  String? initialDirectory,
}) async {
  final input = html.FileUploadInputElement();
  if (extensions.isNotEmpty) input.accept = _accept(extensions);
  input.click();
  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;
  final reader = html.FileReader();
  reader.readAsText(file);
  await reader.onLoad.first;
  return '${reader.result ?? ''}';
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
  final blob = html.Blob(<Object>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = suggestedName
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<bool> printText(String text, {required String fileName}) async {
  html.window.print();
  return true;
}

Future<bool> openFolder(String path) async => false;
