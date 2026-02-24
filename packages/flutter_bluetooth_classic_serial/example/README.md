# Flutter Bluetooth Classic Serial - Example App

This example demonstrates how to use the Flutter Bluetooth Classic Serial plugin to create a complete Bluetooth Classic communication application.

## Features

✅ **Bluetooth State Management**
- Automatic detection of Bluetooth support
- Bluetooth enable/disable handling
- Real-time state monitoring

✅ **Device Discovery & Management**
- View paired Bluetooth devices
- Discover new devices
- Connect/disconnect functionality
- Auto-reconnection with configurable retry logic

✅ **Data Communication**
- Send text messages to connected devices
- Receive and display incoming data
- Message buffering and line-based processing
- Real-time data streaming

✅ **User Interface**
- Material 3 design
- Responsive layout
- Connection status indicators
- Error handling with user feedback
- Data clearing and management

## Getting Started

### Prerequisites

1. **Flutter SDK** (3.8.0 or higher)
2. **Android SDK** with API level 21+ for Android
3. **Xcode** for iOS development
4. **Bluetooth device** to test with (e.g., Arduino with HC-05, ESP32, etc.)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd flutter_bluetooth_classic_serial/example
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Platform Setup

#### Android
The app requires the following permissions (already configured):
- `BLUETOOTH`
- `BLUETOOTH_ADMIN`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`
- `BLUETOOTH_SCAN` (Android 12+)
- `BLUETOOTH_CONNECT` (Android 12+)
- `BLUETOOTH_ADVERTISE` (Android 12+)

#### iOS
Bluetooth Classic requires iOS 13+ and proper configuration in `Info.plist`.

#### Windows
Windows 10/11 with Bluetooth support.

## Usage Guide

### 1. Initial Setup
- Launch the app
- If Bluetooth is disabled, tap "Enable Bluetooth"
- Grant necessary permissions when prompted

### 2. Device Connection
- **Paired Devices**: View and connect to already paired devices
- **Discovery**: Tap the search icon to discover new devices
- **Connect**: Tap "Connect" next to any device
- **Auto-Reconnect**: Toggle the switch to enable automatic reconnection

### 3. Data Communication
- **Send Messages**: Type in the message field and tap "Send"
- **Receive Data**: Incoming data appears in the "Received Data" section
- **Clear Data**: Use the clear button to reset the data display

### 4. Connection Management
- **Status Monitoring**: View real-time connection status
- **Manual Disconnect**: Use the "Disconnect" button
- **Auto-Reconnect**: Enable for automatic reconnection on disconnection

## Testing with Common Devices

### Arduino with HC-05/HC-06
```cpp
void setup() {
  Serial.begin(9600);
}

void loop() {
  if (Serial.available()) {
    String data = Serial.readString();
    Serial.print("Echo: ");
    Serial.println(data);
  }
  delay(100);
}
```

### ESP32 Bluetooth Classic
```cpp
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

void setup() {
  Serial.begin(115200);
  SerialBT.begin("ESP32test");
}

void loop() {
  if (SerialBT.available()) {
    String message = SerialBT.readString();
    SerialBT.print("Received: ");
    SerialBT.println(message);
  }
  delay(20);
}
```

## API Reference

### Key Classes

#### `FlutterBluetoothClassic`
Main plugin class for Bluetooth operations.

#### `BluetoothDevice`
Represents a Bluetooth device with name, address, and pairing status.

#### `BluetoothConnectionState`
Contains connection status and device information.

#### `BluetoothData`
Represents received data with conversion utilities.

### Key Methods

```dart
// Check Bluetooth support and status
await FlutterBluetoothClassic().isBluetoothSupported();
await FlutterBluetoothClassic().isBluetoothEnabled();

// Device management
await FlutterBluetoothClassic().getPairedDevices();
await FlutterBluetoothClassic().startDiscovery();

// Connection
await FlutterBluetoothClassic().connect(deviceAddress);
await FlutterBluetoothClassic().disconnect();

// Data transmission
await FlutterBluetoothClassic().sendString(message);
```

### Event Streams

```dart
// Listen for state changes
FlutterBluetoothClassic().onStateChanged.listen((state) { });

// Listen for connection changes
FlutterBluetoothClassic().onConnectionChanged.listen((state) { });

// Listen for incoming data
FlutterBluetoothClassic().onDataReceived.listen((data) { });
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure all Bluetooth permissions are granted
   - Check location services are enabled (required for device discovery)

2. **Connection Failed**
   - Verify device is in pairing mode
   - Check device compatibility
   - Ensure device isn't connected to another application

3. **No Devices Found**
   - Make sure target device is discoverable
   - Check Bluetooth is enabled on both devices
   - Try refreshing the device list

4. **Data Not Received**
   - Verify the connected device is sending data
   - Check baud rate compatibility
   - Ensure proper data termination (newlines)

### Debug Tips

- Enable debug mode for detailed logging
- Use Android Studio's logcat for Android debugging
- Check device-specific Bluetooth implementations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This example is part of the Flutter Bluetooth Classic Serial plugin and follows the same license terms.

## Support

For issues and questions:
- Check the plugin documentation
- Review existing GitHub issues
- Create a new issue with detailed information

---

**Note**: This example demonstrates the core functionality of the Flutter Bluetooth Classic Serial plugin. Adapt the code to your specific use case and requirements.
