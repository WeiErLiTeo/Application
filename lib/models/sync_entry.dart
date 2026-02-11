// lib/models/sync_entry.dart
class SyncEntry {
  final String content;
  final bool isFile;
  final bool isSent;
  final DateTime timestamp;

  SyncEntry({
    required this.content,
    required this.isFile,
    required this.isSent,
    required this.timestamp,
  });

  String get fileName => content.startsWith("FILE_URL:") 
      ? content.split('/').last 
      : (isFile ? content : "");
}
