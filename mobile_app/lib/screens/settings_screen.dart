import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../utils/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _enablePush = AppConfig.enablePushNotifications;
  bool _enableSMS = AppConfig.enableSMS;
  double _confidence = AppConfig.confidenceThreshold;
  int _frameSkip = AppConfig.frameSkip;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _apiUrlController.text = AppConfig.apiUrl;
    _phoneController.text = AppConfig.phoneNumber ?? '';
    _enablePush = AppConfig.enablePushNotifications;
    _enableSMS = AppConfig.enableSMS;
    _confidence = AppConfig.confidenceThreshold;
    _frameSkip = AppConfig.frameSkip;
  }

  Future<void> _saveSettings() async {
    AppConfig.apiUrl = _apiUrlController.text;
    AppConfig.phoneNumber = _phoneController.text.isNotEmpty ? _phoneController.text : null;
    AppConfig.enablePushNotifications = _enablePush;
    AppConfig.enableSMS = _enableSMS;
    AppConfig.confidenceThreshold = _confidence;
    AppConfig.frameSkip = _frameSkip;

    await AppConfig.saveConfig();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _testNotification() async {
    final notificationService = context.read<NotificationService>();
    await notificationService.sendTestNotification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Notificación de prueba enviada'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = context.read<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== SERVIDOR ==========
          _buildSection(
            title: '🌐 Servidor',
            children: [
              TextField(
                controller: _apiUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL del Backend',
                  hintText: 'http://192.168.1.100:8000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'WebSocket: ${AppConfig.apiUrl.replaceFirst('http', 'ws')}/ws/stream',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),

          const Divider(height: 32),

          // ========== ALERTAS ==========
          _buildSection(
            title: '🚨 Alertas',
            children: [
              SwitchListTile(
                title: const Text('Notificaciones Push'),
                subtitle: const Text('Recibir alertas en el dispositivo'),
                value: _enablePush,
                onChanged: (value) {
                  setState(() {
                    _enablePush = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Alertas SMS'),
                subtitle: const Text('Enviar SMS cuando se detecte un arma'),
                value: _enableSMS,
                onChanged: (value) {
                  setState(() {
                    _enableSMS = value;
                  });
                },
              ),
              if (_enableSMS)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Número de teléfono',
                      hintText: '+52 123 456 7890',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _testNotification,
                icon: const Icon(Icons.notifications),
                label: const Text('Probar Notificación'),
              ),
            ],
          ),

          const Divider(height: 32),

          // ========== DETECCIÓN ==========
          _buildSection(
            title: '🎯 Detección',
            children: [
              ListTile(
                title: const Text('Umbral de Confianza'),
                subtitle: Text('${(_confidence * 100).toInt()}%'),
                trailing: Text(
                  '${(_confidence * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Slider(
                value: _confidence,
                min: 0.1,
                max: 0.9,
                divisions: 8,
                label: '${(_confidence * 100).toInt()}%',
                onChanged: (value) {
                  setState(() {
                    _confidence = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Frames a procesar'),
                subtitle: const Text('1 de cada N frames (mayor = más rápido)'),
                trailing: Text(
                  '1/$_frameSkip',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Slider(
                value: _frameSkip.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '1/$_frameSkip',
                onChanged: (value) {
                  setState(() {
                    _frameSkip = value.toInt();
                  });
                },
              ),
            ],
          ),

          const Divider(height: 32),

          // ========== INFO ==========
          _buildSection(
            title: 'ℹ️ Información',
            children: [
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('FCM Token'),
                subtitle: Text(
                  notificationService.fcmToken ?? 'No disponible',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Versión'),
                subtitle: const Text('1.0.0'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ========== BOTONES ==========
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Guardar Configuración'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
