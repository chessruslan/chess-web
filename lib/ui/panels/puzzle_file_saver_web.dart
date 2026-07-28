import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool _installed = false;

void _installHelpers() {
  if (_installed) return;
  _installed = true;

  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..text = r'''
(function () {
  if (window.mcPuzzleFsReady) return;
  window.mcPuzzleFsReady = true;
  window.mcPuzzleDir = null;

  window.mcPuzzleCanUseFolder = function () {
    return typeof window.showDirectoryPicker === 'function';
  };

  window.mcPuzzlePickFolder = async function () {
    if (!window.mcPuzzleCanUseFolder()) {
      throw new Error('Ваш браузер не поддерживает выбор папки для прямого сохранения. Используйте Chrome или Edge.');
    }
    window.mcPuzzleDir = await window.showDirectoryPicker({ mode: 'readwrite' });
    return window.mcPuzzleDir.name || 'Папка выбрана';
  };

  window.mcPuzzleFolderName = function () {
    return window.mcPuzzleDir ? (window.mcPuzzleDir.name || 'Папка выбрана') : '';
  };

  window.mcPuzzleSaveFile = async function (fileName, content) {
    if (!window.mcPuzzleDir) {
      await window.mcPuzzlePickFolder();
    }
    const handle = await window.mcPuzzleDir.getFileHandle(fileName, { create: true });
    const writable = await handle.createWritable();
    await writable.write(content);
    await writable.close();
    return true;
  };

  window.mcPuzzleReadFiles = async function () {
    if (!window.mcPuzzleDir) return '[]';
    const result = [];
    for await (const [name, handle] of window.mcPuzzleDir.entries()) {
      if (handle.kind !== 'file') continue;
      if (!name.toLowerCase().endsWith('.json')) continue;
      const file = await handle.getFile();
      const text = await file.text();
      result.push({ name, content: text });
    }
    result.sort((a, b) => a.name.localeCompare(b.name, 'ru'));
    return JSON.stringify(result);
  };
})();
''';
  html.document.head?.append(script);
}

Future<bool> canUsePuzzleFolderPicker() async {
  _installHelpers();
  return js_util.callMethod(html.window, 'mcPuzzleCanUseFolder', []) == true;
}

Future<String?> getPuzzleFolderName() async {
  _installHelpers();
  final value = js_util.callMethod(html.window, 'mcPuzzleFolderName', []);
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

Future<String?> choosePuzzleFolder() async {
  _installHelpers();
  final result = await js_util.promiseToFuture<dynamic>(
    js_util.callMethod(html.window, 'mcPuzzlePickFolder', []),
  );
  return '$result';
}

Future<List<Map<String, String>>> loadPuzzleTextFileMapsFromFolder() async {
  _installHelpers();
  final raw = await js_util.promiseToFuture<dynamic>(
    js_util.callMethod(html.window, 'mcPuzzleReadFiles', []),
  );
  final decoded = jsonDecode('$raw');
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map(
        (item) => <String, String>{
          'name': '${item['name'] ?? ''}',
          'content': '${item['content'] ?? ''}',
        },
      )
      .where((file) => file['name']!.trim().isNotEmpty)
      .toList(growable: false);
}

Future<void> publishPuzzleTextFile({
  required String fileName,
  required String content,
}) async {
  _installHelpers();
  await js_util.promiseToFuture<dynamic>(
    js_util.callMethod(html.window, 'mcPuzzleSaveFile', [fileName, content]),
  );
}

Future<void> savePuzzleTextFile({
  required String fileName,
  required String content,
}) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);
}
