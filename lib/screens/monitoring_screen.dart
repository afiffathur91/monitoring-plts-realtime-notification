import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/solar_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    final latest = solarProvider.latestData;
    final lastUpdate = latest?.timestamp;
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
            'Real-time Monitoring',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
      ),
      body: solarProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System Status
                  Container(
                    padding: const EdgeInsets.all(16),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 12),
                              const SizedBox(width: 8),
                              const Text(
                                'NORMAL',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Last Update
                  Text(
                    'Last Update: ${lastUpdate != null ? _formatTime(lastUpdate) : '--:--:--'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  // Voltage Chart
                  Container(
                    width: double.infinity,
                    height: 180,
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
                    child: solarProvider.voltageData.isEmpty
                        ? const Center(child: Text('Grafik Tegangan', style: TextStyle(color: Colors.blueGrey)))
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      for (int i = 0; i < solarProvider.voltageData.length; i++)
                                        FlSpot(i.toDouble(), solarProvider.voltageData[i].voltage),
                                    ],
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    belowBarData: BarAreaData(show: true, color: Colors.blue.withAlpha(50)),
                                    dotData: FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  // Current & Power
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _infoText('Arus', latest?.current.toStringAsFixed(2) ?? '--', 'A'),
                      _infoText('Daya', latest?.power.toStringAsFixed(2) ?? '--', 'W'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Power Trend Chart
                  Container(
                    width: double.infinity,
                    height: 140,
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
                    child: solarProvider.powerData.isEmpty
                        ? const Center(child: Text('Grafik Daya', style: TextStyle(color: Colors.blueGrey)))
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      for (int i = 0; i < solarProvider.powerData.length; i++)
                                        FlSpot(i.toDouble(), solarProvider.powerData[i].power),
                                    ],
                                    isCurved: true,
                                    color: Colors.green,
                                    barWidth: 3,
                                    belowBarData: BarAreaData(show: true, color: Colors.green.withAlpha(50)),
                                    dotData: FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  // Daily Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryItem('Tegangan Puncak', solarProvider.voltageData.isEmpty ? '--' : '${solarProvider.voltageData.map((d) => d.voltage).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} V'),
                            _summaryItem('Arus Puncak', solarProvider.currentData.isEmpty ? '--' : '${solarProvider.currentData.map((d) => d.current).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} A'),
                            _summaryItem('Daya Puncak', solarProvider.powerData.isEmpty ? '--' : '${solarProvider.powerData.map((d) => d.power).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} W'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Export/Share Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final solarProvider = Provider.of<SolarProvider>(context, listen: false);
                        solarProvider.exportDataToCSV();
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Export CSV/Share'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}' ;
  }

  Widget _infoText(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
} 