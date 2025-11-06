import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../providers/session_provider.dart';
import '../utils/app_theme.dart';

/// Arduino SD card file import screen
/// Ported from ArduinoFileListView.swift
class ArduinoFileImportScreen extends StatefulWidget {
  const ArduinoFileImportScreen({super.key});

  @override
  State<ArduinoFileImportScreen> createState() => _ArduinoFileImportScreenState();
}

class _ArduinoFileImportScreenState extends State<ArduinoFileImportScreen> {
  bool _isImporting = false;
  String? _currentImportFile;
  String _importStatus = '';

  @override
  void initState() {
    super.initState();
    // Request file list on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      if (bluetoothService.isConnected) {
        bluetoothService.requestArduinoFileList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothService = context.watch<BluetoothService>();
    final fileList = bluetoothService.arduinoFileList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Arduino'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (fileList.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete_all') {
                  _confirmDeleteAll(bluetoothService);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete All Files'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // Status card
            if (!bluetoothService.isConnected)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Not connected to device. Please connect first.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // Import status card
            if (_isImporting)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _importStatus,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _cancelImport(bluetoothService),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),

            // Refresh button
            if (bluetoothService.isConnected && !_isImporting)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => bluetoothService.requestArduinoFileList(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh File List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            // File list
            Expanded(
              child: fileList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            bluetoothService.isConnected
                                ? 'No files on Arduino SD card'
                                : 'Connect to device to view files',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: fileList.length,
                      itemBuilder: (context, index) {
                        final fileName = fileList[index];
                        final isCurrentlyImporting = _currentImportFile == fileName;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [AppTheme.cardShadow],
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(
                                Icons.insert_drive_file,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            title: Text(
                              fileName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: const Text('Tap to import'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrentlyImporting)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                if (!isCurrentlyImporting)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDeleteFile(bluetoothService, fileName),
                                  ),
                              ],
                            ),
                            onTap: _isImporting
                                ? null
                                : () => _importFile(bluetoothService, fileName),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Import file from Arduino
  Future<void> _importFile(BluetoothService bluetoothService, String fileName) async {
    setState(() {
      _isImporting = true;
      _currentImportFile = fileName;
      _importStatus = 'Requesting file: $fileName';
    });

    try {
      // Request file from Arduino
      await bluetoothService.requestArduinoFile(fileName);

      // Wait for transfer to complete
      setState(() {
        _importStatus = 'Downloading file data...';
      });

      // Poll for completion (check every 500ms for up to 30 seconds)
      int attempts = 0;
      while (!bluetoothService.fileContentTransferCompleted && attempts < 60) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (!bluetoothService.fileContentTransferCompleted) {
        throw Exception('File transfer timeout');
      }

      // Parse and import session
      setState(() {
        _importStatus = 'Parsing session data...';
      });

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      await _parseAndImportSession(
        bluetoothService.arduinoFileContentLines,
        fileName,
        sessionProvider,
      );

      if (mounted) {
        setState(() {
          _isImporting = false;
          _currentImportFile = null;
          _importStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session imported successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _currentImportFile = null;
          _importStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Parse CSV data and import as session
  Future<void> _parseAndImportSession(
    List<String> csvLines,
    String fileName,
    SessionProvider sessionProvider,
  ) async {
    try {
      final List<double> tempData = [];
      int? duration;
      int? sessionId;

      // Parse CSV format (time,temperature)
      for (final line in csvLines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Try to parse as "time,temperature"
        final parts = trimmed.split(',');
        if (parts.length == 2) {
          final time = int.tryParse(parts[0].trim());
          final temp = double.tryParse(parts[1].trim());

          if (time != null && temp != null) {
            tempData.add(temp);
            duration = time; // Last time value is total duration
          }
        }
      }

      if (tempData.isEmpty || duration == null) {
        throw Exception('No valid temperature data found in file');
      }

      // Extract session ID from filename (format: "sessionXX.txt")
      final match = RegExp(r'session(\d+)\.txt').firstMatch(fileName);
      if (match != null) {
        sessionId = int.tryParse(match.group(1) ?? '');
      }

      // Calculate temperature change
      final tempChange = tempData.isNotEmpty && tempData.length > 1
          ? tempData.last - tempData.first
          : 0.0;

      // Import session with default breathing times
      // (Arduino files don't contain these values)
      sessionProvider.addSession(
        sessionId: sessionId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        duration: duration,
        temperatureChange: tempChange,
        inhaleTime: 4.5, // Default inhale time
        exhaleTime: 9.0, // Default exhale time
        tempSetData: tempData,
      );
    } catch (e) {
      throw Exception('Failed to parse session data: $e');
    }
  }

  /// Cancel ongoing import
  Future<void> _cancelImport(BluetoothService bluetoothService) async {
    await bluetoothService.cancelFileImport();
    setState(() {
      _isImporting = false;
      _currentImportFile = null;
      _importStatus = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import canceled'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Confirm and delete single file
  Future<void> _confirmDeleteFile(BluetoothService bluetoothService, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete $fileName from Arduino SD card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await bluetoothService.deleteArduinoSession(fileName);

      // Wait a moment then refresh file list
      await Future.delayed(const Duration(seconds: 1));
      await bluetoothService.requestArduinoFileList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Confirm and delete all files
  Future<void> _confirmDeleteAll(BluetoothService bluetoothService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Files'),
        content: const Text('Delete all session files from Arduino SD card? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await bluetoothService.deleteAllArduinoSessions();

      // Wait a moment then refresh file list
      await Future.delayed(const Duration(seconds: 1));
      await bluetoothService.requestArduinoFileList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All files deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
