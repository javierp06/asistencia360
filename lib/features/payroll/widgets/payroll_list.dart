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
    final theme = Theme.of(context);

    return ListView.builder(
      itemCount: payrolls.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final payroll = payrolls[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PayrollDetailScreen(payroll: payroll),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        radius: 24,
                        child: Icon(
                          Icons.receipt_long,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin ? payroll.empleadoNombre : 'Mi Nómina',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Período: ${payroll.periodo}',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge('Procesado'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha de emisión:',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(payroll.fechaGeneracion),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Salario Neto:',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            currencyFormat.format(payroll.salarioNeto),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Ver detalles'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PayrollDetailScreen(payroll: payroll),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
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