import 'dart:io';
import 'dart:typed_data';

class PlatformFileReader {
  static Future<Uint8List?> readAsBytes(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
