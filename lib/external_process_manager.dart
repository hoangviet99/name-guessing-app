import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ExternalProcessManager {
  static Process? _process;

  /// Extract script from assets to the machine's support directory
  static Future<String> _extractScript() async {
    final supportDir = await getApplicationSupportDirectory();
    final scriptFile = File(p.join(supportDir.path, 'mock-api-service.sh'));

    // Load and write the script file from assets
    final byteData = await rootBundle.load('assets/scripts/mock-api-service.sh');
    await scriptFile.writeAsBytes(byteData.buffer.asUint8List());
    
    // Grant execute permissions (chmod +x)
    await Process.run('chmod', ['+x', scriptFile.path]);
    
    return scriptFile.path;
  }

  /// Start mock API script dynamically based on platform
  static Future<void> startMockApi() async {
    if (!kIsWeb && Platform.isLinux) {
      try {
        // 1. Automatically extract file from assets to disk
        final dynamicPath = await _extractScript();
        final workingDir = p.dirname(dynamicPath);

        debugPrint("🚀 Starting Mock API Service at: $dynamicPath");
        
        // 2. Start process from disk
        _process = await Process.start(
          'bash', 
          [dynamicPath],
          workingDirectory: workingDir,
        );

        // 3. Listen to logs and exit events
        _process!.stdout.listen((data) => debugPrint('✅ Mock API: ${String.fromCharCodes(data).trim()}'));
        _process!.stderr.listen((data) => debugPrint('❌ Mock API Error: ${String.fromCharCodes(data).trim()}'));
        _process!.exitCode.then((code) => debugPrint('ℹ️ Mock API stopped with exit code: $code'));

      } catch (e) {
        debugPrint("❌ Error extracting or starting Mock API: $e");
      }
    }
  }

  /// Stop script when application closes
  static void stopMockApi() {
    if (_process != null) {
      debugPrint("🛑 Stopping Mock API Service...");
      _process!.kill();
      _process = null;
    }
  }
}
