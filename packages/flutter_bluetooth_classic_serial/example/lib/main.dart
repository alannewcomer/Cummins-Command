import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Classic Serial Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BluetoothClassicExample(),
    );
  }
}

class BluetoothClassicExample extends StatefulWidget {
  const BluetoothClassicExample({super.key});

  @override
  State<BluetoothClassicExample> createState() =>
      _BluetoothClassicExampleState();
}

class _BluetoothClassicExampleState extends State<BluetoothClassicExample>
    with WidgetsBindingObserver {
  late FlutterBluetoothClassic _bluetooth;
  bool _isBluetoothAvailable = false;
  bool _isBluetoothEnabled = false;
  BluetoothConnectionState? _connectionState;
  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  String _receivedData = '';
  final StringBuffer _dataBuffer = StringBuffer();
  final TextEditingController _messageController = TextEditingController();
  bool _isDiscovering = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothData>? _dataSubscription;
  StreamSubscription<BluetoothState>? _stateSubscription;
  StreamSubscription<BluetoothDevice>? _deviceDiscoverySubscription;
  Timer? _reconnectTimer;
  bool _autoReconnect = false;
  String? _lastConnectedAddress;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bluetooth = FlutterBluetoothClassic();
    _initBluetooth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    _deviceDiscoverySubscription?.cancel();
    _reconnectTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkBluetoothState();
    }
  }

  Future<void> _initBluetooth() async {
    await _checkBluetoothState();
    _setupListeners();
  }

  Future<void> _checkBluetoothState() async {
    try {
      bool isSupported = await _bluetooth.isBluetoothSupported();
      bool isEnabled = await _bluetooth.isBluetoothEnabled();

      setState(() {
        _isBluetoothAvailable = isSupported;
        _isBluetoothEnabled = isEnabled;
      });

      if (isSupported && isEnabled) {
        await _loadPairedDevices();
      }
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
    }
  }

  void _setupListeners() {
    // Listen for Bluetooth state changes
    _stateSubscription = _bluetooth.onStateChanged.listen(
      (state) {
        setState(() {
          _isBluetoothEnabled = state.isEnabled;
        });
        if (state.isEnabled) {
          _loadPairedDevices();
        }
      },
      onError: (error) {
        debugPrint('Bluetooth state error: $error');
      },
    );

    // Listen for connection state changes
    _connectionSubscription = _bluetooth.onConnectionChanged.listen(
      _onConnectionStateChanged,
      onError: (error) {
        debugPrint('Connection state error: $error');
      },
    );

    // Listen for incoming data
    _dataSubscription = _bluetooth.onDataReceived.listen(
      _onDataReceived,
      onError: (error) {
        debugPrint('Data received error: $error');
      },
    );

    // Listen for device discovery events
    _deviceDiscoverySubscription = _bluetooth.onDeviceDiscovered.listen(
      _onDeviceDiscovered,
      onError: (error) {
        debugPrint('Device discovery error: $error');
      },
    );
  }

  void _onConnectionStateChanged(BluetoothConnectionState state) {
    setState(() {
      _connectionState = state;

      if (state.isConnected) {
        _connectedDevice = _pairedDevices.firstWhere(
          (device) => device.address == state.deviceAddress,
          orElse: () => _discoveredDevices.firstWhere(
            (device) => device.address == state.deviceAddress,
            orElse: () => BluetoothDevice(
              name: 'Unknown Device',
              address: state.deviceAddress,
              paired: false,
            ),
          ),
        );
        _lastConnectedAddress = state.deviceAddress;
        _reconnectTimer?.cancel();
      } else {
        _connectedDevice = null;
        if (_autoReconnect && _lastConnectedAddress != null) {
          _startReconnectTimer();
        }
      }
    });

    _showConnectionSnackBar(state);
  }

  void _onDataReceived(BluetoothData data) {
    String received = data.asString();
    _dataBuffer.write(received);

    setState(() {
      _receivedData += received;
    });

    // Process complete messages (assuming newline-terminated)
    String bufferContent = _dataBuffer.toString();
    if (bufferContent.contains('\n')) {
      List<String> lines = bufferContent.split('\n');
      _dataBuffer.clear();
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        _dataBuffer.write(lines.last);
      }

      // Process complete lines
      for (int i = 0; i < lines.length - 1; i++) {
        _processMessage(lines[i].trim());
      }
    }
  }

  void _onDeviceDiscovered(BluetoothDevice device) {
    setState(() {
      // Add device if not already in the list
      if (!_discoveredDevices.any((d) => d.address == device.address)) {
        _discoveredDevices.add(device);
      }
    });
  }

  void _processMessage(String message) {
    if (message.isNotEmpty) {
      debugPrint('Processed message: $message');
      // Add your message processing logic here
    }
  }

  void _showConnectionSnackBar(BluetoothConnectionState state) {
    if (!mounted) return;

    String message;
    Color backgroundColor;

    if (state.isConnected) {
      message = 'Connected to ${_connectedDevice?.name ?? 'device'}';
      backgroundColor = Colors.green;
    } else {
      message = 'Disconnected: ${state.status}';
      backgroundColor = Colors.red;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_lastConnectedAddress != null &&
          _connectionState?.isConnected != true &&
          _autoReconnect) {
        try {
          debugPrint('Attempting reconnection to $_lastConnectedAddress');
          await _bluetooth.connect(_lastConnectedAddress!);
        } catch (e) {
          debugPrint('Reconnection failed: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await _bluetooth.getPairedDevices();
      setState(() {
        _pairedDevices = devices;
      });
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
      _showErrorSnackBar('Failed to load paired devices: $e');
    }
  }

  Future<void> _startDiscovery() async {
    if (!_isBluetoothEnabled) {
      _showErrorSnackBar('Bluetooth not enabled');
      return;
    }

    setState(() {
      _isDiscovering = true;
      _discoveredDevices.clear();
    });

    try {
      await _bluetooth.startDiscovery();

      // Stop discovery after 30 seconds
      Timer(const Duration(seconds: 30), () {
        _stopDiscovery();
      });
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      setState(() {
        _isDiscovering = false;
      });
      _showErrorSnackBar('Failed to start discovery: $e');
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _bluetooth.stopDiscovery();
      setState(() {
        _isDiscovering = false;
      });
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device.address);
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _showErrorSnackBar('Failed to connect: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      _autoReconnect = false;
      _reconnectTimer?.cancel();
      await _bluetooth.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
      _showErrorSnackBar('Failed to disconnect: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      _showErrorSnackBar('Please enter a message');
      return;
    }

    if (_connectionState?.isConnected != true) {
      _showErrorSnackBar('Not connected to a device');
      return;
    }

    try {
      String message = _messageController.text;
      await _bluetooth.sendString(message);
      setState(() {
        _receivedData += 'Sent: $message\n';
      });
      _messageController.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showErrorSnackBar('Failed to send message: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearReceivedData() {
    setState(() {
      _receivedData = '';
    });
    _dataBuffer.clear();
  }

  Future<void> _enableBluetooth() async {
    try {
      await _bluetooth.enableBluetooth();
      await _checkBluetoothState();
    } catch (e) {
      debugPrint('Error enabling Bluetooth: $e');
      _showErrorSnackBar('Failed to enable Bluetooth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Classic Serial'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _checkBluetoothState,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: !_isBluetoothAvailable
          ? _buildBluetoothUnavailableView()
          : !_isBluetoothEnabled
          ? _buildBluetoothDisabledView()
          : _buildMainView(),
    );
  }

  Widget _buildBluetoothUnavailableView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Bluetooth Not Supported',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This device does not support Bluetooth Classic.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothDisabledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Bluetooth Disabled',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enable Bluetooth to use this app.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enableBluetooth,
              child: const Text('Enable Bluetooth'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildConnectionStatus(),
          const SizedBox(height: 16),
          _buildDeviceSection(),
          const SizedBox(height: 16),
          if (_connectionState?.isConnected == true) ...[
            _buildMessageSection(),
            const SizedBox(height: 16),
          ],
          Expanded(child: _buildDataSection()),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connection Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    const Text('Auto Reconnect'),
                    Switch(
                      value: _autoReconnect,
                      onChanged: (value) {
                        setState(() {
                          _autoReconnect = value;
                        });
                        if (!value) {
                          _reconnectTimer?.cancel();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _connectionState?.isConnected == true
                      ? Icons.link
                      : Icons.link_off,
                  color: _connectionState?.isConnected == true
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(_connectionState?.status ?? 'disconnected'),
              ],
            ),
            if (_connectedDevice != null) ...[
              const SizedBox(height: 8),
              Text('Connected to: ${_connectedDevice!.name}'),
              Text('Address: ${_connectedDevice!.address}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Devices', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    IconButton(
                      onPressed: _isDiscovering ? null : _startDiscovery,
                      icon: _isDiscovering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      tooltip: 'Start discovery',
                    ),
                    IconButton(
                      onPressed: _loadPairedDevices,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh paired devices',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_pairedDevices.isNotEmpty) ...[
              const Text(
                'Paired Devices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ..._pairedDevices.map((device) => _buildDeviceTile(device)),
            ],
            if (_discoveredDevices.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Discovered Devices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ..._discoveredDevices.map((device) => _buildDeviceTile(device)),
            ],
            if (_pairedDevices.isEmpty && _discoveredDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No devices found. Try refreshing or starting discovery.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device) {
    final isConnected = _connectedDevice?.address == device.address;
    final isConnecting =
        _connectionState?.deviceAddress == device.address &&
        !(_connectionState?.isConnected ?? false);

    return ListTile(
      leading: Icon(
        device.paired ? Icons.bluetooth : Icons.bluetooth_searching,
        color: isConnected
            ? Colors.green
            : (isConnecting ? Colors.orange : null),
      ),
      title: Text(device.name),
      subtitle: Text(device.address),
      trailing: isConnected
          ? ElevatedButton(
              onPressed: _disconnect,
              child: const Text('Disconnect'),
            )
          : ElevatedButton(
              onPressed: isConnecting ? null : () => _connectToDevice(device),
              child: Text(isConnecting ? 'Connecting...' : 'Connect'),
            ),
    );
  }

  Widget _buildMessageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Message',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter message to send',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Received Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: _clearReceivedData,
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear data',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _receivedData.isEmpty ? 'No data received' : _receivedData,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
