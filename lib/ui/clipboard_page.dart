import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/sync_provider.dart';

class ClipboardPage extends ConsumerStatefulWidget {
  const ClipboardPage({super.key});

  @override
  ConsumerState<ClipboardPage> createState() => _ClipboardPageState();
}

class _ClipboardPageState extends ConsumerState<ClipboardPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Copy Failed'),
            content: SelectableText(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncProvider);
    final notifier = ref.read(syncProvider.notifier);

    // Filter only text entries
    final textHistory = state.history.where((e) => !e.isFile).toList();

    return Column(
      children: [
        Expanded(
          child: textHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.content_paste_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text("No clipboard history yet", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: textHistory.length,
                  itemBuilder: (context, index) {
                    final entry = textHistory[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.text_snippet)),
                        title: Text(
                          entry.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.timestamp.toString().split('.')[0],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyToClipboard(entry.content),
                          tooltip: 'Copy',
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Type message to send...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  notifier.sendText(_controller.text);
                  _controller.clear();
                },
              ),
            ),
            onSubmitted: (val) {
              notifier.sendText(val);
              _controller.clear();
            },
          ),
        ),
      ],
    );
  }
}
