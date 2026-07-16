import 'package:flutter/material.dart';
import 'arduino_connection_screen.dart';

class IotConnectionScreen extends StatefulWidget {
  const IotConnectionScreen({super.key});

  @override
  State<IotConnectionScreen> createState() => _IotConnectionScreenState();
}

class _IotConnectionScreenState extends State<IotConnectionScreen> {
  bool _connected = false;
  final _serverController = TextEditingController(text: 'blynk-cloud.com');
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _serverController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _toggleConnection() {
    setState(() {
      _connected = !_connected;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_connected ? 'Connected to IoT!' : 'Disconnected from IoT.'),
        backgroundColor: _connected ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'IoT Connection',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          actions: [
            Icon(_connected ? Icons.cloud_done : Icons.cloud_off, color: _connected ? Colors.green : Colors.red),
            const SizedBox(width: 16),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_connected ? Icons.check_circle : Icons.cancel, color: _connected ? Colors.green : Colors.red, size: 28),
                const SizedBox(width: 10),
                Text(
                  _connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _connected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Server Address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _serverController,
              enabled: !_connected,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: 'e.g. blynk-cloud.com',
                prefixIcon: const Icon(Icons.cloud),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Auth Token', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              enabled: !_connected,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: 'Enter your Blynk token',
                prefixIcon: const Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _connected ? Colors.red : Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _toggleConnection,
                    child: Text(_connected ? 'Disconnect' : 'Connect', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                // Arduino Connection Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.usb),
                    label: const Text('Arduino Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ArduinoConnectionScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 