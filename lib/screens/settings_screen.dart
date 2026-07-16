import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/solar_provider.dart';
import '../models/settings.dart';
import '../services/notification_delivery_service.dart';
import 'iot_connection_screen.dart';
import 'device_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _minVoltageController;
  late TextEditingController _maxVoltageController;
  late TextEditingController _minCurrentController;
  late TextEditingController _maxCurrentController;
  late TextEditingController _minPowerController;
  late TextEditingController _maxPowerController;
  late TextEditingController _cooldownController;
  late TextEditingController _telegramBotTokenController;
  late TextEditingController _telegramChatIdController;
  late TextEditingController _webhookUrlController;
  bool _notificationSoundEnabled = true;
  bool _showWattLampu = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers when widget is created
    final solarProvider = Provider.of<SolarProvider>(context, listen: false);
    final settings = solarProvider.settings;
    
    _minVoltageController = TextEditingController(text: settings.minVoltage.toString());
    _maxVoltageController = TextEditingController(text: settings.maxVoltage.toString());
    _minCurrentController = TextEditingController(text: settings.minCurrent.toString());
    _maxCurrentController = TextEditingController(text: settings.maxCurrent.toString());
    _minPowerController = TextEditingController(text: settings.minPower.toString());
    _maxPowerController = TextEditingController(text: settings.maxPower.toString());
  _cooldownController = TextEditingController(text: settings.notificationCooldownMinutes.toString());
  _telegramBotTokenController = TextEditingController(text: settings.telegramBotToken);
  _telegramChatIdController = TextEditingController(text: settings.telegramChatId);
  _webhookUrlController = TextEditingController(text: settings.notificationWebhookUrl);
  _notificationSoundEnabled = settings.notificationSoundEnabled;
  _showWattLampu = settings.showWattLampu;
  }

  @override
  void dispose() {
    _minVoltageController.dispose();
    _maxVoltageController.dispose();
    _minCurrentController.dispose();
    _maxCurrentController.dispose();
    _minPowerController.dispose();
    _maxPowerController.dispose();
    _cooldownController.dispose();
    _telegramBotTokenController.dispose();
    _telegramChatIdController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final solarProvider = Provider.of<SolarProvider>(context, listen: false);
      
      // Create a new settings object with the updated values
      final newSettings = Settings(
        minVoltage: double.parse(_minVoltageController.text),
        maxVoltage: double.parse(_maxVoltageController.text),
        minCurrent: double.parse(_minCurrentController.text),
        maxCurrent: double.parse(_maxCurrentController.text),
        minPower: double.parse(_minPowerController.text),
        maxPower: double.parse(_maxPowerController.text),
        notificationSoundEnabled: _notificationSoundEnabled,
        notificationCooldownMinutes: int.tryParse(_cooldownController.text) ?? 5,
        showWattLampu: _showWattLampu,
        telegramBotToken: _telegramBotTokenController.text.trim(),
        telegramChatId: _telegramChatIdController.text.trim(),
        notificationWebhookUrl: _webhookUrlController.text.trim(),
      );
      
      // Save the settings
      await solarProvider.saveSettings(newSettings);
      // Apply sound toggle immediately
      solarProvider.toggleNotificationSound(newSettings.notificationSoundEnabled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pengaturan Threshold',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Batas Tegangan
              const Text(
                'Batas Tegangan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildThresholdField(
                      controller: _minVoltageController,
                      labelText: 'Tegangan Minimum',
                      helperText: 'V',
                      validator: _validatePositiveNumber,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildThresholdField(
                      controller: _maxVoltageController,
                      labelText: 'Tegangan Maksimum',
                      helperText: 'V',
                      validator: _validatePositiveNumber,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Batas Arus
              const Text(
                'Batas Arus',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildThresholdField(
                      controller: _minCurrentController,
                      labelText: 'Arus Minimum',
                      helperText: 'A',
                      validator: _validatePositiveNumber,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildThresholdField(
                      controller: _maxCurrentController,
                      labelText: 'Arus Maksimum',
                      helperText: 'A',
                      validator: _validatePositiveNumber,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Batas Daya
              const Text(
                'Batas Daya',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildThresholdField(
                      controller: _minPowerController,
                      labelText: 'Daya Minimum',
                      helperText: 'W',
                      validator: _validatePositiveNumber,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildThresholdField(
                      controller: _maxPowerController,
                      labelText: 'Daya Maksimum',
                      helperText: 'W',
                      validator: _validatePositiveNumber,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Settings',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Tombol IoT Connection
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IotConnectionScreen()),
                    );
                  },
                  child: const Text('IoT Connection', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              // Notification sound toggle and cooldown
              SwitchListTile(
                title: const Text('Enable notification sound'),
                value: _notificationSoundEnabled,
                onChanged: (v) {
                  setState(() => _notificationSoundEnabled = v);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cooldownController,
                decoration: InputDecoration(
                  labelText: 'Notification cooldown (minutes)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: 'Minimum minutes between identical notifications',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Value is required';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Enter a valid non-negative integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Watt Lampu toggle
              SwitchListTile(
                title: const Text('Show Watt Lampu'),
                subtitle: const Text('Display lamp wattage in monitoring screen'),
                value: _showWattLampu,
                onChanged: (v) {
                  setState(() => _showWattLampu = v);
                },
              ),
              // Device Settings Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.devices),
                  label: const Text('Device Management'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              const Text(
                'Notifikasi ke Telegram / WhatsApp / Google Assistant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Pastikan Anda sudah mengirim /start ke bot Telegram Anda.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telegramBotTokenController,
                decoration: InputDecoration(
                  labelText: 'Token Bot Telegram',
                  hintText: 'Dari @BotFather',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telegramChatIdController,
                decoration: InputDecoration(
                  labelText: 'Chat ID Telegram',
                  hintText: 'Contoh: 1902668272',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Tes notifikasi Telegram'),
                  onPressed: () async {
                    final token = _telegramBotTokenController.text;
                    final chatId = _telegramChatIdController.text;
                    final err = await NotificationDeliveryService().sendTestToTelegram(token, chatId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err ?? 'Pesan uji terkirim ke Telegram. Cek HP Anda.'),
                        backgroundColor: err != null ? Colors.red : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _webhookUrlController,
                decoration: InputDecoration(
                  labelText: 'Webhook URL (opsional)',
                  hintText: 'IFTTT, Zapier, atau Google Assistant',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              // Test notification sound button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Tes suara notifikasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final solarProvider = Provider.of<SolarProvider>(context, listen: false);
                    try {
                      await solarProvider.playNotificationSound();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test notification sound played')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error playing sound: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdField({
    required TextEditingController controller,
    required String labelText,
    required String helperText,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        helperText: helperText,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
    );
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Value is required';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return 'Enter a valid number';
    }
    
    if (number < 0) {
      return 'Value must be positive';
    }
    
    return null;
  }
} 