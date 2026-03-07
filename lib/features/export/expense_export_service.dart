import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../expense/models/expense.dart';

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

    // Get temp directory
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/expenses.csv";

    // Write CSV file
    final file = File(path);
    await file.writeAsString(csv);

    // Share CSV file
    await Share.shareXFiles([XFile(path)], text: "Expense Export");
  }
}
