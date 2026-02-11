// lib/services/lan_client.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class LanClient {
  WebSocketChannel? _channel;
  final Function(String) onClipboardReceived;

  LanClient({required this.onClipboardReceived});

  // 连接到 Android 服务器
  void connect(String ipAddress) {
    // 这里要注意：如果 ipAddress 只是纯 IP (如 192.168.1.5)，需要拼上 ws:// 和端口
    // 如果用户输入带了 ws:// 则不处理，这里默认假设用户只输入 IP
    final uri = Uri.parse('ws://$ipAddress:8080/ws');
    
    try {
      _channel = WebSocketChannel.connect(uri);
      print("正在尝试连接: $uri");

      _channel!.stream.listen(
        (message) {
          onClipboardReceived(message.toString());
        },
        onError: (error) {
          print('Web端连接错误: $error');
          // 这里可以抛出异常让 UI 捕获
        },
        onDone: () {
          print('Web端连接断开');
        },
      );
    } catch (e) {
      print("连接初始化失败: $e");
      rethrow;
    }
  }

  // 发送剪贴板内容给 Android
  void sendClipboard(String text) {
    if (_channel != null) {
      _channel!.sink.add(text);
    } else {
      print("错误：尚未连接到服务器");
    }
  }

  // 发送文件 (预留接口)
  Future<void> uploadFile(List<int> bytes, String filename, String ip) async {
    final uri = Uri.parse('http://$ip:8080/upload');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    await request.send();
  }

  void disconnect() {
    _channel?.sink.close();
  }
}