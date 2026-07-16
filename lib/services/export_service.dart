import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/solar_data.dart';

class ExportService {
  Future<void> exportAndShareCSV(List<SolarData> data) async {
    // Convert data to CSV format
    List<List<dynamic>> csvData = [
      // Header
      ['Tanggal', 'Waktu', 'Tegangan (V)', 'Arus (A)', 'Daya (W)', 'Energi (Wh)'],
      // Data rows
      ...data.map((item) => [
            item.timestamp.toString().split(' ')[0], // Tanggal
            item.timestamp.toString().split(' ')[1], // Waktu
            item.voltage.toStringAsFixed(2),
            item.current.toStringAsFixed(2),
            item.power.toStringAsFixed(2),
            item.energy?.toStringAsFixed(2) ?? '--',
          ]),
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    
    // Get temporary directory to save the file
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/solar_data_${DateTime.now().millisecondsSinceEpoch}.csv');
    
    // Write to file
    await file.writeAsString(csv);
    
    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Export Data PLTS',
    );
  }

  /// Ekspor data ke PDF dan share.
  Future<void> exportAndSharePDF(List<SolarData> data, {String title = 'Laporan Data PLTS'}) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        footer: (ctx) => pw.Text(
          'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        build: (ctx) => [
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('Tanggal / Waktu'),
                  _cell('Tegangan (V)'),
                  _cell('Arus (A)'),
                  _cell('Daya (W)'),
                  _cell('Energi (Wh)'),
                  _cell('Keterangan'),
                ],
              ),
              ...data.map((d) => pw.TableRow(
                children: [
                  _cell(dateFormat.format(d.timestamp)),
                  _cell(d.voltage.toStringAsFixed(2)),
                  _cell(d.current.toStringAsFixed(2)),
                  _cell(d.power.toStringAsFixed(2)),
                  _cell(d.energy?.toStringAsFixed(2) ?? '--'),
                  _cell(''),
                ],
              )),
            ],
          ),
        ],
      ),
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/plts_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan PLTS PDF');
  }
}

pw.Widget _cell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );
}