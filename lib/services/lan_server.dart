// lib/services/lan_server.dart
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';

class LanServer {
  HttpServer? _server;
  final List<WebSocketChannel> _sockets = [];
  final Function(String) onClipboardReceived;
  final Function(String)? onFileReceived;
  String _currentIp = "127.0.0.1";

  LanServer({required this.onClipboardReceived, this.onFileReceived});

  Future<String> start() async {
    final router = Router();

    // 1. WebSocket 路由
    router.get('/ws', webSocketHandler((webSocket) {
      _sockets.add(webSocket);
      webSocket.stream.listen((message) {
        onClipboardReceived(message.toString());
        _broadcast(message, exclude: webSocket);
      }, onDone: () {
        _sockets.remove(webSocket);
      }, onError: (e) {
        _sockets.remove(webSocket);
      });
    }));

    // 2. HTTP 测试接口
    router.get('/', (Request request) => Response.ok('Server Active'));

    // 3. 文件上传接口 (Web -> Android)
    router.post('/upload', (Request request) async {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.startsWith('multipart/form-data')) {
        return Response.badRequest(body: 'Expected multipart/form-data');
      }

      // Simple boundary extraction
      final boundaryMatch = RegExp(r'boundary=([^;]+)').firstMatch(contentType);
      if (boundaryMatch == null) {
        return Response.badRequest(body: 'Missing boundary');
      }
      final boundary = boundaryMatch.group(1)!.replaceAll('"', '');

      try {
        final transformer = MimeMultipartTransformer(boundary);
        final parts = request.read().transform(transformer);

        await for (final part in parts) {
          final contentDisposition = part.headers['content-disposition'];
          if (contentDisposition != null && contentDisposition.contains('filename=')) {
             // 提取文件名
             final filenameMatch = RegExp(r'filename="?([^"]+)"?').firstMatch(contentDisposition);
             String filename = filenameMatch?.group(1) ?? 'uploaded_file_${DateTime.now().millisecondsSinceEpoch}';
             filename = p.basename(filename); // Prevent path traversal

             // 确定保存路径
             Directory? saveDir;
             try {
               // First try standard downloads directory for all platforms
               saveDir = await getDownloadsDirectory(); 
               
               // Android fallback if getDownloadsDirectory returns null or unusable
               if (Platform.isAndroid && (saveDir == null || !await saveDir.exists())) {
                  saveDir = Directory('/storage/emulated/0/Download');
               }
             } catch (e) {
               print("获取下载目录失败: $e");
             }
             
             if (saveDir == null || !await saveDir.exists()) {
                saveDir = await getApplicationDocumentsDirectory();
             }

             final filePath = p.join(saveDir.path, filename);
             final file = File(filePath);
             
             // 写入文件
             final ios = file.openWrite();
             await ios.addStream(part);
             await ios.close();
             
             print("文件已保存: $filePath");
             onFileReceived?.call(filename);
             return Response.ok('File saved to $filePath');
          }
        }
        return Response.ok('No file processed');
      } catch (e) {
        print("Upload Error: $e");
        return Response.internalServerError(body: 'Upload failed: $e');
      }
    });

    // 4. 文件下载接口 (Android -> Web)
    router.get('/files/<name>', (Request request, String name) async {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, 'served_files', name));
      
      if (await file.exists()) {
        final mimeType = lookupMimeType(name) ?? 'application/octet-stream';
        return Response.ok(file.openRead(), headers: {'Content-Type': mimeType});
      } else {
        return Response.notFound('File not found');
      }
    });

    final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    
    // 启动服务 (依然绑定 0.0.0.0 以确保所有网卡都通)
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
    
    // 【关键修改】这里不再返回 0.0.0.0，而是去查真实的局域网 IP
    _currentIp = await _getWifiIp();
    return _currentIp;
  }

  // 【新增】获取本机真实局域网 IP 的辅助方法
  Future<String> _getWifiIp() async {
    try {
      // 获取所有网络接口
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, 
        includeLinkLocal: false
      );
      
      for (var interface in interfaces) {
        // 过滤掉虚拟机的网桥、Docker等干扰项，通常 WLAN 名字叫 wlan0, en0, eth0 等
        // 如果是模拟器，通常是 eth0
        for (var addr in interface.addresses) {
          // 排除掉 127.0.0.1
          if (!addr.isLoopback) {
            return addr.address; // 返回找到的第一个真实 IP
          }
        }
      }
    } catch (e) {
      print("获取IP失败: $e");
    }
    // 如果实在找不到，只能返回 localhost
    return '127.0.0.1';
  }

  Future<void> serveFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final appDir = await getApplicationDocumentsDirectory();
    final servedDir = Directory(p.join(appDir.path, 'served_files'));
    if (!await servedDir.exists()) {
      await servedDir.create(recursive: true);
    }
    
    final filename = p.basename(filePath);
    final targetFile = File(p.join(servedDir.path, filename));
    await file.copy(targetFile.path);

    final url = 'http://$_currentIp:8080/files/${Uri.encodeComponent(filename)}';
    _broadcast("FILE_URL:$url");
  }

  void broadcastClipboard(String text) {
    _broadcast(text);
  }

  void _broadcast(String message, {WebSocketChannel? exclude}) {
    for (var socket in _sockets) {
      if (socket == exclude) continue;
      try {
        socket.sink.add(message);
      } catch (e) {}
    }
  }

  void stop() {
    _server?.close();
  }
}
