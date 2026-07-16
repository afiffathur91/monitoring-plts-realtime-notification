import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/arduino_service.dart';

class ArduinoConnectionScreen extends StatefulWidget {
  const ArduinoConnectionScreen({super.key});

  @override
  State<ArduinoConnectionScreen> createState() => _ArduinoConnectionScreenState();
}

class _ArduinoConnectionScreenState extends State<ArduinoConnectionScreen> {
  final ArduinoService _arduinoService = ArduinoService();
  List<UsbDevice> _devices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    _isLoading = true;
    setState(() {});

    // Request USB permission
    final status = await Permission.storage.request();
    if (status.isGranted) {
      await _initArduino();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('USB permission is required')),
        );
      }
    }

    _isLoading = false;
    setState(() {});
  }

  Future<void> _initArduino() async {
    try {
      await _arduinoService.initialize();
      await _refreshDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  Future<void> _refreshDevices() async {
    try {
      _devices = await _arduinoService.getDevices();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing devices: $e')),
        );
      }
    }
  }

  Future<void> _connectToDevice(UsbDevice device) async {
    _isLoading = true;
    setState(() {});

    try {
      final success = await _arduinoService.connectToDevice(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Connected successfully' : 'Failed to connect',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting: $e')),
        );
      }
    }

    _isLoading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arduino Connection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No Arduino devices found',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refreshDevices,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isConnected = _arduinoService.isConnected;
                    
                    return ListTile(
                      leading: const Icon(Icons.usb),
                      title: Text(device.productName ?? 'Unknown Device'),
                      subtitle: Text(device.deviceId.toString()),
                      trailing: isConnected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : TextButton(
                              onPressed: () => _connectToDevice(device),
                              child: const Text('Connect'),
                            ),
                    );
                  },
                ),
    );
  }

  @override
  void dispose() {
    _arduinoService.dispose();
    super.dispose();
  }
}