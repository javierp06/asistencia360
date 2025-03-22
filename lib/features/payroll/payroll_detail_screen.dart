import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/payroll.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';

class PayrollDetailScreen extends StatelessWidget {
  final Payroll payroll;

  const PayrollDetailScreen({Key? key, required this.payroll})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_HN',
      symbol: 'L',
      decimalDigits: 2,
    );
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Nómina'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir PDF',
            onPressed: () => _printPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar PDF',
            onPressed: () => _downloadPdf(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey.shade900, Colors.grey.shade800]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con información general
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.receipt_long,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nómina',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  payroll.periodo,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Procesado',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            context,
                            'Fecha de Generación',
                            DateFormat('dd/MM/yyyy').format(payroll.fechaGeneracion),
                            Icons.calendar_today,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            'Empleado',
                            payroll.empleadoNombre,
                            Icons.person,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            'ID de Nómina',
                            payroll.id,
                            Icons.numbers,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Desglose de Salario
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Desglose de Salario',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1),
                      _buildSalaryRow(
                        context,
                        'Salario Base',
                        payroll.salarioBruto - payroll.horasExtra - payroll.bonificaciones,
                        currencyFormat,
                      ),
                      _buildSalaryRow(
                        context,
                        'Horas Extra',
                        payroll.horasExtra,
                        currencyFormat,
                      ),
                      _buildSalaryRow(
                        context,
                        'Bonificaciones',
                        payroll.bonificaciones,
                        currencyFormat,
                      ),
                      const Divider(height: 24),
                      _buildSalaryRow(
                        context,
                        'Salario Bruto',
                        payroll.salarioBruto,
                        currencyFormat,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Deducciones
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.remove_circle_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Deducciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1),
                      _buildSalaryRow(
                        context,
                        'RAP (4%)',
                        payroll.deduccionRap,
                        currencyFormat,
                        isNegative: true,
                      ),
                      _buildSalaryRow(
                        context,
                        'IHSS (2.5%)',
                        payroll.deduccionIhss,
                        currencyFormat,
                        isNegative: true,
                      ),
                      const Divider(height: 24),
                      _buildSalaryRow(
                        context,
                        'Total Deducciones',
                        payroll.deduccionRap + payroll.deduccionIhss,
                        currencyFormat,
                        isNegative: true,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Salario Neto
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.green.shade900 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade400, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.green.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Salario Neto:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      currencyFormat.format(payroll.salarioNeto),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                    onPressed: () => _printPdf(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar PDF'),
                    onPressed: () => _downloadPdf(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context,String label, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary.withOpacity(0.7), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryRow(
     BuildContext context,
    String label,
    double amount,
    NumberFormat formatter, {
    bool isNegative = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            isNegative
                ? '- ${formatter.format(amount)}'
                : formatter.format(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printPdf(BuildContext context) async {
    // Show loading indicator
    final scaffold = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Use built-in fonts
      final ttf = pw.Font.helvetica();
      final ttfBold = pw.Font.helveticaBold();

      // Number formatter
      final currencyFormat = NumberFormat.currency(
        locale: 'es_HN',
        symbol: 'L',
        decimalDigits: 2,
      );

      // Add page to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with company logo and info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOURIST OPTION',
                          style: pw.TextStyle(font: ttfBold, fontSize: 18),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Recibo de Nómina',
                          style: pw.TextStyle(font: ttf, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      child: pw.Text(
                        'CONFIDENCIAL',
                        style: pw.TextStyle(font: ttfBold),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // General Information section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Información General',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfInfoRow('Período', payroll.periodo, ttf),
                      _buildPdfInfoRow(
                        'Fecha de Generación',
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(payroll.fechaGeneracion),
                        ttf,
                      ),
                      _buildPdfInfoRow('Empleado', payroll.empleadoNombre, ttf),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Salary Breakdown section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Desglose de Salario',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'Salario Base',
                        payroll.salarioBruto -
                            payroll.horasExtra -
                            payroll.bonificaciones,
                        currencyFormat,
                        ttf,
                      ),
                      _buildPdfSalaryRow(
                        'Horas Extra',
                        payroll.horasExtra,
                        currencyFormat,
                        ttf,
                      ),
                      _buildPdfSalaryRow(
                        'Bonificaciones',
                        payroll.bonificaciones,
                        currencyFormat,
                        ttf,
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'Salario Bruto',
                        payroll.salarioBruto,
                        currencyFormat,
                        ttfBold,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Deductions section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Deducciones',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'RAP (4%)',
                        payroll.deduccionRap,
                        currencyFormat,
                        ttf,
                        isNegative: true,
                      ),
                      _buildPdfSalaryRow(
                        'IHSS (2.5%)',
                        payroll.deduccionIhss,
                        currencyFormat,
                        ttf,
                        isNegative: true,
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'Total Deducciones',
                        payroll.deduccionRap + payroll.deduccionIhss,
                        currencyFormat,
                        ttfBold,
                        isNegative: true,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Net Salary section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Salario Neto:',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Text(
                        currencyFormat.format(payroll.salarioNeto),
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 14,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Signature section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Divider(),
                          pw.Text(
                            'Firma del Empleado',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Divider(),
                          pw.Text(
                            'Firma del Empleador',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Documento generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar el PDF directamente sin guardar archivo
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Nómina - ${payroll.periodo}',
      );

      scaffold.showSnackBar(
        const SnackBar(content: Text('PDF generado con éxito')),
      );
    } catch (e) {
      // Close the loading dialog
      Navigator.pop(context);

      scaffold.showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    }
  }

  // Helper methods for PDF generation
  pw.Widget _buildPdfInfoRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, color: PdfColors.grey700),
          ),
          pw.Text(value, style: pw.TextStyle(font: font)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSalaryRow(
    String label,
    double amount,
    NumberFormat formatter,
    pw.Font font, {
    bool isNegative = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font)),
          pw.Text(
            isNegative
                ? '- ${formatter.format(amount)}'
                : formatter.format(amount),
            style: pw.TextStyle(
              font: font,
              color: isNegative ? PdfColors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Use built-in fonts
      final ttf = pw.Font.helvetica();
      final ttfBold = pw.Font.helveticaBold();

      // Number formatter
      final currencyFormat = NumberFormat.currency(
        locale: 'es_HN',
        symbol: 'L',
        decimalDigits: 2,
      );

      // Add page to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with company logo and info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TOURIST OPTION',
                          style: pw.TextStyle(font: ttfBold, fontSize: 18),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Recibo de Nómina',
                          style: pw.TextStyle(font: ttf, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      child: pw.Text(
                        'CONFIDENCIAL',
                        style: pw.TextStyle(font: ttfBold),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // General Information section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Información General',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfInfoRow('Período', payroll.periodo, ttf),
                      _buildPdfInfoRow(
                        'Fecha de Generación',
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(payroll.fechaGeneracion),
                        ttf,
                      ),
                      _buildPdfInfoRow('Empleado', payroll.empleadoNombre, ttf),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Salary Breakdown section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Desglose de Salario',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'Salario Base',
                        payroll.salarioBruto -
                            payroll.horasExtra -
                            payroll.bonificaciones,
                        currencyFormat,
                        ttf,
                      ),
                      _buildPdfSalaryRow(
                        'Horas Extra',
                        payroll.horasExtra,
                        currencyFormat,
                        ttf,
                      ),
                      _buildPdfSalaryRow(
                        'Bonificaciones',
                        payroll.bonificaciones,
                        currencyFormat,
                        ttf,
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'Salario Bruto',
                        payroll.salarioBruto,
                        currencyFormat,
                        ttfBold,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Deductions section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Deducciones',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'RAP (4%)',
                        payroll.deduccionRap,
                        currencyFormat,
                        ttf,
                        isNegative: true,
                      ),
                      _buildPdfSalaryRow(
                        'IHSS (2.5%)',
                        payroll.deduccionIhss,
                        currencyFormat,
                        ttf,
                        isNegative: true,
                      ),
                      pw.Divider(),
                      _buildPdfSalaryRow(
                        'Total Deducciones',
                        payroll.deduccionRap + payroll.deduccionIhss,
                        currencyFormat,
                        ttfBold,
                        isNegative: true,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Net Salary section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Salario Neto:',
                        style: pw.TextStyle(font: ttfBold, fontSize: 14),
                      ),
                      pw.Text(
                        currencyFormat.format(payroll.salarioNeto),
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 14,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Signature section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Divider(),
                          pw.Text(
                            'Firma del Empleado',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Divider(),
                          pw.Text(
                            'Firma del Empleador',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Documento generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Generar el PDF como bytes
      final bytes = await pdf.save();

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // CAMBIAR ESTA PARTE: usar FileSaver en lugar de Printing
      await FileSaver.instance.saveFile(
        name: 'Nomina_${payroll.periodo}',
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );

      scaffold.showSnackBar(
        const SnackBar(content: Text('PDF descargado con éxito')),
      );
    } catch (e) {
      // Close the loading dialog
      Navigator.pop(context);

      scaffold.showSnackBar(
        SnackBar(content: Text('Error al descargar PDF: $e')),
      );
    }
  }
}
