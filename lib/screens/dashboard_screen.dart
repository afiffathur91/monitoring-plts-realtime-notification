import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/solar_provider.dart';
import '../providers/auth_provider.dart';
import '../models/solar_data.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'plts_monitoring_screen.dart';
import 'analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize solar data when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SolarProvider>(context, listen: false).init();
    });
  }

  // Convert solar data to chart data points
  List<FlSpot> _getVoltageChartData(List<SolarData> data) {
    if (data.isEmpty) return [];
    
    final List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].voltage));
    }
    return spots;
  }

  List<FlSpot> _getCurrentChartData(List<SolarData> data) {
    if (data.isEmpty) return [];
    
    final List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].current));
    }
    return spots;
  }

  List<FlSpot> _getPowerChartData(List<SolarData> data) {
    if (data.isEmpty) return [];
    
    final List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].power));
    }
    return spots;
  }

  LineChartData _createLineChartData(List<FlSpot> spots, String title, Color color) {
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
          ),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade300),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: color.withAlpha(50),
          ),
          dotData: FlDotData(show: false),
        ),
      ],
    );
  }

  void _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _navigateToNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    final latest = solarProvider.latestData;
    final v = latest?.voltage;
    final i = latest?.current;
    final p = latest?.power;
    final eWh = latest?.energy;
    final recTs = latest?.timestamp.millisecondsSinceEpoch;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'PLTS Dashboard',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: _navigateToNotifications,
          ),
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _logout,
          ),
            const SizedBox(width: 8),
        ],
        ),
      ),
      body: solarProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Device:${solarProvider.currentDeviceId ?? '-'} | Data:${solarProvider.solarData.length}\n'
                      'V:${v?.toStringAsFixed(2) ?? '--'} (ts:${recTs ?? '-'}) | '
                      'I:${i?.toStringAsFixed(2) ?? '--'} (ts:${recTs ?? '-'}) | '
                      'P:${p?.toStringAsFixed(2) ?? '--'} (ts:${recTs ?? '-'}) | '
                      'E:${eWh != null ? (eWh / 1000).toStringAsFixed(2) : '--'} kWh (ts:${recTs ?? '-'})',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                  // System Status
                    Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    child: Row(
                      children: [
                        const Text(
                          'System Status:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        const Text('NORMAL', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  // 4 Info Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniInfoCard(
                        value: v != null ? v.toStringAsFixed(2) : '--',
                        label: 'Tegangan',
                        unit: 'V',
                        color: Colors.blue,
                      ),
                      _miniInfoCard(
                        value: i != null ? i.toStringAsFixed(2) : '--',
                        label: 'Arus',
                        unit: 'A',
                        color: Colors.orange,
                          ),
                        ],
                      ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniInfoCard(
                        value: p != null ? p.toStringAsFixed(2) : '--',
                        label: 'Daya',
                        unit: 'W',
                        color: Colors.green,
                      ),
                      _miniInfoCard(
                        value: eWh != null ? (eWh / 1000).toStringAsFixed(2) : '--',
                        label: 'Energi',
                        unit: 'kWh',
                        color: Colors.purple,
                          ),
                        ],
                      ),
                  const SizedBox(height: 28),
                  // View Details & Analitik
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const HistoryScreen()),
                            );
                          },
                          child: const Text('Riwayat', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                            );
                          },
                          child: const Text('Analitik', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PltsMonitoringScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Real-time',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
  
  Widget _miniInfoCard({
    required String value,
    required String label,
    required String unit,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
} 