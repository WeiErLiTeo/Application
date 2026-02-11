import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/lan_server.dart';
import '../services/lan_client.dart';
import '../models/sync_entry.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

// State
class SyncState {
  final List<SyncEntry> history;
  final bool isServerRunning;
  final String myIp;
  final bool isConnected;
  final String? peerIp;
  final String? lastError;
  final String? lastInfo;

  SyncState({
    this.history = const [],
    this.isServerRunning = false,
    this.myIp = "Loading...",
    this.isConnected = false,
    this.peerIp,
    this.lastError,
    this.lastInfo,
  });

  SyncState copyWith({
    List<SyncEntry>? history,
    bool? isServerRunning,
    String? myIp,
    bool? isConnected,
    String? peerIp,
    String? lastError,
    String? lastInfo,
  }) {
    return SyncState(
      history: history ?? this.history,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      myIp: myIp ?? this.myIp,
      isConnected: isConnected ?? this.isConnected,
      peerIp: peerIp ?? this.peerIp,
      lastError: lastError, // Reset on update unless passed
      lastInfo: lastInfo,
    );
  }
}

// Notifier
class SyncNotifier extends StateNotifier<SyncState> {
  LanServer? _server;
  LanClient? _client;

  SyncNotifier() : super(SyncState()) {
    _initServices();
  }

  void _initServices() {
    void onDataReceived(String text) {
      _addHistory(text, isFile: text.startsWith("FILE_URL:"), isSent: false);
      state = state.copyWith(lastInfo: "Received content");
    }

    void onFileReceived(String filename) {
      _addHistory("✅ Received file: $filename", isFile: true, isSent: false);
      state = state.copyWith(lastInfo: "File saved: $filename");
    }

    if (!kIsWeb) {
      _server = LanServer(onClipboardReceived: onDataReceived, onFileReceived: onFileReceived);
    }
    _client = LanClient(onClipboardReceived: onDataReceived);
  }

  void _addHistory(String content, {required bool isFile, required bool isSent}) {
    final entry = SyncEntry(
      content: content,
      isFile: isFile,
      isSent: isSent,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(history: [entry, ...state.history]);
  }

  Future<void> toggleServer(bool value) async {
    if (kIsWeb) return;
    if (value) {
      if (Platform.isAndroid) {
        await [
          Permission.storage,
          Permission.manageExternalStorage,
        ].request();
      }
      try {
        String ip = await _server!.start();
        state = state.copyWith(isServerRunning: true, myIp: ip, lastInfo: "Server started at $ip:8080");
      } catch (e) {
        state = state.copyWith(isServerRunning: false, lastError: "Start failed: $e");
      }
    } else {
      _server!.stop();
      state = state.copyWith(isServerRunning: false, lastInfo: "Server stopped");
    }
  }

  void connectToServer(String ip) {
    if (ip.isEmpty) {
      state = state.copyWith(lastError: "Please enter IP address");
      return;
    }
    try {
      _client!.connect(ip);
      state = state.copyWith(isConnected: true, peerIp: ip, lastInfo: "Connected to $ip");
    } catch (e) {
      state = state.copyWith(lastError: "Connection error: $e");
    }
  }

  void sendText(String text) {
    if (text.isEmpty) return;
    if (kIsWeb) {
      if (!state.isConnected) {
        state = state.copyWith(lastError: "Connect to Android device first");
        return;
      }
      _client?.sendClipboard(text);
    } else {
      if (!state.isServerRunning) {
        state = state.copyWith(lastError: "Start sync server first");
        return;
      }
      _server?.broadcastClipboard(text);
    }
    _addHistory(text, isFile: false, isSent: true);
  }

  Future<void> sendFile(List<int>? bytes, String? path, String name, String targetIp) async {
    try {
      if (kIsWeb) {
        if (!state.isConnected) {
          state = state.copyWith(lastError: "Connect to Android device first");
          return;
        }
        if (bytes != null) {
          await _client?.uploadFile(bytes, name, targetIp);
          _addHistory("Sent file: $name", isFile: true, isSent: true);
          state = state.copyWith(lastInfo: "File sent successfully");
        }
      } else {
        if (path != null) {
          await _server?.serveFile(path);
          _addHistory("Shared file: $name", isFile: true, isSent: true);
          state = state.copyWith(lastInfo: "File shared via URL");
        }
      }
    } catch (e) {
      state = state.copyWith(lastError: "File send failed: $e");
    }
  }
  
  void clearError() {
    state = state.copyWith(lastError: null); 
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) => SyncNotifier());
