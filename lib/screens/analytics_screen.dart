import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/solar_provider.dart';
import '../models/solar_data.dart';

/// Periode filter untuk analitik
enum AnalyticsPeriod { today, last7, last30 }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.last7;

  List<SolarData> _filterByPeriod(List<SolarData> data) {
    final now = DateTime.now();
    DateTime start;
    switch (_period) {
      case AnalyticsPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case AnalyticsPeriod.last7:
        start = now.subtract(const Duration(days: 7));
        break;
      case AnalyticsPeriod.last30:
        start = now.subtract(const Duration(days: 30));
        break;
    }
    return data.where((d) => d.timestamp.isAfter(start) || d.timestamp.isAtSameMomentAs(start)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Kelompokkan per hari untuk drill-down
  Map<DateTime, List<SolarData>> _groupByDay(List<SolarData> data) {
    final map = <DateTime, List<SolarData>>{};
    for (final d in data) {
      final day = DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day);
      map.putIfAbsent(day, () => []).add(d);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }

  /// Peramalan sederhana: moving average untuk N titik berikutnya
  List<double> _forecast(List<double> series, int count, {int window = 5}) {
    if (series.isEmpty) return [];
    final result = <double>[];
    var extended = List<double>.from(series);
    for (var i = 0; i < count; i++) {
      final start = (extended.length - window).clamp(0, extended.length);
      final slice = extended.sublist(start);
      final next = slice.isEmpty ? extended.last : slice.reduce((a, b) => a + b) / slice.length;
      result.add(next);
      extended = [...extended, next];
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    final allData = solarProvider.solarData;
    final data = _filterByPeriod(allData);
    final byDay = _groupByDay(data);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Dashboard Analitik',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: solarProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Periode
                const Text('Periode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                SegmentedButton<AnalyticsPeriod>(
                  segments: const [
                    ButtonSegment(value: AnalyticsPeriod.today, label: Text('Hari ini')),
                    ButtonSegment(value: AnalyticsPeriod.last7, label: Text('7 Hari')),
                    ButtonSegment(value: AnalyticsPeriod.last30, label: Text('30 Hari')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),
                const SizedBox(height: 20),
                // Summary cards
                _buildSummaryCards(data),
                const SizedBox(height: 20),
                // Peramalan
                _buildForecastSection(data),
                const SizedBox(height: 20),
                // Drill-down: per hari
                const Text('Drill-down per Hari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...byDay.entries.map((e) => _buildDayTile(context, e.key, e.value, solarProvider)),
                const SizedBox(height: 20),
                // Ekspor
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Ekspor CSV'),
                        onPressed: () => solarProvider.exportDataToCSV(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Ekspor PDF'),
                        onPressed: () => solarProvider.exportDataToPDF(title: 'Laporan Analitik PLTS'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCards(List<SolarData> data) {
    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Belum ada data untuk periode ini')),
        ),
      );
    }
    final v = data.map((e) => e.voltage).toList();
    final c = data.map((e) => e.current).toList();
    final p = data.map((e) => e.power).toList();
    final e = data.map((e) => e.energy ?? 0.0).toList();
    double avg(Iterable<double> x) => x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;
    double min(Iterable<double> x) => x.isEmpty ? 0 : x.reduce((a, b) => a < b ? a : b);
    double max(Iterable<double> x) => x.isEmpty ? 0 : x.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _summaryTile('Tegangan (V)', avg(v), min(v), max(v), Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _summaryTile('Arus (A)', avg(c), min(c), max(c), Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _summaryTile('Daya (W)', avg(p), min(p), max(p), Colors.green)),
                Expanded(
                  child: _summaryTile(
                    'Energi (Wh)',
                    e.isEmpty ? 0 : e.reduce((a, b) => a + b),
                    min(e),
                    max(e),
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, double avg, double min, double max, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Rata: ${avg.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
          Text('Min: ${min.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
          Text('Maks: ${max.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildForecastSection(List<SolarData> data) {
    if (data.length < 3) return const SizedBox.shrink();
    final powerSeries = data.map((e) => e.power).toList();
    final forecast = _forecast(List.from(powerSeries), 7, window: 5);
    final spots = [
      ...powerSeries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)),
      ...forecast.asMap().entries.map((e) => FlSpot((powerSeries.length + e.key).toDouble(), e.value)),
    ];
    final maxY = (powerSeries.isEmpty ? 0.0 : powerSeries.reduce((a, b) => a > b ? a : b)) * 1.1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Peramalan Daya (Moving Average)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (powerSeries.length + forecast.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY > 0 ? maxY : 100,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.take(powerSeries.length).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: spots.skip(powerSeries.length).toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: Colors.orange)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Garis oranye: peramalan 7 titik berikutnya', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTile(BuildContext context, DateTime day, List<SolarData> dayData, SolarProvider solarProvider) {
    final dateFormat = DateFormat('EEEE, d MMM yyyy', 'id');
    final v = dayData.map((e) => e.voltage).reduce((a, b) => a + b) / dayData.length;
    final p = dayData.map((e) => e.power).reduce((a, b) => a + b) / dayData.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(dateFormat.format(day)),
        subtitle: Text('${dayData.length} titik • Rata tegangan: ${v.toStringAsFixed(2)} V • Rata daya: ${p.toStringAsFixed(2)} W'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _DrillDownDetailScreen(day: day, data: dayData, solarProvider: solarProvider),
            ),
          );
        },
      ),
    );
  }
}

/// Halaman detail drill-down untuk satu hari
class _DrillDownDetailScreen extends StatelessWidget {
  final DateTime day;
  final List<SolarData> data;
  final SolarProvider solarProvider;

  const _DrillDownDetailScreen({required this.day, required this.data, required this.solarProvider});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy', 'id');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text('Detail ${dateFormat.format(day)}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Ekspor data hari ini', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.table_chart, size: 20),
                          label: const Text('CSV'),
                          onPressed: () => solarProvider.exportDataToCSVWith(data),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text('PDF'),
                          onPressed: () => solarProvider.exportDataToPDFWith(data, title: 'Laporan PLTS ${dateFormat.format(day)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...data.map((d) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(timeFormat.format(d.timestamp)),
              subtitle: Text('Tegangan: ${d.voltage.toStringAsFixed(2)} V • Arus: ${d.current.toStringAsFixed(2)} A • Daya: ${d.power.toStringAsFixed(2)} W'),
            ),
          )),
        ],
      ),
    );
  }
}
