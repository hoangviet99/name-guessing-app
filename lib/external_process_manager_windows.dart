import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ExternalProcessManagerWindows {
  static Process? _process;

  /// Extract .exe or script from assets to Windows support directory
  static Future<String> _extractAsset() async {
    final supportDir = await getApplicationSupportDirectory();
    final targetFile = File(p.join(supportDir.path, 'rufus-4.13.exe'));

    try {
      final byteData = await rootBundle.load('assets/app/rufus-4.13.exe');
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint(
        "⚠️ Windows Asset Warning: Could not find assets/app/rufus-4.13.exe",
      );
    }

    return targetFile.path;
  }

  /// Start service on Windows
  static Future<void> startWindowsService() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final filePath = await _extractAsset();
        final workingDir = p.dirname(filePath);

        debugPrint("🚀 [Windows] Starting Service at: $filePath");
        _process = await Process.start(
          filePath,
          [],
          workingDirectory: workingDir,
        );

        _process!.stdout.listen((data) =>
            debugPrint('✅ Win Log: ${String.fromCharCodes(data).trim()}'));
        _process!.stderr.listen((data) =>
            debugPrint('❌ Win Error: ${String.fromCharCodes(data).trim()}'));
        _process!.exitCode.then(
            (code) => debugPrint('ℹ️ Win Service stopped with exit code: $code'));

      } catch (e) {
        debugPrint("❌ [Windows] Startup Error: $e");
      }
    }
  }

  /// Stop service when application closes
  static void stopWindowsService() {
    if (_process != null) {
      debugPrint("🛑 [Windows] Stopping Service...");
      _process!.kill();
      _process = null;
    }
  }
}
