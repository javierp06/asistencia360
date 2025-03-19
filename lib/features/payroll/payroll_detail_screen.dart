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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Información General',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('Período', payroll.periodo),
                    _buildInfoRow(
                      'Fecha de Generación',
                      DateFormat('dd/MM/yyyy').format(payroll.fechaGeneracion),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Empleado:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              payroll.empleadoNombre,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Desglose de Salario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildSalaryRow(
                      'Salario Base',
                      payroll.salarioBruto - payroll.horasExtra,
                      currencyFormat,
                    ),
                    _buildSalaryRow(
                      'Horas Extra',
                      payroll.horasExtra,
                      currencyFormat,
                    ),
                    _buildSalaryRow(
                      'Bonificaciones',
                      payroll.bonificaciones,
                      currencyFormat,
                    ),
                    const Divider(),
                    _buildSalaryRow(
                      'Salario Bruto',
                      payroll.salarioBruto,
                      currencyFormat,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),

            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deducciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildSalaryRow(
                      'RAP (4%)',
                      payroll.deduccionRap,
                      currencyFormat,
                      isNegative: true,
                    ),
                    _buildSalaryRow(
                      'IHSS (2.5%)',
                      payroll.deduccionIhss,
                      currencyFormat,
                      isNegative: true,
                    ),
                    const Divider(),
                    _buildSalaryRow(
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

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors
                            .green
                            .shade900 // Dark green background in dark mode
                        : Colors
                            .green
                            .shade50, // Light green background in light mode
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Salario Neto:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    currencyFormat.format(payroll.salarioNeto),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors
                                  .white // White text in dark mode
                              : Colors
                                  .green
                                  .shade800, // Dark green text in light mode
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(
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
