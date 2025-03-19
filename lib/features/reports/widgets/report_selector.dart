import 'package:flutter/material.dart';

class ReportSelector extends StatelessWidget {
  final List<String> reports;
  final String selectedReport;
  final Function(String) onReportChanged;

  const ReportSelector({
    Key? key,
    required this.reports,
    required this.selectedReport,
    required this.onReportChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Reporte',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          value: selectedReport,
          items: reports.map((String report) {
            return DropdownMenuItem<String>(
              value: report,
              child: Text(report),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onReportChanged(newValue);
            }
          },
        ),
      ],
    );
  }
}