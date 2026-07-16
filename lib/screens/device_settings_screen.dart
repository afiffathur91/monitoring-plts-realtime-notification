import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../providers/solar_provider.dart';
import '../models/device.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({Key? key}) : super(key: key);

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize device provider
    context.read<DeviceProvider>().init();
  }

  void _showAddDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the Device ID shown on the device\'s setup page',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context
                  .read<DeviceProvider>()
                  .addDevice(_deviceIdController.text);
              if (success) {
                Navigator.pop(context);
                _deviceIdController.clear();
              }
            },
            child: const Text('Add Device'),
          ),
        ],
      ),
    );
  }

  void _showEditDeviceDialog(Device device) {
    _deviceNameController.text = device.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context
                  .read<DeviceProvider>()
                  .updateDeviceName(device.id, _deviceNameController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDeviceDialog(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete ${device.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<DeviceProvider>().deleteDevice(device.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Settings'),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${provider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.init(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No devices added yet'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddDeviceDialog,
                    child: const Text('Add Device'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: provider.devices.length,
                  itemBuilder: (context, index) {
                    final device = provider.devices[index];
                    final isActive = solarProvider.currentDeviceId == device.id;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: isActive ? Colors.blue.shade50 : Colors.white,
                      child: ListTile(
                        onTap: () {
                          context.read<DeviceProvider>().selectDevice(device);
                          context.read<SolarProvider>().selectDevice(device.id);
                        },
                        leading: Icon(
                          Icons.circle,
                          color: device.isOnline ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Device ID: ${device.id}'),
                            Text('Last seen: ${_formatLastSeen(device.lastSeen)}'),
                            Text('Status: ${device.status}'),
                            if (isActive)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Active device',
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Edit'),
                              onTap: () => _showEditDeviceDialog(device),
                            ),
                            PopupMenuItem(
                              child: const Text('Delete'),
                              onTap: () => _showDeleteDeviceDialog(device),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _showAddDeviceDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Device'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    if (lastSeen.millisecondsSinceEpoch == 0) {
      return 'Never';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inDays > 0) {
      return DateFormat('MMM d, yyyy - h:mm a').format(lastSeen);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }
}