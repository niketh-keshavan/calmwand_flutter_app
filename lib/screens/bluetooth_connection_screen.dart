import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../utils/app_theme.dart';

/// Bluetooth device connection screen
/// Ported from BluetoothConnectionView.swift
class BluetoothConnectionScreen extends StatelessWidget {
  const BluetoothConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bluetoothService = context.watch<BluetoothService>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.bluetooth, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bluetooth Devices',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bluetoothService.statusMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!bluetoothService.isConnected)
                  IconButton(
                    onPressed: () {
                      bluetoothService.startScan();
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Device list
          Expanded(
            child: bluetoothService.isScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Scanning for devices...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : bluetoothService.devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No devices found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                bluetoothService.startScan();
                              },
                              child: const Text('Tap to scan'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: bluetoothService.devices.length,
                        itemBuilder: (context, index) {
                          final device = bluetoothService.devices[index];
                          final isConnected = bluetoothService
                                  .connectedDevice?.remoteId ==
                              device.remoteId;

                          return ListTile(
                            leading: Icon(
                              isConnected
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth,
                              color: isConnected
                                  ? Colors.green
                                  : Colors.blue.shade700,
                            ),
                            title: Text(
                              device.platformName.isEmpty
                                  ? 'Unknown Device'
                                  : device.platformName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              device.remoteId.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: isConnected
                                ? ElevatedButton(
                                    onPressed: () {
                                      bluetoothService.disconnect();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade100,
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                    child: const Text('Disconnect'),
                                  )
                                : ElevatedButton(
                                    onPressed: bluetoothService.isConnecting
                                        ? null
                                        : () {
                                            bluetoothService.connect(device);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: bluetoothService.isConnecting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Connect'),
                                  ),
                          );
                        },
                      ),
          ),

          // Close button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
