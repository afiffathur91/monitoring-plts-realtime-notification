import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/solar_provider.dart';
import '../models/solar_data.dart';

/// Filter rentang tanggal untuk daftar history dan ringkasan.
enum _HistoryRange {
  today,
  yesterday,
  last7,
  last30,
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryRange _range = _HistoryRange.last7;

  static const Map<_HistoryRange, String> _rangeLabels = {
    _HistoryRange.today: 'Hari ini',
    _HistoryRange.yesterday: 'Kemarin',
    _HistoryRange.last7: '7 hari terakhir',
    _HistoryRange.last30: '30 hari terakhir',
  };

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Data dalam rentang filter, diurutkan dari terbaru (untuk daftar kartu).
  List<SolarData> _filterData(List<SolarData> all, _HistoryRange range) {
    if (all.isEmpty) return [];
    final now = DateTime.now();
    final todayStart = _startOfDay(now);
    DateTime start;
    DateTime? end;
    final isYesterday = range == _HistoryRange.yesterday;

    switch (range) {
      case _HistoryRange.today:
        start = todayStart;
        end = now;
        break;
      case _HistoryRange.yesterday:
        start = todayStart.subtract(const Duration(days: 1));
        end = todayStart;
        break;
      case _HistoryRange.last7:
        start = todayStart.subtract(const Duration(days: 6));
        end = null;
        break;
      case _HistoryRange.last30:
        start = todayStart.subtract(const Duration(days: 29));
        end = null;
        break;
    }

    final filtered = all.where((d) {
      final t = d.timestamp;
      if (t.isBefore(start)) return false;
      // Hari ini: sampai sekarang. Kemarin: sampai sebelum tengah malam hari ini.
      if (end != null) {
        if (isYesterday) {
          if (!t.isBefore(end)) return false;
        } else {
          if (t.isAfter(end)) return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  /// Agregat per hari kalender (lokal) untuk grafik: rata-rata daya (W).
  List<({DateTime day, double avgPower, int count})> _dailyAggregates(
    List<SolarData> all,
    int maxDays,
  ) {
    if (all.isEmpty) return [];
    final now = DateTime.now();
    final todayStart = _startOfDay(now);
    final cutoff = todayStart.subtract(Duration(days: maxDays - 1));

    final byDay = <DateTime, List<SolarData>>{};
    for (final d in all) {
      final day = _startOfDay(d.timestamp);
      if (day.isBefore(cutoff)) continue;
      byDay.putIfAbsent(day, () => []).add(d);
    }

    final keys = byDay.keys.toList()..sort();
    return keys.map((day) {
      final pts = byDay[day]!;
      final sumP = pts.fold<double>(0, (s, e) => s + e.power);
      return (day: day, avgPower: sumP / pts.length, count: pts.length);
    }).toList();
  }

  /// Selisih energi meter (Wh) dari pembacaan **pertama → terakhir** menurut waktu
  /// dalam kumpulan titik (cocok untuk meter PZEM kumulatif).
  double? _energyDeltaKwh(List<SolarData> points) {
    if (points.length < 2) return null;
    final withEnergy = points.where((e) => e.energy != null).toList();
    if (withEnergy.length < 2) return null;
    withEnergy.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final first = withEnergy.first.energy!;
    final last = withEnergy.last.energy!;
    final deltaWh = last - first;
    if (deltaWh < -1e-6) return null;
    return deltaWh / 1000.0;
  }

  /// Delta Wh antar sampel berurutan (kronologis) di dalam [anyOrder].
  Map<SolarData, double?> _deltaEnergySincePreviousWh(List<SolarData> anyOrder) {
    if (anyOrder.isEmpty) return {};
    final asc = List<SolarData>.from(anyOrder)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final map = <SolarData, double?>{};
    for (var i = 0; i < asc.length; i++) {
      if (i == 0) {
        map[asc[i]] = null;
        continue;
      }
      final e0 = asc[i - 1].energy;
      final e1 = asc[i].energy;
      map[asc[i]] = (e0 != null && e1 != null) ? (e1 - e0) : null;
    }
    return map;
  }

  Iterable<Widget> _buildHistoryListByDay(
    BuildContext context,
    List<SolarData> filteredDesc,
    Map<SolarData, double?> deltaSincePrevWh,
  ) sync* {
    final byDay = <DateTime, List<SolarData>>{};
    for (final d in filteredDesc) {
      final day = _startOfDay(d.timestamp);
      byDay.putIfAbsent(day, () => []).add(d);
    }
    final dayFmt = DateFormat('EEEE, d MMMM yyyy', 'id');
    final sortedDays = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final day in sortedDays) {
      final pts = byDay[day]!..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      yield Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: Colors.deepPurple.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dayFmt.format(day),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
            Text('${pts.length} titik', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      );
      for (final p in pts) {
        yield _buildHistoryCard(context, p, deltaWhSincePrevious: deltaSincePrevWh[p]);
      }
    }
  }

  Widget _buildDailySummary(List<SolarData> all) {
    final now = DateTime.now();
    final todayStart = _startOfDay(now);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final todayPts = all.where((d) => !d.timestamp.isBefore(todayStart)).toList();
    final yestPts = all
        .where((d) =>
            !d.timestamp.isBefore(yesterdayStart) && d.timestamp.isBefore(todayStart))
        .toList();
    final weekPts = all.where((d) => !d.timestamp.isBefore(weekStart)).toList();

    final todayKwh = _energyDeltaKwh(todayPts);
    final yestKwh = _energyDeltaKwh(yestPts);
    double? weekKwh;
    if (weekPts.length >= 2) {
      final sorted = List<SolarData>.from(weekPts)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      weekKwh = _energyDeltaKwh(sorted);
    }

    String fmtKwh(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} kWh';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan harian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Text('Hari ini:    ${fmtKwh(todayKwh)} (${todayPts.length} titik)'),
        Text('Kemarin:     ${fmtKwh(yestKwh)} (${yestPts.length} titik)'),
        Text('7 hari ini:  ${fmtKwh(weekKwh)} (${weekPts.length} titik)'),
        const SizedBox(height: 10),
        Text(
          'Angka kWh = selisih meter pertama–terakhir di periode itu (sensor PZEM: energi kumulatif, tidak reset tiap hari).',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildWeeklyTrendChart(List<SolarData> all) {
    final daily = _dailyAggregates(all, 7);
    if (daily.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Belum cukup data untuk grafik tren', style: TextStyle(color: Colors.blueGrey)),
        ),
      );
    }

    final maxP = daily.map((e) => e.avgPower).reduce((a, b) => a > b ? a : b);
    final minP = daily.map((e) => e.avgPower).reduce((a, b) => a < b ? a : b);
    final pad = (maxP - minP).abs() < 1e-6 ? 1.0 : (maxP - minP) * 0.15;
    final yMax = maxP + pad;
    final yMin = (minP - pad).clamp(0.0, double.infinity);
    final ySpan = (yMax - yMin).abs() < 1e-9 ? 1.0 : (yMax - yMin);
    final leftInterval = math.max(ySpan / 4, 1e-6);
    final decimals = ySpan < 2 ? 2 : (ySpan < 12 ? 1 : 0);

    final dayFmt = DateFormat('E', 'id');

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: yMax,
          minY: yMin,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: leftInterval,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= daily.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dayFmt.format(daily[i].day),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: leftInterval,
                getTitlesWidget: (value, meta) {
                  if (value < yMin - 1e-6 || value > yMax + 1e-6) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      value.toStringAsFixed(decimals),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            daily.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: daily[i].avgPower,
                  color: Colors.deepPurple,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    final allData = solarProvider.solarData;
    final filteredData = _filterData(allData, _range);

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
            'Data History',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
      ),
      body: solarProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Text('Filter:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<_HistoryRange>(
                        isExpanded: true,
                        value: _range,
                        items: _rangeLabels.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _range = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${filteredData.length} data dalam rentang "${_rangeLabels[_range]}"',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aplikasi memuat maks. ${SolarProvider.historyDataLimit} titik terakhir dari Firebase. '
                  'Titik lama hilang dari daftar (bukan dihapus server) bila sudah di luar jendela ini — '
                  'filter "Kemarin" bisa kosong meski data lama masih ada di database.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
                ),
                const SizedBox(height: 20),
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
                  child: _buildDailySummary(allData),
                ),
                const SizedBox(height: 20),
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
                        'Tren mingguan (rata-rata daya / hari)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '7 hari kalender terakhir dari seluruh data',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      _buildWeeklyTrendChart(allData),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: filteredData.isEmpty
                            ? null
                            : () {
                                Provider.of<SolarProvider>(context, listen: false)
                                    .exportDataToCSVWith(filteredData);
                              },
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Ekspor data'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: filteredData.isEmpty
                            ? null
                            : () {
                                Provider.of<SolarProvider>(context, listen: false).exportDataToPDFWith(
                                      filteredData,
                                      title: 'Riwayat PLTS — ${_rangeLabels[_range]}',
                                    );
                              },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Ekspor PDF'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (filteredData.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Tidak ada data di rentang ini', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ..._buildHistoryListByDay(
                    context,
                    filteredData,
                    _deltaEnergySincePreviousWh(filteredData),
                  ),
              ],
            ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    SolarData data, {
    double? deltaWhSincePrevious,
  }) {
    final timeFormat = DateFormat('MMM d, yyyy - h:mm a');
    final formattedTime = timeFormat.format(data.timestamp);

    String? energiExtra;
    if (data.energy != null) {
      if (deltaWhSincePrevious == null) {
        energiExtra = 'Sampel pertama (kronologis) di rentang';
      } else if (deltaWhSincePrevious > 1e-9) {
        energiExtra = '+${deltaWhSincePrevious.toStringAsFixed(2)} Wh vs titik sebelumnya';
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDataColumn(
                  label: 'Tegangan',
                  value: '${data.voltage.toStringAsFixed(2)} V',
                  icon: Icons.electric_bolt,
                  color: Colors.blue,
                ),
                _buildDataColumn(
                  label: 'Arus',
                  value: '${data.current.toStringAsFixed(2)} A',
                  icon: Icons.electrical_services,
                  color: Colors.orange,
                ),
                _buildDataColumn(
                  label: 'Daya',
                  value: '${data.power.toStringAsFixed(2)} W',
                  icon: Icons.power,
                  color: Colors.green,
                ),
                _buildDataColumn(
                  label: 'Energi (kum.)',
                  value: data.energy != null ? '${(data.energy! / 1000).toStringAsFixed(2)} kWh' : '--',
                  icon: Icons.bolt,
                  color: Colors.purple,
                  extraLine: energiExtra,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? extraLine,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (extraLine != null) ...[
            const SizedBox(height: 4),
            Text(
              extraLine,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600, height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
