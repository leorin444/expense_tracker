import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../expense/models/expense.dart';
import 'package:universal_html/html.dart' as html;

class ExportService {
  /// Exports a list of expenses to CSV and shares it
  static Future<void> exportToCSV(List<Expense> expenses) async {
    if (expenses.isEmpty) return;

    // Prepare CSV rows
    List<List<dynamic>> rows = [];

    // Header
    rows.add(["Title", "Category", "Amount", "Date"]);

    // Data rows
    for (var e in expenses) {
      rows.add([
        e.title,
        e.category,
        e.amount.toStringAsFixed(2),
        "${e.date.day}/${e.date.month}/${e.date.year}",
      ]);
    }

    // Convert to CSV string
    String csv = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      // For web, download the file
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'expenses_${DateTime.now().millisecondsSinceEpoch}.csv',
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // For mobile/desktop, save to documents and share
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'expenses_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = path.join(directory.path, fileName);

      // Write CSV file
      final file = File(filePath);
      await file.writeAsString(csv);

      // Try to share
      try {
        await Share.shareXFiles([XFile(filePath)], text: "Expense Export");
      } catch (e) {
        // On platforms where sharing doesn't work, the file is saved
      }
    }
  }
}
