import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const String _manifestUrl = 'https://makechess.com/desktop/update.json';

Future<void> checkAndInstallIfNeeded() async {
  if (!Platform.isWindows) return;

  final response = await http
      .get(Uri.parse(_manifestUrl), headers: const <String, String>{
        'Cache-Control': 'no-cache',
      })
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return;

  final decoded = jsonDecode(response.body);
  if (decoded is! Map) return;
  final manifest = Map<String, dynamic>.from(decoded);
  final windows = manifest['windows'];
  if (windows is! Map) return;

  final remoteVersion = '${manifest['version'] ?? ''}'.trim();
  final installerUrl = '${windows['url'] ?? ''}'.trim();
  final expectedSha256 = '${windows['sha256'] ?? ''}'.trim().toLowerCase();
  if (remoteVersion.isEmpty || installerUrl.isEmpty || expectedSha256.length != 64) {
    return;
  }

  final package = await PackageInfo.fromPlatform();
  if (!_isNewer(remoteVersion, package.version)) return;

  final request = http.Request('GET', Uri.parse(installerUrl));
  final streamed = await request.send().timeout(const Duration(seconds: 12));
  if (streamed.statusCode != 200) return;

  final tempDir = await getTemporaryDirectory();
  final installer = File(
    '${tempDir.path}${Platform.pathSeparator}MakeChessSetup-$remoteVersion.exe',
  );
  final sink = installer.openWrite();
  await streamed.stream.pipe(sink);

  final digest = sha256.convert(await installer.readAsBytes()).toString();
  if (digest.toLowerCase() != expectedSha256) {
    try {
      await installer.delete();
    } catch (_) {}
    return;
  }

  await Process.start(
    installer.path,
    const <String>[
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
      '/RESTARTAPPLICATIONS',
    ],
    mode: ProcessStartMode.detached,
    runInShell: true,
  );

  // Installer is running independently. Close this copy so files can be replaced.
  await Future<void>.delayed(const Duration(milliseconds: 700));
  exit(0);
}

bool _isNewer(String remote, String local) {
  final a = _versionParts(remote);
  final b = _versionParts(local);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av != bv) return av > bv;
  }
  return false;
}

List<int> _versionParts(String value) => value
    .split(RegExp(r'[.+-]'))
    .take(4)
    .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
    .toList(growable: false);
