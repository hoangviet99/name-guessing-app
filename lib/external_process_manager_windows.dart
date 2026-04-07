import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ExternalProcessManagerWindows {
  static Process? _process;

  /// Extract the entire assets/app/ folder (including DLLs, configs, etc.)
  /// to the application support directory on the user's machine.
  static Future<String> _extractFullServiceFolder() async {
    final supportDir = await getApplicationSupportDirectory();
    final serviceFolder = Directory(
      p.join(supportDir.path, 'external_service'),
    );

    // Create target folder if it doesn't exist
    if (!await serviceFolder.exists()) {
      await serviceFolder.create(recursive: true);
    }

    // Use AssetManifest to list all files in assets/app/
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final serviceAssets = manifestMap.keys.where(
      (key) => key.startsWith('assets/app/'),
    );

    for (String assetPath in serviceAssets) {
      // Calculate destination path relative to assets/app folder
      final relativePath = p.relative(assetPath, from: 'assets/app');
      final targetFilePath = p.join(serviceFolder.path, relativePath);
      final targetFile = File(targetFilePath);

      // Important: Ensure subfolders are created if they exist in the assets
      await targetFile.parent.create(recursive: true);

      // Load from asset and write to local disk
      final byteData = await rootBundle.load(assetPath);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    // Name of the main executable file inside assets/app/
    // Change this to match your actual EXE name (e.g., 'my_api.exe')
    return p.join(serviceFolder.path, 'rufus-4.13.exe');
  }

  /// Start the service on Windows
  static Future<void> startWindowsService() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final mainExePath = await _extractFullServiceFolder();
        final workingDir = p.dirname(mainExePath);

        debugPrint(
          "🚀 [Windows] Starting Full Service Bundle at: $mainExePath",
        );

        // Start the process using the extracted EXE and folder context
        _process = await Process.start(
          mainExePath,
          [],
          workingDirectory: workingDir,
        );

        _process!.stdout.listen(
          (data) =>
              debugPrint('✅ Win Service: ${String.fromCharCodes(data).trim()}'),
        );
        _process!.stderr.listen(
          (data) => debugPrint(
            '❌ Win Service Error: ${String.fromCharCodes(data).trim()}',
          ),
        );
        _process!.exitCode.then(
          (code) => debugPrint('ℹ️ Win Service stopped with code: $code'),
        );
      } catch (e) {
        debugPrint("❌ [Windows] Critical Startup Error: $e");
      }
    }
  }

  /// Stop the service and cleanup
  static void stopWindowsService() {
    if (_process != null) {
      debugPrint("🛑 [Windows] Terminating Service...");
      _process!.kill();
      _process = null;
    }
  }
}
