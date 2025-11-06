import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../constants/bluetooth_constants.dart';

/// Bluetooth LE service for Calmwand device communication
/// Ported from BluetoothManager.swift
class BluetoothService extends ChangeNotifier {
  // Discovered devices
  final List<fbp.BluetoothDevice> _devices = [];
  List<fbp.BluetoothDevice> get devices => List.unmodifiable(_devices);

  // Connection state
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _statusMessage = '';
  fbp.BluetoothAdapterState _adapterState = fbp.BluetoothAdapterState.unknown;

  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;
  bool get isBluetoothAvailable => _adapterState == fbp.BluetoothAdapterState.on;

  // Connected device and characteristics
  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get connectedDeviceName => _connectedDevice?.platformName;

  // Characteristic references
  fbp.BluetoothCharacteristic? _temperatureChar;
  fbp.BluetoothCharacteristic? _brightnessChar;
  fbp.BluetoothCharacteristic? _inhaleTimeChar;
  fbp.BluetoothCharacteristic? _exhaleTimeChar;
  fbp.BluetoothCharacteristic? _motorStrengthChar;
  fbp.BluetoothCharacteristic? _fileListRequestChar;
  fbp.BluetoothCharacteristic? _fileNameChar;
  fbp.BluetoothCharacteristic? _fileContentRequestChar;
  fbp.BluetoothCharacteristic? _fileContentChar;
  fbp.BluetoothCharacteristic? _fileActionChar;
  fbp.BluetoothCharacteristic? _sessionIdChar;

  // Published data from device
  String _temperatureData = '';
  String _brightnessData = '';
  String _inhaleData = '';
  String _exhaleData = '';
  String _motorStrengthData = '';
  int? _sessionId;

  String get temperatureData => _temperatureData;
  String get brightnessData => _brightnessData;
  String get inhaleData => _inhaleData;
  String get exhaleData => _exhaleData;
  String get motorStrengthData => _motorStrengthData;
  int? get sessionId => _sessionId;

  // Arduino file operations
  final List<String> _arduinoFileList = [];
  List<String> get arduinoFileList => List.unmodifiable(_arduinoFileList);

  final List<String> _arduinoFileContentLines = [];
  List<String> get arduinoFileContentLines => List.unmodifiable(_arduinoFileContentLines);

  bool _fileContentTransferCompleted = false;
  bool get fileContentTransferCompleted => _fileContentTransferCompleted;

  // Subscriptions
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  final List<StreamSubscription> _characteristicSubscriptions = [];

  BluetoothService() {
    _initialize();
  }

