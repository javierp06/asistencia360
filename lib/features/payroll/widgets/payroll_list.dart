import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/payroll.dart';
import '../payroll_detail_screen.dart';

class PayrollList extends StatelessWidget {
  final List<Payroll> payrolls;
  final bool isAdmin;
  
  const PayrollList({
    Key? key,
    required this.payrolls,
    required this.isAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_HN',
      symbol: 'L',
      decimalDigits: 2,
    );

    return ListView.builder(
      itemCount: payrolls.length,
      itemBuilder: (context, index) {
        final payroll = payrolls[index];
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAdmin ? payroll.empleadoNombre : 'Mi Nómina',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Período: ${payroll.periodo}'),
                const SizedBox(height: 4),
                Text('Fecha: ${DateFormat('dd/MM/yyyy').format(payroll.fechaGeneracion)}'),
                const SizedBox(height: 4),
                Text(
                  'Salario Neto: ${currencyFormat.format(payroll.salarioNeto)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PayrollDetailScreen(payroll: payroll),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'en proceso':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'transferido':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rechazado':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.blue;
        icon = Icons.info;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}