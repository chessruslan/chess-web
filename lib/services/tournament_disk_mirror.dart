import 'tournament_disk_mirror_stub.dart'
    if (dart.library.io) 'tournament_disk_mirror_io.dart' as impl;

class TournamentDiskMirror {
  TournamentDiskMirror._();

  static Future<String?> read(String key) => impl.read(key);

  static Future<void> write(String key, String value) => impl.write(key, value);

  static Future<String?> folderPath() => impl.folderPath();
}