  void _initialize() {
    // Listen to adapter state changes (similar to Swift's centralManagerDidUpdateState)
    fbp.FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;

      if (state == fbp.BluetoothAdapterState.on) {
        // On Web platform, scan must be triggered by user action (button click)
        // On mobile platforms, auto-scan when Bluetooth is ready (matches Swift behavior)
        if (kIsWeb) {
          _statusMessage = 'Bluetooth is ready. Tap to scan.';
        } else {
          _statusMessage = 'Scanning for Devices...';
          startScan();
        }
      } else if (state == fbp.BluetoothAdapterState.off) {
        _statusMessage = 'Bluetooth is OFF. Please turn it on.';
        _isScanning = false;
      } else if (state == fbp.BluetoothAdapterState.unauthorized) {
        _statusMessage = 'Bluetooth permission denied.';
        _isScanning = false;
      } else {
        _statusMessage = 'Bluetooth NOT AVAILABLE';
        _isScanning = false;
      }
      notifyListeners();
    });

    // Check initial state
    _checkInitialBluetoothState();
  }

  /// Check initial bluetooth state when service starts
  Future<void> _checkInitialBluetoothState() async {
    try {
      final state = await fbp.FlutterBluePlus.adapterState.first;
      _adapterState = state;

      if (state == fbp.BluetoothAdapterState.on) {
        _statusMessage = 'Scanning for Devices...';
        // Auto-scan if Bluetooth is already on (matches Swift behavior)
        startScan();
      } else {
        _statusMessage = 'Bluetooth NOT OPEN or UNAVAILABLE';
      }
      notifyListeners();
    } catch (e) {
      print('Error checking bluetooth state: $e');
      _statusMessage = 'Error checking Bluetooth state';
      notifyListeners();
    }
  }

  /// Start scanning for Calmwand devices
  /// Similar to Swift's startScan logic with state checking
  Future<void> startScan() async {
    if (_isScanning) {
      print('Already scanning, ignoring request');
      return;
    }

    // Check if Bluetooth is available (similar to Swift's .poweredOn check)
    if (_adapterState != fbp.BluetoothAdapterState.on) {
      _statusMessage = 'Bluetooth must be turned ON to scan';
      notifyListeners();
      print('Cannot scan: Bluetooth state is $_adapterState');
      return;
    }

    try {
      _isScanning = true;
      _devices.clear();
      _statusMessage = 'Scanning for Devices...';
      notifyListeners();

      print('Starting BLE scan with service UUID: ${BluetoothConstants.serviceUUID}');

      // Listen for scan results BEFORE starting scan (critical for Web platform)
      _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult result in results) {
          // Check if device is not already in list (similar to Swift's contains check)
          if (!_devices.any((d) => d.remoteId == result.device.remoteId)) {
            print('Found device: ${result.device.platformName} (${result.device.remoteId})');
            _devices.add(result.device);
            notifyListeners();
          }
        }
      }, onError: (error) {
        print('Scan error: $error');
        _statusMessage = 'Scan error: $error';
        _isScanning = false;
        notifyListeners();
      });

      // Start scanning with service filter (matches Swift's scanForPeripherals)
      // Set 5 second timeout for Web platform compatibility
      await fbp.FlutterBluePlus.startScan(
        withServices: [fbp.Guid(BluetoothConstants.serviceUUID)],
        timeout: const Duration(seconds: 5),
      );

      // Wait for scan to complete and update status
      await fbp.FlutterBluePlus.isScanning.firstWhere((scanning) => scanning == false);
      _isScanning = false;
      _statusMessage = _devices.isEmpty
          ? 'No devices found. Tap to scan again.'
          : 'Found ${_devices.length} device(s)';
      notifyListeners();
    } catch (e) {
      print('Error starting scan: $e');
      _statusMessage = 'Error starting scan: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await fbp.FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  /// Connect to a device (matches Swift's connect method)
  /// Simplified sequential flow: connect -> listen -> discover
  Future<void> connect(fbp.BluetoothDevice device) async {
    _isConnecting = true;
    _statusMessage = 'Connecting...';
    notifyListeners();

    try {
      // Stop scanning to save battery (matches Swift's stopScan)
      await stopScan();

      // Cancel previous connection state subscription if any
      await _connectionStateSubscription?.cancel();

      // Connect to device with 15 second timeout (reasonable for BLE)
      await device.connect(
        timeout: const Duration(seconds: 15),
      );

      _connectedDevice = device;
      _isConnecting = false;
      _isConnected = true;
      _statusMessage = 'Connected to ${device.platformName ?? "Unknown"}';
      print('Successfully connected to ${device.platformName}');
      notifyListeners();

      // Set up disconnection listener AFTER successful connection
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          print('Device disconnected: ${device.platformName}');
          _handleDisconnection();
        }
      });

      // Discover services and characteristics (matches Swift's discoverServices)
      await _discoverServices(device);
    } catch (e) {
      print('❌ Connection failed: $e');
      _statusMessage = 'Connection failed: $e';
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Handle disconnection (similar to Swift's didDisconnectPeripheral)
  void _handleDisconnection() {
    _isConnected = false;
    _isConnecting = false;
    _statusMessage = 'Disconnected';
    notifyListeners();

    // Auto-restart scan on mobile platforms only
    // On Web, user must manually initiate scan (Web Bluetooth requirement)
    if (!kIsWeb) {
      print('Restarting scan after disconnection...');
      Future.delayed(const Duration(milliseconds: 500), () {
        startScan();
      });
    } else {
      print('Device disconnected. Tap to scan again.');
      _statusMessage = 'Disconnected. Tap to scan again.';
      notifyListeners();
    }
  }

  /// Discover services and characteristics (matches Swift's didDiscoverServices)
  Future<void> _discoverServices(fbp.BluetoothDevice device) async {
    try {
      print('Discovering services for ${device.platformName}...');
      List<fbp.BluetoothService> services = await device.discoverServices();

      print('Found ${services.length} services');
      bool foundTargetService = false;

      for (fbp.BluetoothService service in services) {
        print('Service UUID: ${service.uuid}');
        if (service.uuid == fbp.Guid(BluetoothConstants.serviceUUID)) {
          print('Found target Calmwand service!');
          foundTargetService = true;
          await _setupCharacteristics(service);
          break;
        }
      }

      if (!foundTargetService) {
        print('Warning: Target service ${BluetoothConstants.serviceUUID} not found');
        _statusMessage = 'Device connected but service not found';
        notifyListeners();
      }
    } catch (e) {
      print('Error discovering services: $e');
      _statusMessage = 'Error discovering services: $e';
      notifyListeners();
    }
  }

  /// Set up all characteristics (matches Swift's didDiscoverCharacteristics)
  /// IMPORTANT: First discover all characteristics, THEN set up notifications/reads
  Future<void> _setupCharacteristics(fbp.BluetoothService service) async {
    print('Setting up characteristics for service ${service.uuid}');
    print('Found ${service.characteristics.length} characteristics');

    // PHASE 1: Discover and store all characteristic references
    for (fbp.BluetoothCharacteristic char in service.characteristics) {
      final uuidStr = char.uuid.toString().toUpperCase();
      print('Characteristic: $uuidStr');

      if (uuidStr == BluetoothConstants.temperatureCharacteristicUUID.toUpperCase()) {
        _temperatureChar = char;
        print('✓ Found Temperature characteristic (NOTIFY)');
      }
      else if (uuidStr == BluetoothConstants.brightnessCharacteristicUUID.toUpperCase()) {
        _brightnessChar = char;
        print('✓ Found Brightness characteristic (READ/WRITE)');
      }
      else if (uuidStr == BluetoothConstants.inhaleTimeCharacteristicUUID.toUpperCase()) {
        _inhaleTimeChar = char;
        print('✓ Found Inhale Time characteristic (READ/WRITE)');
      }
      else if (uuidStr == BluetoothConstants.exhaleTimeCharacteristicUUID.toUpperCase()) {
        _exhaleTimeChar = char;
        print('✓ Found Exhale Time characteristic (READ/WRITE)');
      }
      else if (uuidStr == BluetoothConstants.motorStrengthCharacteristicUUID.toUpperCase()) {
        _motorStrengthChar = char;
        print('✓ Found Motor Strength characteristic (READ/WRITE)');
      }
      else if (uuidStr == BluetoothConstants.fileListRequestCharacteristicUUID.toUpperCase()) {
        _fileListRequestChar = char;
        print('✓ Found File List Request characteristic (WRITE)');
      }
      else if (uuidStr == BluetoothConstants.fileNameCharacteristicUUID.toUpperCase()) {
        _fileNameChar = char;
        print('✓ Found File Name characteristic (NOTIFY)');
      }
      else if (uuidStr == BluetoothConstants.fileContentRequestCharacteristicUUID.toUpperCase()) {
        _fileContentRequestChar = char;
        print('✓ Found File Content Request characteristic (WRITE)');
      }
      else if (uuidStr == BluetoothConstants.fileContentCharacteristicUUID.toUpperCase()) {
        _fileContentChar = char;
        print('✓ Found File Content characteristic (NOTIFY)');
      }
      else if (uuidStr == BluetoothConstants.fileActionCharacteristicUUID.toUpperCase()) {
        _fileActionChar = char;
        print('✓ Found File Action characteristic (WRITE)');
      }
      else if (uuidStr == BluetoothConstants.sessionIdCharacteristicUUID.toUpperCase()) {
        _sessionIdChar = char;
        print('✓ Found Session ID characteristic (NOTIFY)');
      }
    }

    print('All characteristics discovered. Setting up notifications (background)...');

    // PHASE 2: Set up notifications for NOTIFY characteristics (ASYNC - non-blocking)
    // These run in the background and don't block READ operations
    if (_temperatureChar != null) {
      _subscribeToCharacteristic(_temperatureChar!, _handleTemperatureUpdate);
    }

    if (_fileNameChar != null) {
      _subscribeToCharacteristic(_fileNameChar!, _handleFileNameUpdate);
    }

    if (_fileContentChar != null) {
      _subscribeToCharacteristic(_fileContentChar!, _handleFileContentUpdate);
    }

    if (_sessionIdChar != null) {
      _subscribeToCharacteristic(_sessionIdChar!, _handleSessionIdUpdate);
    }

    print('NOTIFY setup started (running in background). Reading initial values...');

    // PHASE 3: Read initial values for READ/WRITE characteristics (SEQUENTIAL)
    if (_brightnessChar != null) {
      await _readCharacteristic(_brightnessChar!, (value) {
        _brightnessData = value;
        notifyListeners();
      });
    }

    if (_inhaleTimeChar != null) {
      await _readCharacteristic(_inhaleTimeChar!, (value) {
        _inhaleData = value;
        notifyListeners();
      });
    }

    if (_exhaleTimeChar != null) {
      await _readCharacteristic(_exhaleTimeChar!, (value) {
        _exhaleData = value;
        notifyListeners();
      });
    }

    if (_motorStrengthChar != null) {
      await _readCharacteristic(_motorStrengthChar!, (value) {
        _motorStrengthData = value;
        notifyListeners();
      });
    }

    print('✅ Characteristic setup completed - device ready to use!');
  }

  /// Subscribe to characteristic notifications
  /// Fire-and-forget approach: set listener first, enable notification without waiting
  Future<void> _subscribeToCharacteristic(
    fbp.BluetoothCharacteristic char,
    Function(String) handler,
  ) async {
    // STEP 1: Set up the listener FIRST (before enabling notifications)
    // Use onValueReceived (not lastValueStream) for NOTIFY-only characteristics
    final subscription = char.onValueReceived.listen(
      (value) {
        if (value.isNotEmpty) {
          final strValue = utf8.decode(value);
          handler(strValue);
        }
      },
      onError: (error) {
        print('⚠️ Error in ${char.uuid} stream: $error');
      },
    );

    // Auto-cancel subscription when device disconnects (prevents memory leaks)
    if (_connectedDevice != null) {
      _connectedDevice!.cancelWhenDisconnected(subscription);
    }
    _characteristicSubscriptions.add(subscription);

    // STEP 2: Enable notifications but DON'T WAIT (fire and forget)
    // This avoids waiting for Arduino's descriptor write confirmation
    char.setNotifyValue(true).then((_) {
      print('✓ Notification enabled for ${char.uuid}');
    }).catchError((e) {
      print('⚠️ setNotifyValue warning for ${char.uuid}: $e (non-fatal, listener already active)');
    });

    print('✅ Listener set up for ${char.uuid}');
  }

  /// Read characteristic value with detailed logging
  Future<void> _readCharacteristic(
    fbp.BluetoothCharacteristic char,
    Function(String) handler,
  ) async {
    try {
      print('→ Reading ${char.uuid}...');
      final value = await char.read();

      if (value.isNotEmpty) {
        final strValue = utf8.decode(value);
        print('✓ Read ${char.uuid}: "$strValue"');
        handler(strValue);
      } else {
        print('⚠️ Read ${char.uuid}: empty value');
      }
    } catch (e) {
      print('❌ Error reading ${char.uuid}: $e');
      // Don't rethrow - allow setup to continue
    }
  }

  // MARK: - Characteristic Update Handlers

  void _handleTemperatureUpdate(String value) {
    _temperatureData = value;
    notifyListeners();
    // Temperature updates are continuous - logging would be too noisy
  }

  void _handleFileNameUpdate(String value) {
    if (value != BluetoothConstants.markerEnd) {
      // Arduino sends format: "sid:filename:mins" (e.g., "0:data0.txt:5")
      // We extract just the filename for compatibility
      final parts = value.split(':');
      if (parts.length >= 2) {
        _arduinoFileList.add(parts[1]); // Extract filename (e.g., "data0.txt")
      } else {
        _arduinoFileList.add(value); // Fallback to original value
      }
      notifyListeners();
    }
    // "END" means Arduino is done sending filenames
  }

  void _handleFileContentUpdate(String value) {
    if (value != BluetoothConstants.markerEOF) {
      print('Received file line: $value');
      _arduinoFileContentLines.add(value);
      notifyListeners();
    } else {
      print('Received EOF.');
      _fileContentTransferCompleted = true;
      notifyListeners();
    }
  }

  void _handleSessionIdUpdate(String value) {
    print('📥 Received SessionID notification: "$value"');
    final trimmed = value.trim();
    final id = int.tryParse(trimmed);
    if (id != null) {
      print('✅ Parsed SessionID: $id');
      _sessionId = id;
      notifyListeners();
    } else {
      print('❌ Failed to parse SessionID from: "$value"');
    }
  }

  // MARK: - Write Operations

  /// Write brightness value (0-255)
  Future<void> writeBrightness(String brightness) async {
    await _writeCharacteristic(_brightnessChar, brightness, 'brightness');
    // Update local value immediately (matches Swift behavior - no NOTIFY subscription)
    _brightnessData = brightness;
    notifyListeners();
  }

  /// Write inhale time in milliseconds
  Future<void> writeInhaleTime(String inhaleTime) async {
    await _writeCharacteristic(_inhaleTimeChar, inhaleTime, 'inhale time');
    // Update local value immediately (matches Swift behavior - no NOTIFY subscription)
    _inhaleData = inhaleTime;
    notifyListeners();
  }

  /// Write exhale time in milliseconds
  Future<void> writeExhaleTime(String exhaleTime) async {
    await _writeCharacteristic(_exhaleTimeChar, exhaleTime, 'exhale time');
    // Update local value immediately (matches Swift behavior - no NOTIFY subscription)
    _exhaleData = exhaleTime;
    notifyListeners();
  }

  /// Write motor strength (0-255)
  Future<void> writeMotorStrength(String strength) async {
    await _writeCharacteristic(_motorStrengthChar, strength, 'motor strength');
    // Update local value immediately (matches Swift behavior - no NOTIFY subscription)
    _motorStrengthData = strength;
    notifyListeners();
  }

  /// Generic write to characteristic
  Future<void> _writeCharacteristic(
    fbp.BluetoothCharacteristic? char,
    String value,
    String name,
  ) async {
    if (char == null || _connectedDevice == null) {
      print('No connected device or characteristic for $name');
      return;
    }

    try {
      final data = utf8.encode(value);
      await char.write(data, withoutResponse: false);
      print('Sent $name = $value');
    } catch (e) {
      print('Error writing $name: $e');
    }
  }

  // MARK: - Arduino File Operations

  /// Request list of files from Arduino
  Future<void> requestArduinoFileList() async {
    if (_fileListRequestChar == null || _connectedDevice == null) {
      print('Cannot request file list: no request characteristic or peripheral');
      return;
    }

    // Clear previous list
    _arduinoFileList.clear();
    notifyListeners();

    try {
      final data = utf8.encode(BluetoothConstants.cmdGetList);
      await _fileListRequestChar!.write(data, withoutResponse: false);
      print('Requested file list from Arduino');
    } catch (e) {
      print('Error requesting file list: $e');
    }
  }

  /// Request specific file content from Arduino
  Future<void> requestArduinoFile(String fileName) async {
    if (_fileContentRequestChar == null || _connectedDevice == null) {
      print('Cannot request file: no characteristic or peripheral');
      return;
    }

    // Clear old data and reset completion flag
    _arduinoFileContentLines.clear();
    _fileContentTransferCompleted = false;
    notifyListeners();

    try {
      final cmd = '${BluetoothConstants.cmdGetFile}$fileName';
      final data = utf8.encode(cmd);
      await _fileContentRequestChar!.write(data, withoutResponse: false);
      print('Writing "$cmd" to Arduino…');
    } catch (e) {
      print('Error requesting file: $e');
    }
  }

  /// Cancel file import
  Future<void> cancelFileImport() async {
    if (_fileContentRequestChar == null || _connectedDevice == null) {
      print('Cannot cancel file import: missing characteristic or peripheral');
      return;
    }

    try {
      final data = utf8.encode(BluetoothConstants.cmdCancel);
      await _fileContentRequestChar!.write(data, withoutResponse: false);
      print('Writing "CANCEL" to Arduino…');

      // Clear buffered lines
      _arduinoFileContentLines.clear();
      _fileContentTransferCompleted = false;
      notifyListeners();
    } catch (e) {
      print('Error canceling file import: $e');
    }
  }

  /// Delete session file on Arduino
  /// IMPORTANT: Uses fileActionChar (matches Swift's deleteArduinoSession)
  Future<void> deleteArduinoSession(String filename) async {
    if (_fileActionChar == null || _connectedDevice == null) {
      print('❌ Cannot delete: missing characteristic or peripheral');
      return;
    }

    try {
      final cmd = '${BluetoothConstants.cmdDelete}$filename';
      final data = utf8.encode(cmd);
      await _fileActionChar!.write(data, withoutResponse: false);
      print('→ Sending delete-command: $cmd');
    } catch (e) {
      print('Error deleting session: $e');
    }
  }

  /// Delete all sessions on Arduino
  Future<void> deleteAllArduinoSessions() async {
    if (_fileContentRequestChar == null || _connectedDevice == null) {
      print('Cannot delete all: missing characteristic or peripheral');
      return;
    }

    try {
      final data = utf8.encode(BluetoothConstants.cmdDeleteAll);
      await _fileContentRequestChar!.write(data, withoutResponse: false);
      print('Deleting all Arduino sessions');
    } catch (e) {
      print('Error deleting all sessions: $e');
    }
  }

  /// Start a new session on Arduino
  Future<void> startArduinoSession() async {
    if (_fileActionChar == null || _connectedDevice == null) {
      print('⚠️ Cannot start session: missing characteristic or peripheral');
      return;
    }

    try {
      final data = utf8.encode(BluetoothConstants.cmdStart);
      await _fileActionChar!.write(data, withoutResponse: false);
      print('→ Sent "START" to Arduino');

      // Poll for SessionID with timeout (Arduino may take 200-300ms to respond)
      print('⏳ Waiting for SessionID...');
      const maxWaitMs = 1000;
      const checkIntervalMs = 50;
      int elapsedMs = 0;

      while (_sessionId == null && elapsedMs < maxWaitMs) {
        await Future.delayed(const Duration(milliseconds: checkIntervalMs));
        elapsedMs += checkIntervalMs;
      }

      if (_sessionId != null) {
        print('✅ SessionID received: $_sessionId (after ${elapsedMs}ms)');
      } else {
        print('❌ SessionID not received after ${maxWaitMs}ms timeout');
      }
    } catch (e) {
      print('Error starting session: $e');
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      await _cleanup();
    }
  }

  /// Clean up connections and subscriptions
  Future<void> _cleanup() async {
    // Cancel connection state subscription
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    // Cancel characteristic subscriptions
    for (var subscription in _characteristicSubscriptions) {
      await subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    _connectedDevice = null;
    _isConnected = false;
    _statusMessage = 'Disconnected';

    // Clear characteristic references
    _temperatureChar = null;
    _brightnessChar = null;
    _inhaleTimeChar = null;
    _exhaleTimeChar = null;
    _motorStrengthChar = null;
    _fileListRequestChar = null;
    _fileNameChar = null;
    _fileContentRequestChar = null;
    _fileContentChar = null;
    _fileActionChar = null;
    _sessionIdChar = null;

    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    super.dispose();
  }
}
