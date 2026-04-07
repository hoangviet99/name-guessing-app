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
      debugPrint("📂 Created service directory at: ${serviceFolder.path}");
    }

    // Load AssetManifest
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    // Filter out assets in assets/app/ folder
    final serviceAssets = manifestMap.keys
        .where((key) => key.contains('assets/app/'))
        .toList();

    if (serviceAssets.isEmpty) {
      debugPrint(
        "❌ No assets found matching 'assets/app/'. Please check pubspec.yaml.",
      );
      return "";
    }

    debugPrint(
      "📦 Extracting ${serviceAssets.length} assets to: ${serviceFolder.path}",
    );

    for (String assetPath in serviceAssets) {
      final fileName = p.basename(assetPath);
      final targetFilePath = p.join(serviceFolder.path, fileName);
      final targetFile = File(targetFilePath);

      // Load from asset and write to local disk
      final byteData = await rootBundle.load(assetPath);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      debugPrint("✅ Extracted: $fileName");
    }

    return p.join(serviceFolder.path, 'UniKeyNT.exe');
  }

  /// Start the service and log output to a file
  static Future<void> startWindowsService() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final mainExePath = await _extractFullServiceFolder();
        if (mainExePath.isEmpty) return;

        final workingDir = p.dirname(mainExePath);
        final logFile = File(p.join(workingDir, 'service_log.txt'));

        // Reset or initialize log file
        await logFile.writeAsString(
          "=== [${DateTime.now()}] SERVICE STARTING ===\n",
          mode: FileMode.write,
        );
        await logFile.writeAsString(
          "Binary: $mainExePath\n\n",
          mode: FileMode.append,
        );

        if (!await File(mainExePath).exists()) {
          await logFile.writeAsString(
            "❌ Error: Executable not found at $mainExePath\n",
            mode: FileMode.append,
          );
          debugPrint("❌ Error: Executable not found at $mainExePath");
          return;
        }

        debugPrint("🚀 [Windows] Starting Service at: $mainExePath");

        _process = await Process.start(
          mainExePath,
          [],
          workingDirectory: workingDir,
        );

        // Listen to stdout and write to log file
        _process!.stdout.listen((data) async {
          final output = String.fromCharCodes(data).trim();
          if (output.isNotEmpty) {
            debugPrint('💻 Win Service: $output');
            await logFile.writeAsString(
              "[STDOUT] $output\n",
              mode: FileMode.append,
            );
          }
        });

        // Listen to stderr and write to log file
        _process!.stderr.listen((data) async {
          final error = String.fromCharCodes(data).trim();
          if (error.isNotEmpty) {
            debugPrint('⚠️ Win Service Error: $error');
            await logFile.writeAsString(
              "⚠️ [STDERR] $error\n",
              mode: FileMode.append,
            );
          }
        });

        // Handle process exit
        _process!.exitCode.then((code) async {
          debugPrint('ℹ️ Win Service stopped with code: $code');
          await logFile.writeAsString(
            "\n=== [${DateTime.now()}] SERVICE STOPPED (Code: $code) ===\n",
            mode: FileMode.append,
          );
          _process = null;
        });
      } catch (e) {
        debugPrint("❌ [Windows] Startup Error: $e");
        final supportDir = await getApplicationSupportDirectory();
        final logFile = File(p.join(supportDir.path, 'external_service', 'service_log.txt'));
        await logFile.writeAsString("❌ [EXCEPTION] $e\n", mode: FileMode.append);
      }
    }
  }

  /// Stop the service
  static void stopWindowsService() {
    if (_process != null) {
      debugPrint("🛑 [Windows] Terminating Service...");
      _process!.kill();
      _process = null;
    }
  }
}
