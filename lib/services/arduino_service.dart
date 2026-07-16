import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import '../models/solar_data.dart';

class ArduinoService {
  static final ArduinoService _instance = ArduinoService._internal();
  factory ArduinoService() => _instance;
  ArduinoService._internal();

  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  List<UsbDevice> _devices = [];

  bool get isConnected => _port != null;
  
  // Stream controller for broadcasting solar data
  final _dataController = StreamController<SolarData>.broadcast();
  Stream<SolarData> get dataStream => _dataController.stream;

  // Initialize USB Serial
  Future<void> initialize() async {
    // Get list of available ports
    _devices = await UsbSerial.listDevices();
    
    // Try to connect to the first available device
    if (_devices.isNotEmpty) {
      await connectToDevice(_devices.first);
    }
  }

  // Connect to a specific device
  Future<bool> connectToDevice(UsbDevice device) async {
    // If already connected, disconnect first
    if (_port != null) {
      await disconnect();
    }

    // Try to open port
    _port = await device.create();
    if (_port == null) {
      return false;
    }

    await _port!.open();
    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
      9600, // Baud rate
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    // Create transaction for reading data
    _transaction = Transaction.stringTerminated(
      _port!.inputStream!,
      Uint8List.fromList([13, 10]), // Terminate on CR LF
    );

    // Listen for incoming data
    _subscription = _transaction!.stream.listen((String data) {
      try {
        final jsonData = json.decode(data);
        final solarData = SolarData(
          voltage: jsonData['voltage'].toDouble(),
          current: jsonData['current'].toDouble(),
          power: jsonData['power'].toDouble(),
          timestamp: DateTime.now(),
        );
        _dataController.add(solarData);
      } catch (e) {
        print('Error parsing Arduino data: $e');
      }
    });

    return true;
  }

  // Disconnect from device
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _port?.close();
    _port = null;
    _subscription = null;
    _transaction = null;
  }

  // Get list of available devices
  Future<List<UsbDevice>> getDevices() async {
    _devices = await UsbSerial.listDevices();
    return _devices;
  }

  // Dispose
  void dispose() {
    disconnect();
    _dataController.close();
  }
}