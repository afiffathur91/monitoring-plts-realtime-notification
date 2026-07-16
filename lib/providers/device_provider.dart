import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';

class DeviceProvider extends ChangeNotifier {
  final DeviceService _deviceService = DeviceService();
  List<Device> _devices = [];
  bool _isLoading = false;
  String? _error;
  Device? _selectedDevice;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Device? get selectedDevice => _selectedDevice;

  // Listen to devices stream
  void init() {
    _deviceService.getDevicesStream().listen(
      (devices) {
        _devices = devices;
        // Keep selected device updated
        if (_selectedDevice != null) {
          _selectedDevice = devices.firstWhere(
            (d) => d.id == _selectedDevice!.id,
            orElse: () => _selectedDevice!,
          );
        }
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Select a device
  void selectDevice(Device device) {
    _selectedDevice = device;
    notifyListeners();
  }

  // Update device name
  Future<void> updateDeviceName(String deviceId, String newName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _deviceService.updateDeviceName(deviceId, newName);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete device
  Future<void> deleteDevice(String deviceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _deviceService.deleteDevice(deviceId);
      if (_selectedDevice?.id == deviceId) {
        _selectedDevice = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new device
  Future<bool> addDevice(String deviceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final exists = await _deviceService.deviceExists(deviceId);
      if (!exists) {
        // Pre-create the device node so it can be linked; the hardware will start populating data later
        await _deviceService.createDevice(deviceId);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}