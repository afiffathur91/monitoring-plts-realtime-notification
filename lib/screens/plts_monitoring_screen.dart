import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/solar_provider.dart';
import '../models/solar_data.dart';

enum TimeRange { live, m15, m30, h6, d1, w1, m1 }

class PltsMonitoringScreen extends StatefulWidget {
  const PltsMonitoringScreen({super.key});

  @override
  State<PltsMonitoringScreen> createState() => _PltsMonitoringScreenState();
}

class _PltsMonitoringScreenState extends State<PltsMonitoringScreen> {
  TimeRange _selectedTimeRange = TimeRange.live;

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    final latest = solarProvider.latestData;
    final latestV = latest?.voltage;
    final latestI = latest?.current;
    final latestP = latest?.power;
    final latestEWh = latest?.energy;
    final recTs = latest?.timestamp.millisecondsSinceEpoch;

    // Get filtered data based on time range
    final filteredData = _getFilteredData(solarProvider.solarData, _selectedTimeRange);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
            onPressed: () {
              // Navigate to settings
            },
          ),
          IconButton(
            icon: const Icon(Icons.apps, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                'V:${latestV?.toStringAsFixed(2) ?? '--'} (ts:${recTs ?? '-'}) | '
                'I:${latestI?.toStringAsFixed(2) ?? '--'} (ts:${recTs ?? '-'})\n'
                'P:${latestP?.toStringAsFixed(2) ?? '--'} (ts:${recTs ?? '-'}) | '
                'E:${latestEWh != null ? (latestEWh / 1000).toStringAsFixed(2) : '--'} kWh (ts:${recTs ?? '-'})',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
            // Title with online indicator
            Row(
              children: [
                const Text(
                  'monitoring pjuts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4 Metric Cards: Tegangan, Arus, Daya, Energi
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Tegangan',
                    latestV != null ? _formatValue(latestV) : '--',
                    'V',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Arus',
                    latestI != null ? _formatValue(latestI) : '--',
                    'A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Daya',
                    latestP != null ? _formatValue(latestP) : '--',
                    'W',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Energi',
                    latestEWh != null ? '${(latestEWh / 1000).toStringAsFixed(2)}' : '--',
                    'kWh',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Graph Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Graph Title
                  Row(
                    children: [
                      const Icon(Icons.show_chart, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Tegangan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        latestV != null ? _formatValue(latestV) : '--',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Graph
                  SizedBox(
                    height: 200,
                    child: filteredData.isEmpty
                        ? const Center(
                            child: Text(
                              'No data available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : BarChart(
                            _buildBarChartData(filteredData),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Time Range Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTimeRangeButton('Live', TimeRange.live),
                        const SizedBox(width: 8),
                        _buildTimeRangeButton('15M', TimeRange.m15),
                        const SizedBox(width: 8),
                        _buildTimeRangeButton('30M', TimeRange.m30),
                        const SizedBox(width: 8),
                        _buildTimeRangeButton('6H', TimeRange.h6),
                        const SizedBox(width: 8),
                        _buildTimeRangeButton('1D', TimeRange.d1),
                        const SizedBox(width: 8),
                        _buildTimeRangeButton('1W', TimeRange.w1),
                        const SizedBox(width: 8),
                        _buildTimeRangeButton('1M', TimeRange.m1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: '^$unit',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String label, TimeRange range) {
    final isSelected = _selectedTimeRange == range;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeRange = range;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  BarChartData _buildBarChartData(List<SolarData> data) {
    if (data.isEmpty) {
      return BarChartData();
    }

    // Find min and max for Y-axis using PV voltage
    final values = data.map((d) => d.voltagePV ?? d.voltage).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;

    // Guard against flat-line data (range == 0) which would make grid interval 0 and crash fl_chart.
    // Ensure yMax > yMin and interval > 0.
    final double padding = range == 0 ? (maxValue.abs() * 0.05 + 0.1) : range * 0.1;
    final yMin = (minValue - padding).clamp(0.0, double.infinity);
    final yMax = maxValue + padding;

    // Create detailed Y-axis labels
    final yAxisSteps = 10;
    final rawStep = (yMax - yMin) / yAxisSteps;
    final step = rawStep == 0 ? 0.1 : rawStep;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: yMax,
      minY: yMin,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: step,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            interval: step,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value.toStringAsFixed(3),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 10,
                  ),
                ),
              );
            },
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
        show: false,
      ),
      barGroups: List.generate(
        data.length,
        (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: data[index].voltagePV ?? data[index].voltage,
              color: Colors.purple,
              width: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SolarData> _getFilteredData(List<SolarData> allData, TimeRange range) {
    if (allData.isEmpty) return [];
    if (range == TimeRange.live) {
      // Return last 50 data points for live view
      return allData.length > 50 ? allData.sublist(allData.length - 50) : allData;
    }

    final now = DateTime.now();
    DateTime cutoff;

    switch (range) {
      case TimeRange.m15:
        cutoff = now.subtract(const Duration(minutes: 15));
        break;
      case TimeRange.m30:
        cutoff = now.subtract(const Duration(minutes: 30));
        break;
      case TimeRange.h6:
        cutoff = now.subtract(const Duration(hours: 6));
        break;
      case TimeRange.d1:
        cutoff = now.subtract(const Duration(days: 1));
        break;
      case TimeRange.w1:
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case TimeRange.m1:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      default:
        return allData;
    }

    return allData.where((data) => data.timestamp.isAfter(cutoff)).toList();
  }

  String _formatValue(double value) {
    // Format with comma as decimal separator if needed
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}
