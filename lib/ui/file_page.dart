import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sync_provider.dart';

class FilePage extends ConsumerWidget {
  const FilePage({super.key});

  Future<void> _pickAndSendFile(WidgetRef ref, BuildContext context) async {
    final state = ref.read(syncProvider);
    final notifier = ref.read(syncProvider.notifier);

    // Basic validation
    if (kIsWeb && !state.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connect to Android device first")),
      );
      return;
    }

    try {
      // On Web, we need to load file data into memory (bytes) because path is unavailable.
      // On Mobile/Desktop, we can use the path (withData: false avoids loading huge files into RAM).
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        withData: kIsWeb, 
      );
      
      if (!context.mounted) return;

      if (result != null) {
        final file = result.files.single;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Processing ${file.name}...")),
        );

        // Safe access to path (only on non-web)
        String? filePath;
        if (!kIsWeb) {
          filePath = file.path;
        }

        await notifier.sendFile(
          file.bytes,
          filePath,
          file.name,
          state.peerIp ?? '',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File pick failed: $e")),
      );
    }
  }

  Future<void> _openFileUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch $url")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncProvider);
    
    // Filter file entries
    final fileHistory = state.history.where((e) => e.isFile).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _pickAndSendFile(ref, context),
              icon: const Icon(Icons.upload_file),
              label: const Text("Select & Send File"),
            ),
          ),
        ),
        Expanded(
          child: fileHistory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No file history", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: fileHistory.length,
                  itemBuilder: (context, index) {
                    final entry = fileHistory[index];
                    final isUrl = entry.content.startsWith("FILE_URL:");
                    final fileName = isUrl 
                        ? entry.content.split('/').last 
                        : entry.content.replaceFirst("Sent file: ", "").replaceFirst("Shared file: ", "");

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUrl ? Theme.of(context).colorScheme.primaryContainer : null,
                          child: Icon(isUrl ? Icons.download : Icons.upload),
                        ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.timestamp.toString().split('.')[0],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: isUrl
                            ? IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => _openFileUrl(entry.content.substring(9), context),
                                tooltip: "Download File",
                              )
                            : const Icon(Icons.check, color: Colors.green),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
