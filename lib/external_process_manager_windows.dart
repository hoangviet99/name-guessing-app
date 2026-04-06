import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ExternalProcessManagerWindows {
  static Process? _process;

  /// Giải nén file .exe hoặc script từ assets ra thư mục máy Windows
  static Future<String> _extractAsset() async {
    final supportDir = await getApplicationSupportDirectory();
    // Ở đây mình ví dụ tên file là service.exe, bạn hãy đổi tên theo nhu cầu thực tế nhé.
    final targetFile = File(p.join(supportDir.path, 'service.exe'));

    try {
      final byteData = await rootBundle.load('assets/scripts/service.exe');
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint("⚠️ Cảnh báo asset Windows: Không tìm thấy assets/scripts/service.exe");
    }
    
    return targetFile.path;
  }

  /// Khởi động service trên Windows
  static Future<void> startWindowsService() async {
    // Chỉ thực thi logic nếu đang chạy trên Windows
    if (!kIsWeb && Platform.isWindows) {
      try {
        final filePath = await _extractAsset();
        final workingDir = p.dirname(filePath);

        // Nếu bạn muốn mở file TEXT (.txt) trên Windows thì dùng lệnh này:
        // await Process.run('start', [filePath], runInShell: true);
        
        // Nếu là file EXE, chúng ta khởi động tiến trình ngầm:
        debugPrint("🚀 [Windows] Đang khởi động Service tại: $filePath");
        _process = await Process.start(
          filePath, 
          [],
          workingDirectory: workingDir,
        );

        _process!.stdout.listen((data) => debugPrint('✅ Win Log: ${String.fromCharCodes(data).trim()}'));
        _process!.stderr.listen((data) => debugPrint('❌ Win Error: ${String.fromCharCodes(data).trim()}'));

      } catch (e) {
        debugPrint("❌ [Windows] Lỗi khởi động: $e");
      }
    }
  }

  /// Tắt service khi đóng ứng dụng
  static void stopWindowsService() {
    if (_process != null) {
      debugPrint("🛑 [Windows] Đang đóng Service...");
      _process!.kill();
      _process = null;
    }
  }
}
