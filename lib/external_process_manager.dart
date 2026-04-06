import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ExternalProcessManager {
  static Process? _process;

  /// Giải nén script từ assets ra thư mục làm việc của máy
  static Future<String> _extractScript() async {
    final supportDir = await getApplicationSupportDirectory();
    final scriptFile = File(p.join(supportDir.path, 'mock-api-service.sh'));

    // Ghi đè file nếu cần (hoặc chỉ ghi nếu chưa có)
    final byteData = await rootBundle.load('assets/scripts/mock-api-service.sh');
    await scriptFile.writeAsBytes(byteData.buffer.asUint8List());
    
    // Cấp quyền thực thi (chmod +x) cho file vừa chép ra
    await Process.run('chmod', ['+x', scriptFile.path]);
    
    return scriptFile.path;
  }

  /// Khởi động script mock API linh hoạt theo từng máy
  static Future<void> startMockApi() async {
    if (!kIsWeb && Platform.isLinux) {
      try {
        // 1. Tự động lấy file từ Assets ra đĩa
        final dynamicPath = await _extractScript();
        final workingDir = p.dirname(dynamicPath);

        debugPrint("🚀 Đang khởi động Mock API Service tại: $dynamicPath");
        
        // 2. Chạy từ bộ nhớ máy tính
        _process = await Process.start(
          'bash', 
          [dynamicPath],
          workingDirectory: workingDir,
        );

        // 3. Lắng nghe log lỗi/kết quả
        _process!.stdout.listen((data) => debugPrint('✅ Mock API: ${String.fromCharCodes(data).trim()}'));
        _process!.stderr.listen((data) => debugPrint('❌ Mock API Error: ${String.fromCharCodes(data).trim()}'));
        _process!.exitCode.then((code) => debugPrint('ℹ️ Mock API dừng với mã: $code'));

      } catch (e) {
        debugPrint("❌ Lỗi tự động trích xuất hoặc khởi động Mock API: $e");
      }
    }
  }

  /// Tắt script khi đóng ứng dụng
  static void stopMockApi() {
    if (_process != null) {
      debugPrint("🛑 Đang dọn dẹp Mock API Service...");
      _process!.kill();
      _process = null;
    }
  }
}
