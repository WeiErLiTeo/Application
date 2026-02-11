import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncProvider);
    final notifier = ref.read(syncProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Connection Status",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      state.isConnected ? Icons.check_circle : Icons.wifi_off,
                      color: state.isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(state.isConnected 
                      ? "Connected to ${state.peerIp ?? 'peer'}" 
                      : "Not connected to peer"),
                  ],
                ),
                if (state.isServerRunning) ...[
                  const SizedBox(height: 8),
                  Text("Server running on: ${state.myIp}:8080"),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text("Run as Server (Android Host)"),
          subtitle: const Text("Allow other devices to connect to this device"),
          value: state.isServerRunning,
          onChanged: (val) => notifier.toggleServer(val),
        ),
        const SizedBox(height: 16),
        const Text("Connect to Peer (Web Client)"),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Peer IP Address",
            hintText: "192.168.x.x",
            prefixIcon: Icon(Icons.computer),
          ),
          onSubmitted: (val) => notifier.connectToServer(val),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            // Logic to scan QR code? Placeholder for now.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("QR Scan not implemented yet"))
            );
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text("Scan QR Code"),
        ),
      ],
    );
  }
}
